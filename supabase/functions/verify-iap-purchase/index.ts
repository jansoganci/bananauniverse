import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import * as jose from 'https://deno.land/x/jose@v4.14.4/index.ts';
import { createLogger } from '../_shared/logger.ts';

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

  const requestId = `iap-verify-${Date.now()}`;
  let logger = createLogger('verify-iap-purchase', requestId);

  try {
    logger.info('Request received', { method: req.method });

    // ============================================
    // 1. AUTHENTICATE REQUEST
    // ============================================
    logger.step('1. Authenticating request');
    const authHeader = req.headers.get('authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      logger.error('Missing authorization header');
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
      logger = createLogger('verify-iap-purchase', requestId, { userId });
      logger.step('1. User authenticated', { userId });
    } else {
      // Anonymous user - get device_id from body
      const body = await req.json();
      deviceId = body.device_id || null;
      
      if (!deviceId) {
        logger.error('device_id required for anonymous users');
        return new Response(
          JSON.stringify({ success: false, error: 'device_id required for anonymous users' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      logger = createLogger('verify-iap-purchase', requestId, { deviceId });
      logger.step('1. Anonymous user', { deviceId });

      // Set device_id session for RLS
      await supabase.rpc('set_device_id_session', { p_device_id: deviceId });
      logger.debug('Device ID session set');
    }

    // ============================================
    // 2. PARSE REQUEST BODY
    // ============================================
    logger.step('2. Parsing request body');
    const body = await req.json();
    const { transaction_jwt, product_id } = body;

    if (!transaction_jwt || !product_id) {
      logger.error('Missing required fields', { hasTransactionJwt: !!transaction_jwt, hasProductId: !!product_id });
      return new Response(
        JSON.stringify({ success: false, error: 'Missing transaction_jwt or product_id' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    logger.step('2. Request body parsed', { productId: product_id });

    // ============================================
    // 3. VERIFY TRANSACTION WITH APPLE
    // ============================================
    logger.step('3. Verifying transaction with Apple');
    const verification = await verifyAppleTransaction(transaction_jwt, logger);

    if (!verification.valid) {
      logger.error('Transaction verification failed');
      return new Response(
        JSON.stringify({ success: false, error: 'Invalid transaction', code: 'INVALID_RECEIPT' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    logger.step('3. Transaction verified', {
      transactionId: verification.transaction_id,
      originalTransactionId: verification.original_transaction_id,
      productId: verification.product_id
    });

    // Validate product_id matches
    if (verification.product_id !== product_id) {
      logger.error('Product ID mismatch', {
        expected: product_id,
        received: verification.product_id
      });
      return new Response(
        JSON.stringify({ success: false, error: 'Product ID mismatch', code: 'PRODUCT_MISMATCH' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // ============================================
    // 4. CHECK IDEMPOTENCY
    // ============================================
    logger.step('4. Checking idempotency');
    const idempotencyKey = `purchase-${verification.original_transaction_id}`;
    
    const { data: existingKey } = await supabase
      .from('idempotency_keys')
      .select('response_body')
      .eq('idempotency_key', idempotencyKey)
      .eq(userId ? 'user_id' : 'device_id', userId || deviceId)
      .single();

    if (existingKey?.response_body) {
      // Already processed - return cached result
      logger.info('Idempotent request, returning cached result', { idempotencyKey });
      logger.summary('success', { idempotent: true });
      return new Response(
        JSON.stringify(existingKey.response_body),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    logger.step('4. Idempotency check passed');

    // ============================================
    // 5. LOOKUP PRODUCT IN DATABASE
    // ============================================
    logger.step('5. Looking up product in database');
    const { data: product, error: productError } = await supabase
      .from('products')
      .select('credits, bonus_credits, is_active')
      .eq('product_id', product_id)
      .single();

    if (productError || !product) {
      logger.error('Product not found', { productId: product_id, error: productError?.message });
      return new Response(
        JSON.stringify({ success: false, error: 'Product not found', code: 'PRODUCT_NOT_FOUND' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (!product.is_active) {
      logger.warn('Product is not active', { productId: product_id });
      return new Response(
        JSON.stringify({ success: false, error: 'Product is not active', code: 'PRODUCT_INACTIVE' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const totalCredits = product.credits + (product.bonus_credits || 0);
    logger.step('5. Product found', {
      productId: product_id,
      credits: product.credits,
      bonusCredits: product.bonus_credits || 0,
      totalCredits
    });

    // ============================================
    // 6. GRANT CREDITS
    // ============================================
    logger.step('6. Granting credits');
    const { data: creditResult, error: creditError } = await supabase.rpc('add_credits', {
      p_user_id: userId,
      p_device_id: deviceId,
      p_amount: totalCredits,
      p_idempotency_key: idempotencyKey
    });

    if (creditError || !creditResult?.success) {
      logger.error('Failed to grant credits', {
        error: creditError?.message || creditResult?.error,
        totalCredits
      });
      return new Response(
        JSON.stringify({ 
          success: false, 
          error: creditResult?.error || 'Failed to grant credits',
          code: 'CREDIT_GRANT_FAILED'
        }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    logger.step('6. Credits granted', {
      creditsGranted: totalCredits,
      creditsRemaining: creditResult.credits_remaining
    });

    // ============================================
    // 7. LOG IAP TRANSACTION (Optional)
    // ============================================
    logger.step('7. Logging IAP transaction');
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
      logger.step('7. IAP transaction logged');
    } catch (logError) {
      // Don't fail if logging fails
      logger.warn('Failed to log IAP transaction', { error: logError });
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

    logger.summary('success', {
      productId: product_id,
      creditsGranted: totalCredits,
      creditsRemaining: creditResult.credits_remaining,
      transactionId: verification.transaction_id,
      originalTransactionId: verification.original_transaction_id
    });

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error: any) {
    logger.error('Fatal error', error);
    logger.summary('error', { error: error.message });
    return new Response(
      JSON.stringify({ success: false, error: error.message || 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

// ============================================
// APPLE TRANSACTION VERIFICATION
// ============================================

async function verifyAppleTransaction(transactionJWT: string, logger?: any): Promise<{
  valid: boolean;
  product_id?: string;
  transaction_id?: string;
  original_transaction_id?: string;
  purchase_date?: number;
}> {
  try {
    if (logger) logger.debug('Decoding transaction JWT');
    // Decode JWT to get transaction ID
    const decoded = await jose.decodeJwt(transactionJWT);
    
    const transactionId = decoded.transactionId as string;
    if (!transactionId) {
      if (logger) logger.error('No transaction ID in JWT');
      return { valid: false };
    }

    if (logger) logger.debug('Creating Apple API authentication JWT');
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

    if (logger) logger.debug('Calling App Store Server API', { transactionId });
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
      if (logger) logger.error('Apple API error', {
        status: response.status,
        error: errorText.substring(0, 200)
      });
      return { valid: false };
    }

    const data = await response.json();

    if (logger) logger.debug('Verifying signed transaction');
    // Verify the signed transaction (JWS)
    const { payload } = await jose.jwtVerify(
      data.signedTransaction,
      key  // In production, use Apple's public key from JWKS
    );

    // Validate bundle ID
    const bundleId = Deno.env.get('APPLE_BUNDLE_ID');
    if (payload.bundleId !== bundleId) {
      if (logger) logger.error('Bundle ID mismatch', {
        received: payload.bundleId,
        expected: bundleId
      });
      return { valid: false };
    }

    if (logger) logger.debug('Transaction verified successfully', {
      productId: payload.productId,
      transactionId: payload.transactionId,
      originalTransactionId: payload.originalTransactionId
    });

    return {
      valid: true,
      product_id: payload.productId as string,
      transaction_id: payload.transactionId as string,
      original_transaction_id: payload.originalTransactionId as string,
      purchase_date: payload.purchaseDate as number
    };

  } catch (error: any) {
    if (logger) logger.error('Verification error', error);
    return { valid: false };
  }
}

