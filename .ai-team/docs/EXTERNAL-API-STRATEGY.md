# External API Integration Strategy

**Purpose:** Document patterns for integrating external AI providers (FalAI, Runway, Pika, etc.) with webhook support, retry logic, health monitoring, and automatic failover.

**Generated:** 2025-01-15

**Target:** AI agent system templates for solo developers

---

## 🎯 Current Implementation Status

### ✅ What Already Exists

Your current backend has these patterns implemented:

| Pattern | Status | Implementation |
|---------|--------|----------------|
| **Retry Logic** | ✅ Implemented | 3 attempts with exponential backoff for fal.ai |
| **Webhook Integration** | ✅ Implemented | Receiving completion webhooks from provider |
| **HMAC Validation** | ✅ Implemented | Webhook signature verification |
| **Single Provider** | ✅ Implemented | FalAI video generation |
| **Idempotency** | ✅ Implemented | Duplicate webhook protection |

### 🟡 What Needs Documentation

Patterns that exist but need to be documented as templates:

1. **Multi-provider abstraction** - How to support multiple AI providers
2. **Provider health checking** - Detect and respond to provider outages
3. **Automatic failover** - Switch providers when one fails
4. **Adding new providers** - Step-by-step pattern for expansion

---

## 📊 Decision Framework: Webhooks vs Polling

### When to Use Webhooks (Recommended)

**Your Current Choice:** ✅ Webhooks

**Best for:**
- Long-running operations (>30 seconds)
- Async video/image generation
- External AI providers with webhook support
- Cost-sensitive applications

**Pros:**
- ✅ No constant polling overhead
- ✅ Lower API usage and costs
- ✅ Immediate notification when job completes
- ✅ Scales to thousands of concurrent jobs
- ✅ Provider does the work (you just receive)

**Cons:**
- ⚠️ Requires public endpoint
- ⚠️ Must handle webhook retries
- ⚠️ Need HMAC signature validation
- ⚠️ More complex setup

**Pattern:**
```typescript
// Provider initiates → POST to your webhook → Update job status
Provider: Job complete → Webhook POST → Your backend → Update DB
```

---

### When to Use Polling

**Best for:**
- Short-running operations (<30 seconds)
- Providers without webhook support
- Internal/private APIs
- Development/testing environments

**Pros:**
- ✅ Simpler implementation
- ✅ No public endpoint needed
- ✅ Full control over timing
- ✅ Easier local development

**Cons:**
- ❌ Higher API usage (multiple status checks)
- ❌ Increased costs
- ❌ 1-5 second delay before detecting completion
- ❌ Doesn't scale well (N jobs = N polling loops)

**Pattern:**
```typescript
// Your backend initiates → Check status repeatedly
Your backend: Loop → Check status → Wait → Check again → Job complete
```

---

## 🏗️ Pattern 1: Multi-Provider Abstraction

### Provider Interface Pattern

Define a standard interface that all providers must implement:

```typescript
// _shared/providers/base-provider.ts

export interface VideoGenerationRequest {
  model_id: string
  prompt: string
  duration?: number
  aspect_ratio?: string
}

export interface VideoGenerationResponse {
  provider: string
  job_id: string
  status: 'queued' | 'processing' | 'completed' | 'failed'
  video_url?: string
  error?: string
  estimated_time?: number
}

export interface VideoProvider {
  name: string

  // Submit generation request
  generateVideo(
    request: VideoGenerationRequest
  ): Promise<VideoGenerationResponse>

  // Check job status (for polling)
  checkStatus(jobId: string): Promise<VideoGenerationResponse>

  // Validate webhook (for webhook-based providers)
  validateWebhook(
    signature: string,
    payload: string
  ): boolean

  // Parse webhook payload
  parseWebhook(payload: any): VideoGenerationResponse

  // Health check
  isHealthy(): Promise<boolean>
}
```

---

### Provider Implementation Examples

#### FalAI Provider (Webhook-based)

