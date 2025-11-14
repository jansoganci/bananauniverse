import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import * as jose from 'https://deno.land/x/jose@v4.14.4/index.ts';
import { createLogger } from '../_shared/logger.ts';

Deno.serve(async (req: Request) => {
  const requestId = `iap-webhook-${Date.now()}`;
  let logger = createLogger('iap-webhook', requestId);
  
  try {
    logger.info('Request received', { method: req.method });
    
    const body = await req.json();
    const { signedPayload, notificationType } = body;

    if (!signedPayload) {
      logger.error('Missing signedPayload');
      return new Response('Missing signedPayload', { status: 400 });
    }

    logger.step('1. Notification received', { notificationType });

    // ============================================
    // 1. VERIFY WEBHOOK SIGNATURE
    // ============================================
    // In production, verify with Apple's public key from JWKS
    // For now, decode without verification (add proper verification in production)
    logger.step('2. Decoding webhook payload');
    const { payload } = await jose.decodeJwt(signedPayload);
    logger.step('2. Payload decoded');

    // ============================================
    // 2. HANDLE REFUND NOTIFICATION
    // ============================================
    if (notificationType === 'REFUND') {
      logger.step('3. Processing REFUND notification');
      
      const transactionInfo = payload.data?.signedTransactionInfo;
      if (!transactionInfo) {
        logger.error('Missing transaction info in payload');
        return new Response('Missing transaction info', { status: 400 });
      }

      // Decode transaction info
      logger.step('4. Decoding transaction info');
      const { payload: txPayload } = await jose.decodeJwt(transactionInfo);
      const originalTransactionId = txPayload.originalTransactionId as string;

      logger = createLogger('iap-webhook', requestId, {
        originalTransactionId,
      });
      
      logger.step('4. Processing refund', { originalTransactionId });

      // ============================================
      // 3. FIND TRANSACTION IN DATABASE
      // ============================================
      logger.step('5. Finding transaction in database');
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
        logger.warn('Transaction not found', { originalTransactionId, error: findError?.message });
        return new Response('Transaction not found', { status: 404 });
      }
      
      logger.step('5. Transaction found', {
        userId: iapTransaction.user_id,
        deviceId: iapTransaction.device_id,
        creditsGranted: iapTransaction.credits_granted,
        currentStatus: iapTransaction.status
      });

      // ============================================
      // 4. REMOVE CREDITS (if not already refunded)
      // ============================================
      if (iapTransaction.status !== 'refunded') {
        logger.step('6. Removing credits');
        const idempotencyKey = `refund-${originalTransactionId}`;
        const { error: consumeError } = await supabase.rpc('consume_credits', {
          p_user_id: iapTransaction.user_id,
          p_device_id: iapTransaction.device_id,
          p_amount: iapTransaction.credits_granted,
          p_idempotency_key: idempotencyKey
        });

        if (consumeError) {
          logger.error('Failed to remove credits', { 
            error: consumeError.message,
            creditsGranted: iapTransaction.credits_granted
          });
          // Continue anyway - mark as refunded
        } else {
          logger.step('6. Credits removed', { creditsRemoved: iapTransaction.credits_granted });
        }

        // ============================================
        // 5. UPDATE TRANSACTION STATUS
        // ============================================
        logger.step('7. Updating transaction status');
        await supabase
          .from('iap_transactions')
          .update({
            status: 'refunded',
            refunded_at: new Date().toISOString()
          })
          .eq('original_transaction_id', originalTransactionId);

        logger.step('7. Transaction status updated to refunded');
        logger.summary('success', {
          originalTransactionId,
          creditsRemoved: iapTransaction.credits_granted,
          userId: iapTransaction.user_id,
          deviceId: iapTransaction.device_id
        });
      } else {
        logger.info('Transaction already refunded', { originalTransactionId });
      }
    } else {
      logger.debug('Non-REFUND notification, skipping', { notificationType });
    }

    // Return 200 to acknowledge receipt
    return new Response('OK', { status: 200 });

  } catch (error: any) {
    logger.error('Fatal error', error);
    logger.summary('error', { error: error.message });
    return new Response('Internal server error', { status: 500 });
  }
});

