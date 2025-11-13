# Backend Architecture: Video Generation Workflow

**Part 3 of 6** - Video generation endpoints, provider integration, idempotency, and webhooks

**Related Documents:**
- [backend-INDEX.md](./backend-INDEX.md) - Complete documentation index
- [backend-2-core-apis.md](./backend-2-core-apis.md) - Core API endpoints
- [backend-5-credit-system.md](./backend-5-credit-system.md) - Credit deduction logic
- [backend-6-operations-testing.md](./backend-6-operations-testing.md) - Error handling

---

## 🎬 Generate Video Endpoint

**Purpose:** Start a video generation job with idempotency protection

**Endpoint:** `POST /functions/v1/generate-video`

**Request Headers:**
```
Authorization: Bearer <jwt-token>
Idempotency-Key: <uuid>
```

**Request Body:**
```json
{
  "user_id": "uuid",
  "model_id": "uuid",
  "prompt": "A cat playing piano in a jazz club",
  "settings": {
    "resolution": "1080p",
    "duration": 5,
    "fps": 24
  }
}
```

**Response:**
```json
{
  "job_id": "uuid",
  "status": "pending",
  "credits_used": 4
}
```

**Idempotent Response (if retry):**
```
Status: 200
Headers: X-Idempotent-Replay: true
Body: (same as original response)
```

### Implementation

File: `supabase/functions/generate-video/index.ts`

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { logEvent } from '../_shared/logger.ts'