```typescript
// _shared/providers/fal-provider.ts
import { VideoProvider, VideoGenerationRequest, VideoGenerationResponse } from './base-provider.ts'
import { createHmac } from 'https://deno.land/std@0.177.0/crypto/mod.ts'

export class FalProvider implements VideoProvider {
  name = 'fal.ai'
  private apiKey: string
  private webhookSecret: string

  constructor() {
    this.apiKey = Deno.env.get('FAL_API_KEY')!
    this.webhookSecret = Deno.env.get('FAL_WEBHOOK_SECRET')!
  }

  async generateVideo(request: VideoGenerationRequest): Promise<VideoGenerationResponse> {
    const response = await fetch('https://queue.fal.run/fal-ai/video-model', {
      method: 'POST',
      headers: {
        'Authorization': `Key ${this.apiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        prompt: request.prompt,
        model_id: request.model_id,
        webhook_url: `${Deno.env.get('SUPABASE_URL')}/functions/v1/video-webhook`
      })
    })

    const data = await response.json()

    return {
      provider: 'fal.ai',
      job_id: data.request_id,
      status: 'queued',
      estimated_time: 120 // seconds
    }
  }

  async checkStatus(jobId: string): Promise<VideoGenerationResponse> {
    const response = await fetch(`https://queue.fal.run/fal-ai/video-model/requests/${jobId}`, {
      headers: { 'Authorization': `Key ${this.apiKey}` }
    })

    const data = await response.json()

    return {
      provider: 'fal.ai',
      job_id: jobId,
      status: data.status,
      video_url: data.output?.video_url
    }
  }

  validateWebhook(signature: string, payload: string): boolean {
    const hmac = createHmac('sha256', this.webhookSecret)
    hmac.update(payload)
    const expectedSignature = hmac.toString('hex')

    return signature === expectedSignature
  }

  parseWebhook(payload: any): VideoGenerationResponse {
    return {
      provider: 'fal.ai',
      job_id: payload.request_id,
      status: payload.status === 'completed' ? 'completed' : 'failed',
      video_url: payload.output?.video_url,
      error: payload.error
    }
  }

  async isHealthy(): Promise<boolean> {
    try {
      const response = await fetch('https://queue.fal.run/fal-ai/health', {
        headers: { 'Authorization': `Key ${this.apiKey}` }
      })
      return response.ok
    } catch {
      return false
    }
  }
}
```

---

#### Runway Provider (Webhook-based)

```typescript
// _shared/providers/runway-provider.ts
import { VideoProvider, VideoGenerationRequest, VideoGenerationResponse } from './base-provider.ts'

export class RunwayProvider implements VideoProvider {
  name = 'runway'
  private apiKey: string

  constructor() {
    this.apiKey = Deno.env.get('RUNWAY_API_KEY')!
  }

  async generateVideo(request: VideoGenerationRequest): Promise<VideoGenerationResponse> {
    const response = await fetch('https://api.runwayml.com/v1/generate', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.apiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        prompt: request.prompt,
        model: request.model_id,
        webhook_url: `${Deno.env.get('SUPABASE_URL')}/functions/v1/video-webhook`
      })
    })

    const data = await response.json()

    return {
      provider: 'runway',
      job_id: data.id,
      status: 'queued',
      estimated_time: 180
    }
  }

  async checkStatus(jobId: string): Promise<VideoGenerationResponse> {
    const response = await fetch(`https://api.runwayml.com/v1/generate/${jobId}`, {
      headers: { 'Authorization': `Bearer ${this.apiKey}` }
    })

    const data = await response.json()

    return {
      provider: 'runway',
      job_id: jobId,
      status: data.status,
      video_url: data.output_url
    }
  }

  validateWebhook(signature: string, payload: string): boolean {
    // Runway-specific validation
    const webhookSecret = Deno.env.get('RUNWAY_WEBHOOK_SECRET')!
    const hmac = createHmac('sha256', webhookSecret)
    hmac.update(payload)
    return signature === `sha256=${hmac.toString('hex')}`
  }

  parseWebhook(payload: any): VideoGenerationResponse {
    return {
      provider: 'runway',
      job_id: payload.id,
      status: payload.status === 'succeeded' ? 'completed' : 'failed',
      video_url: payload.output_url,
      error: payload.error_message
    }
  }

  async isHealthy(): Promise<boolean> {
    try {
      const response = await fetch('https://api.runwayml.com/v1/health', {
        headers: { 'Authorization': `Bearer ${this.apiKey}` }
      })
      return response.ok
    } catch {
      return false
    }
  }
}
```

---

#### Pika Provider (Polling-based fallback)

```typescript
// _shared/providers/pika-provider.ts
import { VideoProvider, VideoGenerationRequest, VideoGenerationResponse } from './base-provider.ts'

