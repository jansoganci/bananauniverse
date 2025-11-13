/**
 * Generate Video Edge Function
 * Purpose: Create async video generation job
 *
 * Usage:
 * POST /generate-video
 * Headers: Idempotency-Key: unique-key
 * {
 *   "model_id": "fal-video-model",
 *   "prompt": "A cat playing piano",
 *   "duration": 5
 * }
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { requireAuth } from '../_shared/auth-helper.ts'
import { retryWithBackoff } from '../_shared/retry.ts'

serve(async (req) => {
  try {
    // Only allow POST
    if (req.method !== 'POST') {
      return new Response('Method not allowed', { status: 405 })
    }

    // Get authenticated user
    const authUser = await requireAuth(req)

    // Get idempotency key (required)
    const idempotencyKey = req.headers.get('Idempotency-Key')
    if (!idempotencyKey) {
      return new Response(
        JSON.stringify({ error: 'Missing Idempotency-Key header' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Parse request body
    const { model_id, prompt, duration = 5 } = await req.json()

    if (!model_id || !prompt) {
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

    // Check idempotency
    const { data: existingLog } = await supabaseClient
      .from('idempotency_log')
      .select('response_data')
      .eq('idempotency_key', idempotencyKey)
      .single()

    if (existingLog) {
      console.log('Request already processed (idempotent)')
      return new Response(JSON.stringify(existingLog.response_data), {
        headers: {
          'Content-Type': 'application/json',
          'X-Idempotent-Replay': 'true',
        },
      })
    }

    // Create job (deducts credits atomically)
    const { data: jobResult, error: jobError } = await supabaseClient.rpc(
      'create_video_job',
      {
        p_user_id: authUser.id,
        p_model_id: model_id,
        p_prompt: prompt,
        p_credits_required: 1, // TODO: Get from models table
        p_idempotency_key: idempotencyKey,
      }
    )

    if (jobError) throw jobError

    if (!jobResult.success) {
      return new Response(JSON.stringify(jobResult), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    const jobId = jobResult.job_id

    // Call external provider (with retry)
    try {
      const providerResponse = await callVideoProvider(model_id, prompt, duration)

      // Update job with provider ID
      await supabaseClient
        .from('video_jobs')
        .update({
          provider_name: providerResponse.provider,
          provider_job_id: providerResponse.job_id,
          status: 'processing',
          started_at: new Date().toISOString(),
        })
        .eq('id', jobId)

      return new Response(
        JSON.stringify({
          success: true,
          job_id: jobId,
          status: 'processing',
          estimated_time: providerResponse.estimated_time || 120,
          credits_remaining: jobResult.credits_remaining,
        }),
        { headers: { 'Content-Type': 'application/json' } }
      )
    } catch (error) {
      // Provider call failed - rollback credits
      console.error('Provider call failed:', error)

      await supabaseClient.rpc('rollback_failed_job', {
        p_job_id: jobId,
      })

      throw error
    }
  } catch (error) {
    console.error('Error in generate-video:', error)

    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})

/**
 * Call external video generation provider
 * Replace with your actual provider (FalAI, Runway, etc.)
 */
async function callVideoProvider(
  modelId: string,
  prompt: string,
  duration: number
) {
  const apiKey = Deno.env.get('FAL_API_KEY')

  return retryWithBackoff(
    async () => {
      const response = await fetch('https://queue.fal.run/fal-ai/video-model', {
        method: 'POST',
        headers: {
          Authorization: `Key ${apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          prompt,
          duration,
          model_id: modelId,
          webhook_url: `${Deno.env.get('SUPABASE_URL')}/functions/v1/video-webhook`,
        }),
      })

      if (!response.ok) {
        throw new Error(`Provider error: ${response.statusText}`)
      }

      const data = await response.json()

      return {
        provider: 'fal',
        job_id: data.request_id,
        estimated_time: 120, // 2 minutes
      }
    },
    { maxRetries: 3, retryableErrors: ['timeout', '500', '503'] }
  )
}
