# Backend Architecture: Operations & Testing

**Part 6 of 6** - Error handling, logging, admin tools, deployment, testing, and performance

**Related Documents:**
- [backend-INDEX.md](./backend-INDEX.md) - Complete documentation index
- [backend-3-generation-workflow.md](./backend-3-generation-workflow.md) - Retry logic
- [backend-5-credit-system.md](./backend-5-credit-system.md) - Admin refunds

---

## 🌍 Error Handling with i18n (Phase 7)

### Error Code System

**Purpose:** Standardized error codes with internationalized messages

File: `supabase/functions/_shared/error-codes.ts`

```typescript
export enum ErrorCode {
  // Client errors (4xxx)
  ERR_4001 = 'ERR_4001', // Insufficient credits
  ERR_4002 = 'ERR_4002', // Invalid model
  ERR_4003 = 'ERR_4003', // Invalid prompt
  ERR_4004 = 'ERR_4004', // Rate limit exceeded
  ERR_4005 = 'ERR_4005', // Unauthorized

  // Provider errors (5xxx)
  ERR_5001 = 'ERR_5001', // Provider timeout
  ERR_5002 = 'ERR_5002', // Provider unavailable
  ERR_5003 = 'ERR_5003', // Provider rejected request

  // System errors (6xxx)
  ERR_6001 = 'ERR_6001', // Database error
  ERR_6002 = 'ERR_6002', // Storage error
  ERR_6003 = 'ERR_6003', // Internal server error
}

export const ErrorMessages: Record<ErrorCode, Record<string, string>> = {
  [ErrorCode.ERR_4001]: {
    en: 'You need {required} credits, but only have {available}. Please purchase more credits.',
    tr: '{required} krediye ihtiyacınız var, ancak sadece {available} krediniz var. Lütfen daha fazla kredi satın alın.',
    es: 'Necesitas {required} créditos, pero solo tienes {available}. Por favor compra más créditos.'
  },
  [ErrorCode.ERR_4002]: {
    en: 'The selected model is not available.',
    tr: 'Seçilen model mevcut değil.',
    es: 'El modelo seleccionado no está disponible.'
  },
  // ... more error messages
}
```

### Error Response Builder

File: `supabase/functions/_shared/error-response.ts`

```typescript
import { ErrorCode, ErrorMessages } from './error-codes.ts'

interface ErrorResponseOptions {
  code: ErrorCode
  language?: 'en' | 'tr' | 'es'
  variables?: Record<string, string | number>
  details?: any
}

export function createErrorResponse(options: ErrorResponseOptions): Response {
  const {
    code,
    language = 'en',
    variables = {},
    details
  } = options

  let message = ErrorMessages[code][language] || ErrorMessages[code]['en']

  // Replace variables in message
  Object.entries(variables).forEach(([key, value]) => {
    message = message.replace(`{${key}}`, String(value))
  })

  const statusCode = getStatusCode(code)

  return new Response(
    JSON.stringify({
      error: {
        code,
        message,
        details
      }
    }),
    {
      status: statusCode,
      headers: { 'Content-Type': 'application/json' }
    }
  )
}

function getStatusCode(code: ErrorCode): number {
  if (code.startsWith('ERR_4')) return 400
  if (code.startsWith('ERR_5')) return 502
  if (code.startsWith('ERR_6')) return 500
  return 500
}
```

### Usage in Endpoints

```typescript
import { createErrorResponse } from '../_shared/error-response.ts'
import { ErrorCode } from '../_shared/error-codes.ts'

// Get user's preferred language
const userLanguage = req.headers.get('Accept-Language')?.split(',')[0]?.substring(0, 2) || 'en'
const language = ['en', 'tr', 'es'].includes(userLanguage) ? userLanguage : 'en'

// Check credits
if (!deductResult.success) {
  return createErrorResponse({
    code: ErrorCode.ERR_4001,
    language,
    variables: {
      required: model.cost_per_generation,
      available: deductResult.current_credits || 0
    }
  })
}
```

### Error Logging

Create migration: `supabase/migrations/006_create_error_log.sql`

```sql
CREATE TABLE IF NOT EXISTS error_log (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  error_code TEXT NOT NULL,
  endpoint TEXT NOT NULL,
  request_data JSONB,
  error_details JSONB,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_error_code ON error_log(error_code);
CREATE INDEX idx_error_user ON error_log(user_id, created_at DESC);
```

---

## 🔄 Retry Logic for External APIs (Phase 6)

### Exponential Backoff Utility

File: `supabase/functions/_shared/fetch-with-retry.ts`