export class PikaProvider implements VideoProvider {
  name = 'pika'
  private apiKey: string

  constructor() {
    this.apiKey = Deno.env.get('PIKA_API_KEY')!
  }

  async generateVideo(request: VideoGenerationRequest): Promise<VideoGenerationResponse> {
    const response = await fetch('https://api.pika.art/v1/generate', {
      method: 'POST',
      headers: {
        'X-API-Key': this.apiKey,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        text: request.prompt,
        model: request.model_id
        // Note: Pika doesn't support webhooks, so no webhook_url
      })
    })

    const data = await response.json()

    return {
      provider: 'pika',
      job_id: data.job_id,
      status: 'processing',
      estimated_time: 90
    }
  }

  async checkStatus(jobId: string): Promise<VideoGenerationResponse> {
    const response = await fetch(`https://api.pika.art/v1/jobs/${jobId}`, {
      headers: { 'X-API-Key': this.apiKey }
    })

    const data = await response.json()

    return {
      provider: 'pika',
      job_id: jobId,
      status: data.status === 'done' ? 'completed' : data.status,
      video_url: data.result_url,
      error: data.error
    }
  }

  validateWebhook(): boolean {
    // Pika doesn't support webhooks
    return false
  }

  parseWebhook(): VideoGenerationResponse {
    throw new Error('Pika does not support webhooks')
  }

  async isHealthy(): Promise<boolean> {
    try {
      const response = await fetch('https://api.pika.art/v1/status', {
        headers: { 'X-API-Key': this.apiKey }
      })
      return response.ok
    } catch {
      return false
    }
  }
}
```

---

### Provider Registry Pattern

```typescript
// _shared/providers/registry.ts
import { VideoProvider } from './base-provider.ts'
import { FalProvider } from './fal-provider.ts'
import { RunwayProvider } from './runway-provider.ts'
import { PikaProvider } from './pika-provider.ts'

export class ProviderRegistry {
  private providers: Map<string, VideoProvider> = new Map()
  private healthStatus: Map<string, boolean> = new Map()

  constructor() {
    // Register all available providers
    this.register(new FalProvider())
    this.register(new RunwayProvider())
    this.register(new PikaProvider())
  }

  register(provider: VideoProvider) {
    this.providers.set(provider.name, provider)
    this.healthStatus.set(provider.name, true) // Assume healthy initially
  }

  get(name: string): VideoProvider | undefined {
    return this.providers.get(name)
  }

  async getHealthy(): Promise<VideoProvider | null> {
    // Return first healthy provider
    for (const [name, provider] of this.providers) {
      if (this.healthStatus.get(name)) {
        return provider
      }
    }
    return null
  }

  async checkHealth(providerName: string): Promise<boolean> {
    const provider = this.providers.get(providerName)
    if (!provider) return false

    const isHealthy = await provider.isHealthy()
    this.healthStatus.set(providerName, isHealthy)
    return isHealthy
  }

  async checkAllHealth(): Promise<Map<string, boolean>> {
    for (const name of this.providers.keys()) {
      await this.checkHealth(name)
    }
    return this.healthStatus
  }

  listProviders(): string[] {
    return Array.from(this.providers.keys())
  }
}

// Singleton instance
export const providerRegistry = new ProviderRegistry()
```

---

## 🔄 Pattern 2: Webhook Implementation

### Webhook Endpoint Pattern

```typescript
// POST /video-webhook
// Receives webhooks from ALL providers

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from '@supabase/supabase-js'
import { providerRegistry } from '../_shared/providers/registry.ts'