serve(async (req) => {
  try {
    // 1. Get idempotency key from header
    const idempotencyKey = req.headers.get('Idempotency-Key')
    
    if (!idempotencyKey) {
      return new Response(
        JSON.stringify({ error: 'Idempotency-Key header required' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }
    
    const { user_id, model_id, prompt, settings } = await req.json()
    
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )
    
    // 2. Check idempotency (prevent duplicate processing)
    const { data: existing } = await supabaseClient
      .from('idempotency_log')
      .select('job_id, response_data, status_code')
      .eq('idempotency_key', idempotencyKey)
      .eq('user_id', user_id)
      .gt('expires_at', new Date().toISOString())
      .single()
    
    if (existing) {
      // Return cached response
      logEvent('idempotent_replay', { 
        user_id, 
        idempotency_key: idempotencyKey 
      })
      
      return new Response(
        JSON.stringify(existing.response_data),
        {
          status: existing.status_code,
          headers: {
            'Content-Type': 'application/json',
            'X-Idempotent-Replay': 'true'
          }
        }
      )
    }
    
    // 3. Fetch model details
    const { data: model, error: modelError } = await supabaseClient
      .from('models')
      .select('cost_per_generation, provider, provider_model_id')
      .eq('id', model_id)
      .single()
    
    if (modelError) throw modelError
    
    // 4. Deduct credits atomically
    const { data: deductResult } = await supabaseClient.rpc('deduct_credits', {
      p_user_id: user_id,
      p_amount: model.cost_per_generation,
      p_reason: 'video_generation'
    })
    
    if (!deductResult.success) {
      return new Response(
        JSON.stringify({ 
          error: deductResult.error,
          credits_remaining: deductResult.current_credits || 0
        }),
        { status: 402, headers: { 'Content-Type': 'application/json' } }
      )
    }
    
    // 5. Create video job
    const { data: job, error: jobError } = await supabaseClient
      .from('video_jobs')
      .insert({
        user_id: user_id,
        model_id: model_id,
        prompt: prompt,
        settings: settings || {},
        status: 'pending',
        credits_used: model.cost_per_generation
      })
      .select()
      .single()
    
    if (jobError) {
      // ROLLBACK: Refund credits if job creation failed
      await supabaseClient.rpc('add_credits', {
        p_user_id: user_id,
        p_amount: model.cost_per_generation,
        p_reason: 'generation_failed_refund'
      })
      
      throw jobError
    }
    
    // 6. Call provider API
    let providerJobId: string | null = null
    
    try {
      const providerResult = await callProviderAPI(
        model.provider,
        model.provider_model_id,
        prompt,
        settings
      )
      
      providerJobId = providerResult.job_id
      
      // Update job with provider_job_id
      await supabaseClient
        .from('video_jobs')
        .update({ provider_job_id: providerJobId })
        .eq('job_id', job.job_id)
      
    } catch (providerError) {
      // ROLLBACK: Mark job as failed and refund credits
      await supabaseClient
        .from('video_jobs')
        .update({
          status: 'failed',
          error_message: providerError.message
        })
        .eq('job_id', job.job_id)
      
      await supabaseClient.rpc('add_credits', {
        p_user_id: user_id,
        p_amount: model.cost_per_generation,
        p_reason: 'generation_failed_refund'
      })
      
      throw providerError
    }
    
    // 7. Store idempotency record
    const responseBody = {
      job_id: job.job_id,
      status: 'pending',
      credits_used: model.cost_per_generation
    }
    
    await supabaseClient.from('idempotency_log').insert({
      idempotency_key: idempotencyKey,
      user_id: user_id,
      job_id: job.job_id,
      operation_type: 'video_generation',
      response_data: responseBody,
      status_code: 200
    })
    
    logEvent('video_generation_started', {
      user_id,
      job_id: job.job_id,
      model_id,
      provider: model.provider,
      credits_used: model.cost_per_generation
    })
    
    return new Response(
      JSON.stringify(responseBody),
      { headers: { 'Content-Type': 'application/json' } }
    )
    
  } catch (error) {
    logEvent('video_generation_error', { error: error.message }, 'error')
    
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})
```

---

## 🔄 Idempotency Logic

### How It Works

1. **Client generates UUID** before making request
2. **Client sends UUID** in `Idempotency-Key` header
3. **Server checks** if key exists in `idempotency_log` table
4. **If exists:** Return cached response (prevents duplicate charge)
5. **If new:** Process request and store response in `idempotency_log`

### Benefits

- **Prevents double-charging** if network drops and client retries
- **Idempotent operations** - safe to retry
- **24-hour expiration** - keys expire after 24 hours

### iOS Client Implementation

```swift
// In VideoGenerationService.swift
func generateVideo(
    userId: String, 
    modelId: String, 
    prompt: String,
    settings: VideoSettings
) async throws -> VideoGenerationResponse {
    
    // Generate idempotency key
    let idempotencyKey = UUID().uuidString
    
    let request = VideoGenerationRequest(
        user_id: userId,
        model_id: modelId,
        prompt: prompt,
        settings: settings
    )
    
    // Call API with idempotency key in header
    let response: VideoGenerationResponse = try await APIClient.shared.request(
        endpoint: "generate-video",
        method: .POST,
        body: request,
        headers: [
            "Idempotency-Key": idempotencyKey
        ]
    )
    
    return response
}
```

---

## 📊 Get Video Status Endpoint

**Purpose:** Check video generation job status (polling endpoint)

**Endpoint:** `GET /functions/v1/get-video-status?job_id=<uuid>`

**Request Headers:**
```
Authorization: Bearer <jwt-token>
```

**Response (Pending):**
```json
{
  "job_id": "uuid",
  "status": "pending",
  "video_url": null,
  "thumbnail_url": null
}
```

**Response (Completed):**
```json
{
  "job_id": "uuid",
  "status": "completed",
  "video_url": "https://storage.supabase.co/videos/...",
  "thumbnail_url": "https://storage.supabase.co/thumbnails/..."
}
```

**Response (Failed):**
```json
{
  "job_id": "uuid",
  "status": "failed",
  "error_message": "Provider timeout"
}
```

### Implementation

File: `supabase/functions/get-video-status/index.ts`

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  try {
    const url = new URL(req.url)
    const job_id = url.searchParams.get('job_id')
    
    if (!job_id) {
      return new Response(
        JSON.stringify({ error: 'job_id required' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }
    
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )
    
    // 1. Get job from database
    const { data: job, error } = await supabaseClient
      .from('video_jobs')
      .select('*')
      .eq('job_id', job_id)
      .single()
    
    if (error) throw error
    
    // 2. If still pending/processing, check provider status
    if (job.status === 'pending' || job.status === 'processing') {
      try {
        const providerStatus = await checkProviderStatus(
          job.provider_job_id,
          job.model_id
        )
        
        if (providerStatus.status === 'completed') {
          // Update job in database
          await supabaseClient
            .from('video_jobs')
            .update({
              status: 'completed',
              video_url: providerStatus.video_url,
              thumbnail_url: providerStatus.thumbnail_url,
              completed_at: new Date().toISOString()
            })
            .eq('job_id', job_id)
          
          return new Response(
            JSON.stringify({
              job_id: job.job_id,
              status: 'completed',
              video_url: providerStatus.video_url,
              thumbnail_url: providerStatus.thumbnail_url
            }),
            { headers: { 'Content-Type': 'application/json' } }
          )
        }
      } catch (providerError) {
        // If provider check fails, return current DB status
        console.error('Provider check failed:', providerError)
      }
    }
    
    // 3. Return current status
    return new Response(
      JSON.stringify({
        job_id: job.job_id,
        status: job.status,
        video_url: job.video_url,
        thumbnail_url: job.thumbnail_url
      }),
      { headers: { 'Content-Type': 'application/json' } }
    )
    
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})
```

**Note:** This polling endpoint is replaced by webhooks in Phase 5. See Webhook System section below.

---

## 🤖 Provider Integration

### Provider Adapter Interface

File: `supabase/functions/_shared/falai-adapter.ts`

```typescript
// FalAI adapter
export async function callFalAI(
  modelId: string, 
  prompt: string, 
  settings: any
) {
  const apiKey = Deno.env.get('FALAI_API_KEY')
  
  const response = await fetch(`https://fal.run/${modelId}`, {
    method: 'POST',
    headers: {
      'Authorization': `Key ${apiKey}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      prompt: prompt,
      ...settings
    })
  })
  
  if (!response.ok) {
    throw new Error(`FalAI error: ${response.statusText}`)
  }
  
  const data = await response.json()
  
  return {
    job_id: data.request_id || data.id
  }
}

export async function checkFalAIStatus(providerJobId: string) {
  const apiKey = Deno.env.get('FALAI_API_KEY')
  
  const response = await fetch(`https://fal.run/status/${providerJobId}`, {
    headers: {
      'Authorization': `Key ${apiKey}`
    }
  })
  
  if (!response.ok) {
    throw new Error(`FalAI status check failed: ${response.statusText}`)
  }
  
  const data = await response.json()
  
  return {
    status: data.status,
    video_url: data.video?.url,
    thumbnail_url: data.thumbnail?.url
  }
}
```

### Provider Router

```typescript
async function callProviderAPI(
  provider: string,
  modelId: string,
  prompt: string,
  settings: any
) {
  switch (provider) {
    case 'fal':
      return await callFalAI(modelId, prompt, settings)
    case 'runway':
      // Future implementation
      throw new Error('Runway not yet implemented')
    case 'pika':
      // Future implementation
      throw new Error('Pika not yet implemented')
    default:
      throw new Error(`Unknown provider: ${provider}`)
  }
}
```

### Retry Logic (Phase 6)

See [backend-6-operations-testing.md](./backend-6-operations-testing.md) for exponential backoff retry implementation.

---

## 🔙 Rollback Logic

### When Rollback Occurs

1. **Job creation fails** → Refund credits
2. **Provider API call fails** → Refund credits + mark job as failed
3. **Video upload fails** → Refund credits + mark job as failed

### Rollback Implementation

```typescript
// Example: Rollback on provider failure
try {
  const providerResult = await callProviderAPI(...)
} catch (providerError) {
  // ROLLBACK: Mark job as failed and refund credits
  await supabaseClient
    .from('video_jobs')
    .update({
      status: 'failed',
      error_message: providerError.message
    })
    .eq('job_id', job.job_id)
  
  await supabaseClient.rpc('add_credits', {
    p_user_id: user_id,
    p_amount: model.cost_per_generation,
    p_reason: 'generation_failed_refund'
  })
  
  throw providerError
}
```

**See:** [backend-5-credit-system.md](./backend-5-credit-system.md) for credit refund stored procedure.

---

## 🔔 Webhook System (Phase 5)

**Purpose:** Replace polling with event-driven architecture

### Webhook Delivery Endpoint

File: `supabase/functions/webhook-delivery/index.ts`

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// HMAC signature validation for security
async function validateSignature(
  payload: string,
  signature: string,
  secret: string
): Promise<boolean> {
  const encoder = new TextEncoder()
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  )

  const signatureBytes = await crypto.subtle.sign(
    'HMAC',
    key,
    encoder.encode(payload)
  )

  const expectedSignature = Array.from(new Uint8Array(signatureBytes))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('')

  return expectedSignature === signature
}

serve(async (req) => {
  try {
    const signature = req.headers.get('X-Webhook-Signature')
    const payload = await req.text()

    // Validate webhook signature
    const secret = Deno.env.get('WEBHOOK_SECRET')!
    const isValid = await validateSignature(payload, signature!, secret)

    if (!isValid) {
      return new Response(
        JSON.stringify({ error: 'Invalid signature' }),
        { status: 401 }
      )
    }

    const event = JSON.parse(payload)

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // Process webhook event
    switch (event.type) {
      case 'video.completed':
        await handleVideoCompleted(event.data, supabaseClient)
        break
      case 'video.failed':
        await handleVideoFailed(event.data, supabaseClient)
        break
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { 'Content-Type': 'application/json' }
    })
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500 }
    )
  }
})

async function handleVideoCompleted(data: any, client: any) {
  // Update video job
  await client
    .from('video_jobs')
    .update({
      status: 'completed',
      video_url: data.video_url,
      thumbnail_url: data.thumbnail_url,
      completed_at: new Date().toISOString()
    })
    .eq('provider_job_id', data.provider_job_id)

  // Send APNs push notification
  const job = await client
    .from('video_jobs')
    .select('user_id')
    .eq('provider_job_id', data.provider_job_id)
    .single()

  await sendPushNotification(job.data.user_id, {
    title: 'Video Ready!',
    body: 'Your video generation is complete',
    data: { job_id: data.job_id }
  })
}

async function handleVideoFailed(data: any, client: any) {
  // Mark job as failed and refund credits
  const job = await client
    .from('video_jobs')
    .select('user_id, credits_used')
    .eq('provider_job_id', data.provider_job_id)
    .single()

  await client
    .from('video_jobs')
    .update({
      status: 'failed',
      error_message: data.error
    })
    .eq('provider_job_id', data.provider_job_id)

  // Refund credits
  await client.rpc('add_credits', {
    p_user_id: job.data.user_id,
    p_amount: job.data.credits_used,
    p_reason: 'generation_failed_refund'
  })
}
```

### Benefits of Webhooks

- **Real-time updates** - No polling needed
- **Better battery life** - iOS app doesn't need to poll
- **Lower API costs** - Fewer requests
- **Push notifications** - Users get notified when video is ready

---

## ⚠️ Error Handling

### Error Scenarios

1. **Insufficient Credits** → Status 402, return current balance
2. **Invalid Model** → Status 400, error message
3. **Provider Timeout** → Status 504, refund credits
4. **Provider Rejection** → Status 400, refund credits
5. **Network Failure** → Status 500, retry with idempotency

### Error Response Format

```json
{
  "error": "Insufficient credits",
  "credits_remaining": 2
}
```

**Enhanced Format (Phase 7):**

See [backend-6-operations-testing.md](./backend-6-operations-testing.md) for internationalized error codes.

---

## 📱 iOS Client Polling Pattern

**Before Webhooks (Phase 0-4):**

```swift
// Poll every 2-4 seconds
func pollVideoStatus(jobId: String) async throws -> VideoJob {
    while true {
        let status = try await resultService.getVideoJobStatus(jobId: jobId)
        
        if status.status == "completed" {
            return status
        } else if status.status == "failed" {
            throw AppError.generationFailed(status.error_message ?? "Unknown error")
        }
        
        // Wait 3 seconds before next poll
        try await Task.sleep(nanoseconds: 3_000_000_000)
    }
}
```

**After Webhooks (Phase 5+):**

- Remove polling code
- Listen for push notifications
- Update UI when notification received

---

## 🚀 Next Steps

1. **Implement webhooks** - See Phase 5 in [backend-6-operations-testing.md](./backend-6-operations-testing.md)
2. **Add retry logic** - See Phase 6 in [backend-6-operations-testing.md](./backend-6-operations-testing.md)
3. **Error handling** - See Phase 7 in [backend-6-operations-testing.md](./backend-6-operations-testing.md)

---

**Related Documentation:**
- [backend-INDEX.md](./backend-INDEX.md) - Complete documentation index
- [backend-2-core-apis.md](./backend-2-core-apis.md) - Core API endpoints
- [backend-5-credit-system.md](./backend-5-credit-system.md) - Credit deduction logic
- [backend-6-operations-testing.md](./backend-6-operations-testing.md) - Error handling and retry logic