```typescript
interface RetryConfig {
  maxRetries: number
  initialDelay: number
  maxDelay: number
  retryableStatusCodes: number[]
}

const defaultConfig: RetryConfig = {
  maxRetries: 3,
  initialDelay: 2000, // 2 seconds
  maxDelay: 30000, // 30 seconds
  retryableStatusCodes: [408, 429, 500, 502, 503, 504]
}

export async function fetchWithRetry(
  url: string,
  options: RequestInit = {},
  config: Partial<RetryConfig> = {}
): Promise<Response> {
  const finalConfig = { ...defaultConfig, ...config }
  let lastError: Error | null = null

  for (let attempt = 0; attempt <= finalConfig.maxRetries; attempt++) {
    try {
      const controller = new AbortController()
      const timeout = setTimeout(() => controller.abort(), 30000)

      const response = await fetch(url, {
        ...options,
        signal: controller.signal
      })

      clearTimeout(timeout)

      // Success
      if (response.ok) {
        return response
      }

      // Non-retryable error
      if (!finalConfig.retryableStatusCodes.includes(response.status)) {
        return response
      }

      // Retryable error
      lastError = new Error(
        `HTTP ${response.status}: ${response.statusText}`
      )

    } catch (error) {
      lastError = error as Error
    }

    // Don't retry on last attempt
    if (attempt === finalConfig.maxRetries) {
      break
    }

    // Calculate exponential backoff
    const delay = Math.min(
      finalConfig.initialDelay * Math.pow(2, attempt),
      finalConfig.maxDelay
    )

    console.log(`Retry attempt ${attempt + 1} after ${delay}ms`)
    await new Promise(resolve => setTimeout(resolve, delay))
  }

  throw lastError || new Error('Request failed after retries')
}
```

### Usage in Provider Calls