serve(async (req) => {
  try {
    // 1. Identify provider from header or payload
    const providerName = req.headers.get('X-Provider') || 'fal.ai'
    const provider = providerRegistry.get(providerName)

    if (!provider) {
      return new Response('Unknown provider', { status: 400 })
    }

    // 2. Validate webhook signature
    const signature = req.headers.get('X-Signature') || ''
    const rawBody = await req.text()

    if (!provider.validateWebhook(signature, rawBody)) {
      return new Response('Invalid signature', { status: 401 })
    }

    // 3. Parse webhook payload
    const payload = JSON.parse(rawBody)
    const result = provider.parseWebhook(payload)

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // 4. Check idempotency (prevent duplicate processing)
    const { data: existingLog } = await supabaseClient
      .from('idempotency_log')
      .select('response')
      .eq('idempotency_key', `webhook:${result.job_id}`)
      .single()

    if (existingLog) {
      console.log('Webhook already processed:', result.job_id)
      return new Response(JSON.stringify(existingLog.response), {
        headers: { 'X-Idempotent-Replay': 'true' }
      })
    }

    // 5. Update job status
    const { data: job } = await supabaseClient
      .from('video_jobs')
      .update({
        status: result.status,
        video_url: result.video_url,
        error_message: result.error,
        completed_at: result.status === 'completed' ? new Date().toISOString() : null
      })
      .eq('provider_job_id', result.job_id)
      .select()
      .single()

    if (!job) {
      return new Response('Job not found', { status: 404 })
    }

    // 6. Handle rollback if failed
    if (result.status === 'failed') {
      await supabaseClient.rpc('rollback_credits', {
        p_job_id: job.id,
        p_user_id: job.user_id,
        p_credits_to_refund: job.credits_used
      })
    }

    // 7. Store idempotency log
    await supabaseClient
      .from('idempotency_log')
      .insert({
        idempotency_key: `webhook:${result.job_id}`,
        response: { success: true, job_id: job.id },
        created_at: new Date().toISOString()
      })

    // 8. Log event
    console.log('Webhook processed:', {
      provider: result.provider,
      job_id: result.job_id,
      status: result.status
    })

    return new Response(JSON.stringify({ success: true }), {
      headers: { 'Content-Type': 'application/json' }
    })

  } catch (error) {
    console.error('Webhook error:', error)
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500
    })
  }
})
```

---

### Webhook Retry Handling

Providers will retry webhooks if your endpoint fails. Handle this gracefully:

```typescript
// Pattern: Idempotent webhook processing

async function processWebhook(jobId: string) {
  // 1. Check if already processed
  const existing = await checkIdempotency(`webhook:${jobId}`)
  if (existing) {
    return existing.response // Return cached result
  }

  // 2. Process webhook
  const result = await updateJobStatus(jobId)

  // 3. Store result for future retries
  await storeIdempotency(`webhook:${jobId}`, result)

  return result
}
```

**Why idempotency matters:**
- Provider retries webhook if your endpoint returns 5xx or times out
- Without idempotency: Credits refunded multiple times
- With idempotency: Same webhook processed once, subsequent retries return cached response

---

## 🔍 Pattern 3: Provider Health Monitoring

### Health Check Pattern

```typescript
// _shared/health-monitor.ts

export interface ProviderHealth {
  name: string
  status: 'healthy' | 'degraded' | 'down'
  response_time_ms: number
  last_check: string
  consecutive_failures: number
}

export class HealthMonitor {
  private healthCache: Map<string, ProviderHealth> = new Map()
  private readonly FAILURE_THRESHOLD = 3

  async checkProvider(provider: VideoProvider): Promise<ProviderHealth> {
    const startTime = Date.now()

    try {
      const isHealthy = await provider.isHealthy()
      const responseTime = Date.now() - startTime

      const current = this.healthCache.get(provider.name)
      const consecutiveFailures = isHealthy ? 0 : (current?.consecutive_failures || 0) + 1

      const health: ProviderHealth = {
        name: provider.name,
        status: this.determineStatus(isHealthy, consecutiveFailures, responseTime),
        response_time_ms: responseTime,
        last_check: new Date().toISOString(),
        consecutive_failures: consecutiveFailures
      }

      this.healthCache.set(provider.name, health)
      return health

    } catch (error) {
      const current = this.healthCache.get(provider.name)
      const consecutiveFailures = (current?.consecutive_failures || 0) + 1

      const health: ProviderHealth = {
        name: provider.name,
        status: 'down',
        response_time_ms: Date.now() - startTime,
        last_check: new Date().toISOString(),
        consecutive_failures: consecutiveFailures
      }

      this.healthCache.set(provider.name, health)
      return health
    }
  }

  private determineStatus(
    isHealthy: boolean,
    consecutiveFailures: number,
    responseTime: number
  ): 'healthy' | 'degraded' | 'down' {
    if (!isHealthy || consecutiveFailures >= this.FAILURE_THRESHOLD) {
      return 'down'
    }
    if (responseTime > 5000 || consecutiveFailures > 0) {
      return 'degraded'
    }
    return 'healthy'
  }

  getHealth(providerName: string): ProviderHealth | undefined {
    return this.healthCache.get(providerName)
  }

