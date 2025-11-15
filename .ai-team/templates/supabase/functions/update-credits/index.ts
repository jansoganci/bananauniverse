/**
 * Update Credits Edge Function
 * Purpose: Add/deduct credits for users
 *
 * Usage:
 * POST /update-credits
 * {
 *   "user_id": "uuid",
 *   "amount": 10,
 *   "action": "add" | "deduct",
 *   "reason": "iap_purchase" | "video_generation" | etc
 * }
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { requireAuth } from '../_shared/auth-helper.ts'
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
    const { user_id, amount, action, reason, transaction_id } = await req.json()

    // Validate input
    if (!user_id || !amount || !action) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Users can only modify their own credits (unless admin)
    if (authUser.id !== user_id) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 403, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Create Supabase client with service role
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    let result

    if (action === 'add') {
      // Add credits
      const { data, error } = await supabaseClient.rpc('add_credits', {
        p_user_id: user_id,
        p_amount: amount,
        p_reason: reason || 'manual',
        p_transaction_id: transaction_id,
      })

      if (error) throw error
      result = data
    } else if (action === 'deduct') {
      // Deduct credits
      const { data, error } = await supabaseClient.rpc('deduct_credits', {
        p_user_id: user_id,
        p_amount: amount,
        p_reason: reason || 'usage',
      })

      if (error) throw error
      result = data
    } else {
      return new Response(
        JSON.stringify({ error: 'Invalid action' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Send Telegram alert for purchases
    if (action === 'add' && reason === 'iap_purchase') {
      await TelegramAlerts.purchase(user_id, 'Credits', amount)
    }

    return new Response(JSON.stringify(result), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (error) {
    console.error('Error in update-credits:', error)

    // Send error alert
    await TelegramAlerts.error('update-credits', error.message)

    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})