```typescript
import { fetchWithRetry } from '../_shared/fetch-with-retry.ts'

async function callFalAI(modelId: string, prompt: string, settings: any) {
  const apiKey = Deno.env.get('FALAI_API_KEY')

  const response = await fetchWithRetry(
    `https://fal.run/${modelId}`,
    {
      method: 'POST',
      headers: {
        'Authorization': `Key ${apiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        prompt: prompt,
        ...settings
      })
    },
    {
      maxRetries: 3,
      initialDelay: 2000,
      maxDelay: 30000
    }
  )

  if (!response.ok) {
    throw new Error(`FalAI error: ${response.statusText}`)
  }

  const data = await response.json()

  return {
    job_id: data.request_id || data.id
  }
}
```

---

## 🛡️ IP-Based Rate Limiting (Phase 8)

### Rate Limit Table

Create migration: `supabase/migrations/007_create_rate_limit.sql`

```sql
CREATE TABLE IF NOT EXISTS rate_limit_log (
  id BIGSERIAL PRIMARY KEY,
  ip_address INET NOT NULL,
  action TEXT NOT NULL, -- 'video_generation', 'credit_purchase', etc.
  user_id UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_rate_limit_ip_action ON rate_limit_log(ip_address, action, created_at);

-- Auto-cleanup old rate limit logs (keep 7 days)
CREATE OR REPLACE FUNCTION cleanup_rate_limit_logs()
RETURNS void AS $$
BEGIN
  DELETE FROM rate_limit_log
  WHERE created_at < now() - INTERVAL '7 days';
END;
$$ LANGUAGE plpgsql;
```

### Rate Limiter Middleware

File: `supabase/functions/_shared/rate-limiter.ts`

```typescript
interface RateLimitConfig {
  action: string
  maxRequests: number
  windowMinutes: number
}

export async function checkRateLimit(
  req: Request,
  config: RateLimitConfig,
  supabaseClient: any
): Promise<{ allowed: boolean; retryAfter?: number }> {

  // Get client IP (handle proxies)
  const forwardedFor = req.headers.get('X-Forwarded-For')
  const ip = forwardedFor ? forwardedFor.split(',')[0].trim() :
             req.headers.get('CF-Connecting-IP') || '0.0.0.0'

  // Count recent requests
  const windowStart = new Date(Date.now() - config.windowMinutes * 60 * 1000)

  const { count, error } = await supabaseClient
    .from('rate_limit_log')
    .select('*', { count: 'exact', head: true })
    .eq('ip_address', ip)
    .eq('action', config.action)
    .gte('created_at', windowStart.toISOString())

  if (error) throw error

  if (count >= config.maxRequests) {
    // Calculate retry-after seconds
    const oldestRequest = await supabaseClient
      .from('rate_limit_log')
      .select('created_at')
      .eq('ip_address', ip)
      .eq('action', config.action)
      .gte('created_at', windowStart.toISOString())
      .order('created_at', { ascending: true })
      .limit(1)
      .single()

    const retryAfter = Math.ceil(
      (new Date(oldestRequest.data.created_at).getTime() +
      config.windowMinutes * 60 * 1000 -
      Date.now()) / 1000
    )

    return { allowed: false, retryAfter }
  }

  // Log this request
  await supabaseClient.from('rate_limit_log').insert({
    ip_address: ip,
    action: config.action
  })

  return { allowed: true }
}
```

### Usage in Endpoints

```typescript
import { checkRateLimit } from '../_shared/rate-limiter.ts'
import { createErrorResponse } from '../_shared/error-response.ts'
import { ErrorCode } from '../_shared/error-codes.ts'

serve(async (req) => {
  try {
    const supabaseClient = createClient(...)

    // Check rate limit: max 10 video generations per hour
    const rateLimitCheck = await checkRateLimit(
      req,
      {
        action: 'video_generation',
        maxRequests: 10,
        windowMinutes: 60
      },
      supabaseClient
    )

    if (!rateLimitCheck.allowed) {
      return createErrorResponse({
        code: ErrorCode.ERR_4004,
        variables: { seconds: rateLimitCheck.retryAfter },
        details: { retry_after: rateLimitCheck.retryAfter }
      })
    }

    // Continue with video generation...
  } catch (error) {
    // ... error handling
  }
})
```

---

## 🔧 Admin Tools (Phase 9)

### Admin Authentication

File: `supabase/functions/_shared/admin-auth.ts`

```typescript
export async function requireAdmin(
  req: Request,
  supabaseClient: any
): Promise<{ admin: any }> {

  const authHeader = req.headers.get('Authorization')

  if (!authHeader) {
    throw new Error('Missing Authorization header')
  }

  const token = authHeader.replace('Bearer ', '')

  // Get user from token
  const { data: { user }, error } = await supabaseClient.auth.getUser(token)

  if (error || !user) {
    throw new Error('Invalid token')
  }

  // Check if user is admin
  const { data: userData } = await supabaseClient
    .from('users')
    .select('is_admin')
    .eq('id', user.id)
    .single()

  if (!userData?.is_admin) {
    throw new Error('Admin access required')
  }

  return { admin: user }
}
```

### Admin Actions Table

Create migration: `supabase/migrations/008_create_admin_tables.sql`

```sql
CREATE TABLE IF NOT EXISTS admin_actions (
  id BIGSERIAL PRIMARY KEY,
  admin_user_id UUID NOT NULL REFERENCES users(id),
  action_type TEXT NOT NULL CHECK (action_type IN (
    'credit_refund',
    'credit_adjustment',
    'model_disable',
    'model_enable',
    'user_ban',
    'user_unban'
  )),
  target_user_id UUID REFERENCES users(id),
  target_model_id UUID REFERENCES models(id),
  amount INTEGER, -- For credit adjustments
  reason TEXT NOT NULL,
  details JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_admin_actions_admin ON admin_actions(admin_user_id, created_at DESC);
CREATE INDEX idx_admin_actions_target_user ON admin_actions(target_user_id, created_at DESC);

-- Add admin flag to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT false;
```

### Admin Credit Refund Endpoint

File: `supabase/functions/admin-refund-credits/index.ts`

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { requireAdmin } from '../_shared/admin-auth.ts'

serve(async (req) => {
  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // Verify admin
    const { admin } = await requireAdmin(req, supabaseClient)

    const { user_id, amount, reason } = await req.json()

    // Add credits
    const { data: result } = await supabaseClient.rpc('add_credits', {
      p_user_id: user_id,
      p_amount: amount,
      p_reason: `admin_refund: ${reason}`
    })

    if (!result.success) {
      return new Response(
        JSON.stringify({ error: result.error }),
        { status: 400 }
      )
    }

    // Log admin action
    await supabaseClient.from('admin_actions').insert({
      admin_user_id: admin.id,
      action_type: 'credit_refund',
      target_user_id: user_id,
      amount: amount,
      reason: reason
    })

    return new Response(
      JSON.stringify({
        success: true,
        new_balance: result.credits_remaining
      }),
      { headers: { 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: error.message.includes('Admin') ? 403 : 500 }
    )
  }
})
```

---

## 📊 Logging & Monitoring

### Structured Logging

File: `supabase/functions/_shared/logger.ts`

```typescript
export function logEvent(
  eventType: string,
  data: Record<string, any>,
  level: 'info' | 'error' | 'warn' = 'info'
) {
  const logEntry = {
    timestamp: new Date().toISOString(),
    level,
    event: eventType,
    ...data,
    environment: Deno.env.get('ENVIRONMENT')
  }
  
  console.log(JSON.stringify(logEntry))
}
```

### Key Metrics to Track

1. **Video Generation:**
   - Generation requests
   - Success/failure rates
   - Average generation time
   - Provider response times

2. **Credits:**
   - Credits deducted
   - Credits added (IAP, refunds)
   - Credit balance distribution
   - Purchase conversion rate

3. **Errors:**
   - Error codes and frequencies
   - Failed API calls
   - Provider timeouts

4. **Performance:**
   - API response times
   - Database query times
   - Rate limit hits

---

## 🚀 Deployment Phases

### Phase 0: Setup & Infrastructure (2-3 days)
- Create Supabase project
- Set up database schema
- Create stored procedures
- Enable RLS policies
- Configure storage buckets

### Phase 0.5: Security Essentials (2 days)
- Implement Apple IAP verification
- Implement DeviceCheck verification
- Add anonymous auth
- Add token refresh logic

### Phase 1: Core APIs (3-4 days)
- Device check endpoint
- Credit management endpoints
- Get models endpoint
- User profile endpoint

### Phase 2: Video Generation (4-5 days)
- Generate video endpoint
- Get video status endpoint
- Provider integration
- Idempotency logic

### Phase 3: History & User (2 days)
- Get video jobs endpoint
- Delete video job endpoint
- User profile management

### Phase 4: Integration & Testing (3-4 days)
- Connect iOS app
- End-to-end testing
- Edge case testing
- Security audit

### Phase 5: Webhooks (3-4 days)
- Webhook delivery system
- APNs push notifications
- Replace polling

### Phase 6: Retry Logic (2-3 days)
- Exponential backoff
- Timeout handling
- Provider retry logic

### Phase 7: Error i18n (2-3 days)
- Error code system
- Localized messages
- Error logging

### Phase 8: Rate Limiting (2 days)
- IP-based rate limiting
- Rate limit headers
- Auto-cleanup

### Phase 9: Admin Tools (3-4 days)
- Admin authentication
- Credit refund endpoint
- Model management
- User stats

---

## ✅ Testing Checklist

### Security Testing
- [ ] RLS policies prevent unauthorized access
- [ ] Apple IAP receipts validated server-side
- [ ] DeviceCheck prevents duplicate initial grants
- [ ] No API keys exposed in client code
- [ ] Token refresh works correctly
- [ ] Idempotency prevents double-charging

### Functionality Testing
- [ ] Guest user onboarding works
- [ ] Video generation with idempotency
- [ ] Credit purchase flow
- [ ] Apple Sign-In flow
- [ ] History loading with pagination
- [ ] Rollback on generation failure

### Edge Cases
- [ ] Insufficient credits
- [ ] Network timeout during generation
- [ ] Provider API failure
- [ ] Duplicate transaction_id
- [ ] Duplicate idempotency key
- [ ] Concurrent video generations
- [ ] Token expiration during request

### Performance Testing
- [ ] 100+ video jobs in history
- [ ] Pagination works correctly
- [ ] Concurrent requests handled
- [ ] Database queries < 100ms
- [ ] Stored procedures handle concurrency

---

## ⚡ Performance Considerations

### Database Optimization
- Use indexes on frequently queried columns
- Use partial indexes for filtered queries
- Monitor query performance
- Vacuum and analyze regularly

### API Optimization
- Implement ETag caching for models (Phase 5)
- Use pagination for list endpoints
- Cache credit balance (short TTL)
- Optimize database queries

### Scaling Considerations
- Connection pooling (Supavisor)
- Read replicas for analytics
- Redis caching (future)
- CDN for video files (future)

---

## 🔧 Maintenance Tasks

### Daily
- Monitor error logs
- Check rate limit hits
- Review failed generations

### Weekly
- Clean up expired idempotency keys
- Review admin actions
- Analyze error patterns

### Monthly
- Review performance metrics
- Optimize slow queries
- Update dependencies
- Security audit

---

## 🚀 Next Steps

1. **Deploy Phase 0-4** - MVP with security
2. **Monitor metrics** - Track errors, performance
3. **Implement Phases 5-9** - Production features
4. **Scale optimizations** - When needed

---

**Related Documentation:**
- [backend-INDEX.md](./backend-INDEX.md) - Complete documentation index
- [backend-3-generation-workflow.md](./backend-3-generation-workflow.md) - Generation workflow
- [backend-5-credit-system.md](./backend-5-credit-system.md) - Credit system