  getAllHealth(): ProviderHealth[] {
    return Array.from(this.healthCache.values())
  }
}

export const healthMonitor = new HealthMonitor()
```

---

### Scheduled Health Checks

```typescript
// Run health checks every 5 minutes
// Option 1: Supabase pg_cron
// Option 2: External cron service
// Option 3: Edge Function with Deno.cron

Deno.cron('provider-health-check', '*/5 * * * *', async () => {
  const providers = providerRegistry.listProviders()

  for (const name of providers) {
    const provider = providerRegistry.get(name)!
    const health = await healthMonitor.checkProvider(provider)

    // Alert if provider is down
    if (health.status === 'down') {
      await sendTelegramAlert({
        level: 'error',
        title: `Provider Down: ${name}`,
        message: `${health.consecutive_failures} consecutive failures`,
        metadata: {
          provider: name,
          last_check: health.last_check,
          response_time: health.response_time_ms
        }
      })
    }

    // Store health metrics
    await supabaseClient
      .from('provider_health_log')
      .insert({
        provider_name: name,
        status: health.status,
        response_time_ms: health.response_time_ms,
        checked_at: health.last_check
      })
  }
})
```

---

### Database Schema for Health Tracking

```sql
-- Track provider health over time
CREATE TABLE provider_health_log (
    id BIGSERIAL PRIMARY KEY,
    provider_name TEXT NOT NULL,
    status TEXT CHECK (status IN ('healthy', 'degraded', 'down')),
    response_time_ms INTEGER,
    consecutive_failures INTEGER DEFAULT 0,
    checked_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    INDEX idx_provider_health_recent (provider_name, checked_at DESC)
);

-- Get latest health status
CREATE OR REPLACE FUNCTION get_provider_health(p_provider_name TEXT)
RETURNS JSONB AS $$
DECLARE
    latest_health RECORD;
BEGIN
    SELECT * INTO latest_health
    FROM provider_health_log
    WHERE provider_name = p_provider_name
    ORDER BY checked_at DESC
    LIMIT 1;

    RETURN jsonb_build_object(
        'provider', p_provider_name,
        'status', latest_health.status,
        'last_check', latest_health.checked_at,
        'response_time', latest_health.response_time_ms
    );
END;
$$ LANGUAGE plpgsql;
```

---

## 🔄 Pattern 4: Automatic Failover

### Failover Decision Framework

**When to failover:**
1. ❌ Provider returns 5xx error → Failover immediately
2. ❌ Provider health check fails 3 times → Mark as down
3. ❌ Provider response time > 10 seconds → Try next provider
4. ⚠️ Provider returns 429 (rate limit) → Wait or failover

**When NOT to failover:**
1. ✅ Provider returns 4xx error (client error) → Don't retry
2. ✅ Provider is processing (webhook pending) → Wait
3. ✅ Only one provider available → Fail gracefully

---

### Failover Implementation Pattern

```typescript
// _shared/failover.ts

export async function generateVideoWithFailover(
  request: VideoGenerationRequest,
  preferredProvider?: string
): Promise<VideoGenerationResponse> {
  const providers = await getAvailableProviders(preferredProvider)

  if (providers.length === 0) {
    throw new Error('No healthy providers available')
  }

  let lastError: Error | null = null

  for (const provider of providers) {
    try {
      console.log(`Attempting video generation with: ${provider.name}`)

      // Check provider health before using
      const health = await healthMonitor.checkProvider(provider)
      if (health.status === 'down') {
        console.log(`Skipping unhealthy provider: ${provider.name}`)
        continue
      }

      // Attempt generation
      const response = await provider.generateVideo(request)

      console.log(`Success with provider: ${provider.name}`)
      return response

    } catch (error) {
      lastError = error
      console.error(`Provider ${provider.name} failed:`, error.message)

      // Mark as unhealthy if 5xx error
      if (error.message.includes('500') || error.message.includes('503')) {
        await healthMonitor.checkProvider(provider) // Force health check
      }

      // Continue to next provider
      continue
    }
  }

  // All providers failed
  throw new Error(`All providers failed. Last error: ${lastError?.message}`)
}

