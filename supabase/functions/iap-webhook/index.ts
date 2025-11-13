import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import * as jose from 'https://deno.land/x/jose@v4.14.4/index.ts';

Deno.serve(async (req: Request) => {
  try {
    const body = await req.json();
    const { signedPayload, notificationType } = body;

    if (!signedPayload) {
      return new Response('Missing signedPayload', { status: 400 });
    }

    console.log('📥 [WEBHOOK] Received notification:', notificationType);

    // ============================================
    // 1. VERIFY WEBHOOK SIGNATURE
    // ============================================
    // In production, verify with Apple's public key from JWKS
    // For now, decode without verification (add proper verification in production)
    const { payload } = await jose.decodeJwt(signedPayload);

    // ============================================
    // 2. HANDLE REFUND NOTIFICATION
    // ============================================
    if (notificationType === 'REFUND') {
      const transactionInfo = payload.data?.signedTransactionInfo;
      if (!transactionInfo) {
        return new Response('Missing transaction info', { status: 400 });
      }

      // Decode transaction info
      const { payload: txPayload } = await jose.decodeJwt(transactionInfo);
      const originalTransactionId = txPayload.originalTransactionId as string;

      console.log('💰 [WEBHOOK] Processing refund for transaction:', originalTransactionId);

      // ============================================
      // 3. FIND TRANSACTION IN DATABASE
      // ============================================
      const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
      const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
      const supabase = createClient(supabaseUrl, supabaseServiceKey);

      const { data: iapTransaction, error: findError } = await supabase
        .from('iap_transactions')
        .select('user_id, device_id, credits_granted, status')
        .eq('original_transaction_id', originalTransactionId)
        .eq('status', 'completed')
        .single();

      if (findError || !iapTransaction) {
        console.warn('⚠️ [WEBHOOK] Transaction not found:', originalTransactionId);
        return new Response('Transaction not found', { status: 404 });
      }

      // ============================================
      // 4. REMOVE CREDITS (if not already refunded)
      // ============================================
      if (iapTransaction.status !== 'refunded') {
        const { error: consumeError } = await supabase.rpc('consume_credits', {
          p_user_id: iapTransaction.user_id,
          p_device_id: iapTransaction.device_id,
          p_amount: iapTransaction.credits_granted,
          p_idempotency_key: `refund-${originalTransactionId}`
        });

        if (consumeError) {
          console.error('❌ [WEBHOOK] Failed to remove credits:', consumeError);
          // Continue anyway - mark as refunded
        } else {
          console.log('✅ [WEBHOOK] Credits removed:', iapTransaction.credits_granted);
        }

        // ============================================
        // 5. UPDATE TRANSACTION STATUS
        // ============================================
        await supabase
          .from('iap_transactions')
          .update({
            status: 'refunded',
            refunded_at: new Date().toISOString()
          })
          .eq('original_transaction_id', originalTransactionId);

        console.log('✅ [WEBHOOK] Refund processed:', originalTransactionId);
      } else {
        console.log('ℹ️ [WEBHOOK] Transaction already refunded:', originalTransactionId);
      }
    }

    // Return 200 to acknowledge receipt
    return new Response('OK', { status: 200 });

  } catch (error: any) {
    console.error('❌ [WEBHOOK] Error:', error);
    return new Response('Internal server error', { status: 500 });
  }
});

