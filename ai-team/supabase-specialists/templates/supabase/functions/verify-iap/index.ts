/**
 * Verify IAP Edge Function
 * Purpose: Verify Apple In-App Purchase and grant credits
 *
 * Usage:
 * POST /verify-iap
 * {
 *   "transaction_id": "apple_transaction_id",
 *   "product_id": "com.yourapp.credits.medium"
 * }
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { requireAuth } from '../_shared/auth-helper.ts'
import { retryWithBackoff } from '../_shared/retry.ts'
import { TelegramAlerts } from '../_shared/telegram.ts'

serve(async (req) => {
  try {
    // Only allow POST
    if (req.method !== 'POST') {
      return new Response('Method not allowed', { status: 405 })
    }

    // Get authenticated user
    const authUser = await requireAuth(req)

    // Parse request body
    const { transaction_id, product_id } = await req.json()

    if (!transaction_id || !product_id) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Create Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Verify with Apple (simplified - in production, use App Store Server API)
    const appleVerification = await verifyWithApple(transaction_id)

    if (!appleVerification.success) {
      return new Response(
        JSON.stringify({ error: 'Invalid transaction' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Process IAP purchase
    const { data: result, error } = await supabaseClient.rpc('process_iap_purchase', {
      p_user_id: authUser.id,
      p_transaction_id: transaction_id,
      p_original_transaction_id: appleVerification.original_transaction_id,
      p_product_id: product_id,
    })

    if (error) throw error

    if (!result.success) {
      return new Response(JSON.stringify(result), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    // Send Telegram alert
    await TelegramAlerts.purchase(
      authUser.id,
      result.product_name,
      result.credits_granted
    )

    return new Response(JSON.stringify(result), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (error) {
    console.error('Error in verify-iap:', error)

    // Send error alert
    await TelegramAlerts.error('verify-iap', error.message)

    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})

/**
 * Verify transaction with Apple App Store Server API
 * In production, implement full JWT creation and verification
 * See: https://developer.apple.com/documentation/appstoreserverapi
 */
async function verifyWithApple(transactionId: string) {
  // TODO: Implement real Apple verification
  // This is simplified for template purposes

  // In production:
  // 1. Create JWT with your App Store credentials
  // 2. Call Apple's verification endpoint
  // 3. Parse and validate the response

  return retryWithBackoff(
    async () => {
      // Placeholder - replace with real Apple API call
      console.log('Verifying transaction:', transactionId)

      // For template: return mock success
      return {
        success: true,
        original_transaction_id: transactionId,
      }
    },
    { maxRetries: 3, retryableErrors: ['timeout', '500'] }
  )
}