async function getAvailableProviders(
  preferredProvider?: string
): Promise<VideoProvider[]> {
  const allProviders = providerRegistry.listProviders()
  const healthyProviders: VideoProvider[] = []

  // Add preferred provider first (if healthy)
  if (preferredProvider) {
    const provider = providerRegistry.get(preferredProvider)
    if (provider) {
      const health = await healthMonitor.checkProvider(provider)
      if (health.status !== 'down') {
        healthyProviders.push(provider)
      }
    }
  }

  // Add other healthy providers
  for (const name of allProviders) {
    if (name === preferredProvider) continue // Already added

    const provider = providerRegistry.get(name)!
    const health = await healthMonitor.checkProvider(provider)

    if (health.status !== 'down') {
      healthyProviders.push(provider)
    }
  }

  return healthyProviders
}
```

---

### Database Schema for Failover Tracking

```sql
-- Track which provider was used for each job
ALTER TABLE video_jobs ADD COLUMN provider_name TEXT;
ALTER TABLE video_jobs ADD COLUMN provider_attempts INTEGER DEFAULT 1;
ALTER TABLE video_jobs ADD COLUMN failover_reason TEXT;

-- Log failover events
CREATE TABLE provider_failover_log (
    id BIGSERIAL PRIMARY KEY,
    job_id UUID REFERENCES video_jobs(id),
    from_provider TEXT,
    to_provider TEXT,
    reason TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);
```

---

### Updated Generation Endpoint with Failover

```typescript
// POST /generate-video (with failover support)

import { generateVideoWithFailover } from '../_shared/failover.ts'

serve(async (req) => {
  try {
    const { user_id, model_id, prompt } = await req.json()
    const idempotencyKey = req.headers.get('Idempotency-Key')

    // 1. Check idempotency
    // ... (same as before)

    // 2. Deduct credits
    const deductResult = await supabaseClient.rpc('deduct_credits', {
      p_user_id: user_id,
      p_amount: 1,
      p_reason: 'video_generation'
    })

    if (!deductResult.data.success) {
      return new Response(
        JSON.stringify({ error: deductResult.data.error }),
        { status: 400 }
      )
    }

    // 3. Generate video with automatic failover
    const result = await generateVideoWithFailover({
      model_id,
      prompt,
      duration: 5,
      aspect_ratio: '16:9'
    })

    // 4. Create job record
    const { data: job } = await supabaseClient
      .from('video_jobs')
      .insert({
        id: crypto.randomUUID(),
        user_id,
        model_id,
        prompt,
        provider_name: result.provider, // Track which provider
        provider_job_id: result.job_id,
        status: result.status,
        credits_used: 1
      })
      .select()
      .single()

    return new Response(
      JSON.stringify({
        job_id: job.id,
        provider: result.provider, // Tell client which provider
        status: result.status,
        estimated_time: result.estimated_time
      }),
      { headers: { 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    // Rollback credits on complete failure
    await supabaseClient.rpc('rollback_credits', {
      p_user_id: user_id,
      p_amount: 1
    })

    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500 }
    )
  }
})
```

---

## 📋 Pattern 5: Adding New Providers (Step-by-Step)

### Checklist for Adding a New Provider

When you want to add a new AI provider (e.g., "StabilityAI"):

#### Step 1: Implement Provider Interface

```typescript
// _shared/providers/stability-provider.ts
import { VideoProvider, VideoGenerationRequest, VideoGenerationResponse } from './base-provider.ts'

export class StabilityProvider implements VideoProvider {
  name = 'stability'

  async generateVideo(request: VideoGenerationRequest): Promise<VideoGenerationResponse> {
    // Implement provider-specific API call
  }

  async checkStatus(jobId: string): Promise<VideoGenerationResponse> {
    // Implement status check
  }

  validateWebhook(signature: string, payload: string): boolean {
    // Implement webhook validation (or return false if no webhooks)
  }

  parseWebhook(payload: any): VideoGenerationResponse {
    // Parse webhook payload
  }

  async isHealthy(): Promise<boolean> {
    // Implement health check
  }
}
```

---

#### Step 2: Register Provider

```typescript
// _shared/providers/registry.ts

import { StabilityProvider } from './stability-provider.ts'

constructor() {
  this.register(new FalProvider())
  this.register(new RunwayProvider())
  this.register(new PikaProvider())
  this.register(new StabilityProvider()) // Add new provider
}
```

---

#### Step 3: Add Environment Variables

```bash
# Add provider credentials to Supabase secrets
supabase secrets set STABILITY_API_KEY="your-api-key"
supabase secrets set STABILITY_WEBHOOK_SECRET="your-webhook-secret"
```

---

#### Step 4: Test Provider

```typescript
// Test new provider
const provider = new StabilityProvider()

// Test health check
const isHealthy = await provider.isHealthy()
console.log('Stability health:', isHealthy)

// Test generation
const result = await provider.generateVideo({
  model_id: 'stable-video-1.0',
  prompt: 'test video',
  duration: 5
})
console.log('Generation result:', result)
```

---

#### Step 5: Update Database (Optional)

```sql
-- Add provider to models table
INSERT INTO models (id, name, provider, credits_per_generation)
VALUES (
  'stability-video-1.0',
  'Stability Video 1.0',
  'stability',
  1
);
```

---

#### Step 6: Deploy and Monitor

```bash
# Deploy Edge Functions
supabase functions deploy

# Monitor health
curl https://your-project.supabase.co/functions/v1/provider-health

# Test generation with new provider
curl -X POST https://your-project.supabase.co/functions/v1/generate-video \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "uuid",
    "model_id": "stability-video-1.0",
    "prompt": "test video"
  }'
