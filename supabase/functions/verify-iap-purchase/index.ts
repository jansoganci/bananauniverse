import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import * as jose from 'https://deno.land/x/jose@v4.14.4/index.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // ============================================
    // 1. AUTHENTICATE REQUEST
    // ============================================
    const authHeader = req.headers.get('authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return new Response(
        JSON.stringify({ success: false, error: 'Missing authorization header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Get user from JWT (if authenticated)
    const token = authHeader.replace('Bearer ', '');
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    
    let userId: string | null = null;
    let deviceId: string | null = null;

    if (user) {
      userId = user.id;
    } else {
      // Anonymous user - get device_id from body
      const body = await req.json();
      deviceId = body.device_id || null;
      
      if (!deviceId) {
        return new Response(
          JSON.stringify({ success: false, error: 'device_id required for anonymous users' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // Set device_id session for RLS
      await supabase.rpc('set_device_id_session', { p_device_id: deviceId });
    }

    // ============================================
    // 2. PARSE REQUEST BODY
    // ============================================
    const body = await req.json();
    const { transaction_jwt, product_id } = body;

    if (!transaction_jwt || !product_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'Missing transaction_jwt or product_id' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // ============================================
    // 3. VERIFY TRANSACTION WITH APPLE
    // ============================================
    const verification = await verifyAppleTransaction(transaction_jwt);

    if (!verification.valid) {
      return new Response(
        JSON.stringify({ success: false, error: 'Invalid transaction', code: 'INVALID_RECEIPT' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Validate product_id matches
    if (verification.product_id !== product_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'Product ID mismatch', code: 'PRODUCT_MISMATCH' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // ============================================
    // 4. CHECK IDEMPOTENCY
    // ============================================
    const idempotencyKey = `purchase-${verification.original_transaction_id}`;
    
    const { data: existingKey } = await supabase
      .from('idempotency_keys')
      .select('response_body')
      .eq('idempotency_key', idempotencyKey)
      .eq(userId ? 'user_id' : 'device_id', userId || deviceId)
      .single();

    if (existingKey?.response_body) {
      // Already processed - return cached result
      console.log('✅ [IAP] Idempotent request, returning cached result');
      return new Response(
        JSON.stringify(existingKey.response_body),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // ============================================
    // 5. LOOKUP PRODUCT IN DATABASE
    // ============================================
    const { data: product, error: productError } = await supabase
      .from('products')
      .select('credits, bonus_credits, is_active')
      .eq('product_id', product_id)
      .single();

    if (productError || !product) {
      return new Response(
        JSON.stringify({ success: false, error: 'Product not found', code: 'PRODUCT_NOT_FOUND' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (!product.is_active) {
      return new Response(
        JSON.stringify({ success: false, error: 'Product is not active', code: 'PRODUCT_INACTIVE' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const totalCredits = product.credits + (product.bonus_credits || 0);

    // ============================================
    // 6. GRANT CREDITS
    // ============================================
    const { data: creditResult, error: creditError } = await supabase.rpc('add_credits', {
      p_user_id: userId,
      p_device_id: deviceId,
      p_amount: totalCredits,
      p_idempotency_key: idempotencyKey
    });

    if (creditError || !creditResult?.success) {
      console.error('❌ [IAP] Failed to grant credits:', creditError || creditResult);
      return new Response(
        JSON.stringify({ 
          success: false, 
          error: creditResult?.error || 'Failed to grant credits',
          code: 'CREDIT_GRANT_FAILED'
        }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // ============================================
    // 7. LOG IAP TRANSACTION (Optional)
    // ============================================
    try {
      await supabase
        .from('iap_transactions')
        .insert({
          user_id: userId,
          device_id: deviceId,
          product_id: product_id,
          transaction_id: verification.transaction_id,
          original_transaction_id: verification.original_transaction_id,
          credits_granted: totalCredits,
          status: 'completed',
          verified_at: new Date().toISOString(),
          receipt_data: { transaction_jwt: transaction_jwt.substring(0, 100) + '...' }  // Truncated for storage
        });
    } catch (logError) {
      // Don't fail if logging fails
      console.warn('⚠️ [IAP] Failed to log IAP transaction:', logError);
    }

    // ============================================
    // 8. RETURN SUCCESS
    // ============================================
    const response = {
      success: true,
      credits_granted: totalCredits,
      balance_after: creditResult.credits_remaining,
      transaction_id: verification.transaction_id,
      original_transaction_id: verification.original_transaction_id
    };

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error: any) {
    console.error('❌ [IAP] Fatal error:', error);
    return new Response(
      JSON.stringify({ success: false, error: error.message || 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

// ============================================
// APPLE TRANSACTION VERIFICATION
// ============================================

async function verifyAppleTransaction(transactionJWT: string): Promise<{
  valid: boolean;
  product_id?: string;
  transaction_id?: string;
  original_transaction_id?: string;
  purchase_date?: number;
}> {
  try {
    // Decode JWT to get transaction ID
    const decoded = await jose.decodeJwt(transactionJWT);
    
    const transactionId = decoded.transactionId as string;
    if (!transactionId) {
      return { valid: false };
    }

    // Create JWT for Apple API authentication
    const privateKey = Deno.env.get('APPLE_PRIVATE_KEY')!
      .replace(/\\n/g, '\n');

    const algorithm = 'ES256';
    const key = await jose.importPKCS8(privateKey, algorithm);

    const authJWT = await new jose.SignJWT({})
      .setProtectedHeader({
        alg: algorithm,
        kid: Deno.env.get('APPLE_KEY_ID')!
      })
      .setIssuer(Deno.env.get('APPLE_ISSUER_ID')!)
      .setAudience('appstoreconnect-v1')
      .setIssuedAt()
      .setExpirationTime('1h')
      .sign(key);

    // Call App Store Server API
    const response = await fetch(
      `https://api.storekit.itunes.apple.com/inApps/v1/transactions/${transactionId}`,
      {
        headers: {
          'Authorization': `Bearer ${authJWT}`,
          'Content-Type': 'application/json'
        }
      }
    );

    if (!response.ok) {
      const errorText = await response.text();
      console.error('❌ [IAP] Apple API error:', errorText);
      return { valid: false };
    }

    const data = await response.json();

    // Verify the signed transaction (JWS)
    const { payload } = await jose.jwtVerify(
      data.signedTransaction,
      key  // In production, use Apple's public key from JWKS
    );

    // Validate bundle ID
    const bundleId = Deno.env.get('APPLE_BUNDLE_ID');
    if (payload.bundleId !== bundleId) {
      console.error('❌ [IAP] Bundle ID mismatch:', payload.bundleId, 'expected', bundleId);
      return { valid: false };
    }

    return {
      valid: true,
      product_id: payload.productId as string,
      transaction_id: payload.transactionId as string,
      original_transaction_id: payload.originalTransactionId as string,
      purchase_date: payload.purchaseDate as number
    };

  } catch (error: any) {
    console.error('❌ [IAP] Verification error:', error);
    return { valid: false };
  }
}