```

---

## 🎯 Complete Implementation Summary

### What You Have Now (Current State)

✅ **Single Provider (FalAI)**
- Webhook integration
- Retry logic (3 attempts)
- HMAC validation
- Idempotency

### What These Patterns Add

🟢 **Multi-Provider Support**
- Provider interface for abstraction
- Easy addition of Runway, Pika, StabilityAI
- Provider registry

🟢 **Health Monitoring**
- Automatic health checks every 5 minutes
- Status tracking (healthy/degraded/down)
- Telegram alerts for outages

🟢 **Automatic Failover**
- Try next provider on failure
- Intelligent provider selection
- Failure tracking and logging

### Architecture Diagram

```
User Request
    ↓
generate-video endpoint
    ↓
generateVideoWithFailover()
    ↓
┌─────────────────────────────────┐
│ Try Provider 1 (FalAI)          │
│  ✓ Check health                 │
│  ✓ Call API                     │
│  ✓ Return job_id                │
└─────────────────────────────────┘
    ↓ (if fails)
┌─────────────────────────────────┐
│ Try Provider 2 (Runway)         │
│  ✓ Check health                 │
│  ✓ Call API                     │
│  ✓ Return job_id                │
└─────────────────────────────────┘
    ↓ (if fails)
┌─────────────────────────────────┐
│ Try Provider 3 (Pika)           │
│  ✓ Check health                 │
│  ✓ Call API                     │
│  ✓ Return job_id                │
└─────────────────────────────────┘
    ↓
Job Created in Database
    ↓
... (async processing) ...
    ↓
Provider Sends Webhook
    ↓
video-webhook endpoint
    ↓
┌─────────────────────────────────┐
│ 1. Validate signature           │
│ 2. Check idempotency            │
│ 3. Update job status            │
│ 4. Rollback credits if failed   │
└─────────────────────────────────┘
```

---

## 📋 Template Checklist for AI Agents

When the AI agent system needs to implement external API integration, use this checklist:

### Phase 1: Provider Abstraction
- [ ] Create base provider interface
- [ ] Implement first provider class
- [ ] Create provider registry
- [ ] Test provider integration

### Phase 2: Webhook System
- [ ] Create webhook endpoint
- [ ] Implement HMAC validation
- [ ] Add idempotency protection
- [ ] Test webhook reception

### Phase 3: Health Monitoring
- [ ] Implement health check methods
- [ ] Create health monitor class
- [ ] Schedule periodic health checks
- [ ] Add health status database table

### Phase 4: Failover Logic
- [ ] Implement failover function
- [ ] Add provider priority logic
- [ ] Create failover logging
- [ ] Test multi-provider scenarios

### Phase 5: Adding Providers
- [ ] Implement new provider class
- [ ] Register in registry
- [ ] Add credentials to secrets
- [ ] Test and deploy

---

## 🔐 Security Checklist

- [ ] All webhook signatures validated with HMAC
- [ ] Webhook secrets stored in environment variables
- [ ] API keys never exposed to client
- [ ] Idempotency prevents duplicate processing
- [ ] Rate limiting on webhook endpoint
- [ ] Health checks use authenticated endpoints
- [ ] Provider credentials rotated regularly

---

**This document provides patterns for the AI agent system to implement robust, scalable, multi-provider external API integrations with webhooks, health monitoring, and automatic failover.**
