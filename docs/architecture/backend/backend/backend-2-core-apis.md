# Backend Architecture: Core APIs

**Part 2 of 6** - Core API endpoints, request/response formats, and authentication

**Related Documents:**
- [backend-INDEX.md](./backend-INDEX.md) - Complete documentation index
- [backend-1-overview-database.md](./backend-1-overview-database.md) - Database schema
- [backend-4-auth-security.md](./backend-4-auth-security.md) - Authentication details
- [backend-8-rate-limiting.md](./backend-8-rate-limiting.md) - Rate limiting (Phase 8)

---

## 📡 Core API Endpoints

### 1. Device Check Endpoint

**Purpose:** Guest user onboarding and device verification

**Endpoint:** `POST /functions/v1/device-check`

**Request:**
```json
{
  "device_id": "uuid-string",
  "device_token": "apple-devicecheck-token"
}
```

**Response (New User):**
```json
{
  "user_id": "uuid",
  "credits_remaining": 10,
  "is_new": true,
  "session": {
    "access_token": "jwt-token",
    "refresh_token": "refresh-token",
    "expires_at": 1234567890
  }
}
```

**Response (Existing User):**
```json
{
  "user_id": "uuid",
  "credits_remaining": 15,
  "is_new": false
}
```

**Implementation:**

File: `supabase/functions/device-check/index.ts`

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { verifyDeviceToken } from '../_shared/device-check.ts'

serve(async (req) => {
  try {
    const { device_id, device_token } = await req.json()
    
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )
    
    // 1. Verify device token with Apple DeviceCheck
    const deviceCheck = await verifyDeviceToken(device_token, device_id)
    
    if (!deviceCheck.valid) {
      return new Response(
        JSON.stringify({ error: 'Invalid device' }),
        { status: 403 }
      )
    }
    
    // 2. Check if user exists
    const { data: existingUser } = await supabaseClient
      .from('users')
      .select('*')
      .eq('device_id', device_id)
      .single()
    
    if (existingUser) {
      return new Response(
        JSON.stringify({
          user_id: existingUser.id,
          credits_remaining: existingUser.credits_remaining,
          is_new: false
        }),
        { headers: { 'Content-Type': 'application/json' } }
      )
    }
    
    // 3. Create anonymous auth session for new guest
    const { data: authData, error: authError } = await supabaseClient.auth.signInAnonymously()
    
    if (authError) throw authError
    
    // 4. Create user record with auth.uid
    const { data: newUser, error: userError } = await supabaseClient
      .from('users')
      .insert({
        id: authData.user.id,
        device_id: device_id,
        is_guest: true,
        tier: 'free',
        credits_remaining: 10,
        credits_total: 10,
        initial_grant_claimed: true
      })
      .select()
      .single()
    
    if (userError) throw userError
    
    // 5. Log initial credit grant
    await supabaseClient.from('quota_log').insert({
      user_id: newUser.id,
      change: 10,
      reason: 'initial_grant',
      balance_after: 10
    })
    
    // 6. Return user data + auth session
    return new Response(
      JSON.stringify({
        user_id: newUser.id,
        credits_remaining: newUser.credits_remaining,
        is_new: true,
        session: authData.session
      }),
      { headers: { 'Content-Type': 'application/json' } }
    )
    
  } catch (error) {
    console.error('Device check error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500 }
    )
  }
})
```

**See:** [backend-4-auth-security.md](./backend-4-auth-security.md) for DeviceCheck verification details.

---

### 2. Get User Credits Endpoint

**Purpose:** Query current credit balance

**Endpoint:** `GET /functions/v1/get-user-credits?user_id=<uuid>`

**Request Headers:**
```
Authorization: Bearer <jwt-token>
```

**Response:**
```json
{
  "credits_remaining": 15
}
```

**Implementation:**

File: `supabase/functions/get-user-credits/index.ts`

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { getAuthenticatedUser } from '../_shared/auth-helper.ts'

serve(async (req) => {
  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )
    
    // Get authenticated user
    const user = await getAuthenticatedUser(req, supabaseClient)
    
    const { data: userData, error } = await supabaseClient
      .from('users')
      .select('credits_remaining')
      .eq('id', user.id)
      .single()
    
    if (error) throw error
    
    return new Response(
      JSON.stringify({ credits_remaining: userData.credits_remaining }),
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

---

### 3. Get Models Endpoint

**Purpose:** List available video generation models

**Endpoint:** `GET /functions/v1/get-models`

**Request:** No authentication required (public endpoint)

**Response:**
```json
{
  "models": [
    {
      "id": "uuid",
      "name": "Cinematic",
      "category": "cinematic",
      "description": "Hollywood-style videos",
      "cost_per_generation": 4,
      "provider": "fal",
      "provider_model_id": "fal-ai/veo3.1",
      "is_featured": true,
      "is_available": true,
      "thumbnail_url": "https://...",
      "created_at": "2025-01-01T00:00:00Z"
    }
  ]
}
```

**Implementation:**

File: `supabase/functions/get-models/index.ts`

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )
    
    const { data: models, error } = await supabaseClient
      .from('models')
      .select('*')
      .eq('is_available', true)
      .order('is_featured', { ascending: false })
      .order('name', { ascending: true })
    
    if (error) throw error
    
    return new Response(
      JSON.stringify({ models }),
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

**Caching:** Consider adding ETag support for better performance (see Phase 5 optimizations).

---

### 4. Get User Profile Endpoint

**Purpose:** Get complete user profile data

**Endpoint:** `GET /functions/v1/get-user-profile?user_id=<uuid>`

**Request Headers:**
```
Authorization: Bearer <jwt-token>
```

**Response:**
```json
{
  "id": "uuid",
  "email": "user@example.com",
  "device_id": "uuid",
  "apple_sub": "apple-sub-id",
  "is_guest": false,
  "tier": "free",
  "credits_remaining": 15,
  "credits_total": 25,
  "initial_grant_claimed": true,
  "language": "en",
  "theme_preference": "system",
  "created_at": "2025-01-01T00:00:00Z",
  "updated_at": "2025-01-01T00:00:00Z"
}
```

**Implementation:**

File: `supabase/functions/get-user-profile/index.ts`

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { getAuthenticatedUser } from '../_shared/auth-helper.ts'

serve(async (req) => {
  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )
    
    const user = await getAuthenticatedUser(req, supabaseClient)
    
    const { data: userData, error } = await supabaseClient
      .from('users')
      .select('*')
      .eq('id', user.id)
      .single()
    
    if (error) throw error
    
    return new Response(
      JSON.stringify(userData),
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

---

### 5. Get Video Jobs (History) Endpoint

**Purpose:** List user's video generation history

**Endpoint:** `GET /functions/v1/get-video-jobs?user_id=<uuid>&limit=20&offset=0`

**Request Headers:**
```
Authorization: Bearer <jwt-token>
```

**Query Parameters:**
- `user_id` (required): User UUID
- `limit` (optional): Number of results (default: 20, max: 100)
- `offset` (optional): Pagination offset (default: 0)

**Response:**
```json
{
  "jobs": [
    {
      "job_id": "uuid",
      "prompt": "A cat playing piano",
      "model_name": "Cinematic",
      "credits_used": 4,
      "status": "completed",
      "video_url": "https://...",
      "thumbnail_url": "https://...",
      "created_at": "2025-01-01T00:00:00Z"
    }
  ],
  "total": 42,
  "has_more": true
}
```

**Implementation:**

File: `supabase/functions/get-video-jobs/index.ts`

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { getAuthenticatedUser } from '../_shared/auth-helper.ts'

serve(async (req) => {
  try {
    const url = new URL(req.url)
    const limit = parseInt(url.searchParams.get('limit') || '20')
    const offset = parseInt(url.searchParams.get('offset') || '0')
    
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )
    
    const user = await getAuthenticatedUser(req, supabaseClient)
    
    const { data: jobs, error, count } = await supabaseClient
      .from('video_jobs')
      .select(`
        job_id,
        prompt,
        status,
        video_url,
        thumbnail_url,
        credits_used,
        created_at,
        models (name)
      `, { count: 'exact' })
      .eq('user_id', user.id)
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1)
    
    if (error) throw error
    
    // Transform to match iOS model
    const transformedJobs = jobs.map(job => ({
      job_id: job.job_id,
      prompt: job.prompt,
      model_name: job.models?.name || 'Unknown Model',
      credits_used: job.credits_used,
      status: job.status,
      video_url: job.video_url,
      thumbnail_url: job.thumbnail_url,
      created_at: job.created_at
    }))
    
    return new Response(
      JSON.stringify({
        jobs: transformedJobs,
        total: count || 0,
        has_more: (count || 0) > offset + limit
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

---

## 🔐 API Authentication Flow

### Authentication Methods

1. **Guest Users (Anonymous)**
   - Use anonymous JWT from `device-check` endpoint
   - Token stored in iOS Keychain
   - Sent in `Authorization: Bearer <token>` header

2. **Authenticated Users (Apple Sign-In)**
   - Use authenticated JWT from Supabase Auth
   - Token stored in iOS Keychain
   - Sent in `Authorization: Bearer <token>` header

### Token Refresh

See [backend-4-auth-security.md](./backend-4-auth-security.md) for token refresh implementation.

### Auth Helper Utility

File: `supabase/functions/_shared/auth-helper.ts`

```typescript
import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'

export async function getAuthenticatedUser(
  req: Request,
  supabaseClient: SupabaseClient
) {
  const authHeader = req.headers.get('Authorization')
  
  if (!authHeader) {
    throw new Error('Missing Authorization header')
  }
  
  const token = authHeader.replace('Bearer ', '')
  
  // Get user from token
  const { data: { user }, error } = await supabaseClient.auth.getUser(token)
  
  if (error || !user) {
    throw new Error('Invalid or expired token')
  }
  
  return user
}
```

---

## 🚦 Rate Limiting

**Note:** Rate limiting is implemented in Phase 8. See [backend-8-rate-limiting.md](./backend-8-rate-limiting.md) for details.

**Basic Implementation:**

```typescript
import { checkRateLimit } from '../_shared/rate-limiter.ts'

// Check rate limit: max 10 requests per hour
const rateLimitCheck = await checkRateLimit(
  req,
  {
    action: 'api_request',
    maxRequests: 10,
    windowMinutes: 60
  },
  supabaseClient
)

if (!rateLimitCheck.allowed) {
  return new Response(
    JSON.stringify({ 
      error: 'Rate limit exceeded',
      retry_after: rateLimitCheck.retryAfter 
    }),
    { 
      status: 429,
      headers: {
        'Content-Type': 'application/json',
        'Retry-After': String(rateLimitCheck.retryAfter)
      }
    }
  )
}
```

---

## 📝 API Versioning

### Current Version: v1

All endpoints are under `/functions/v1/`:

- `/functions/v1/device-check`
- `/functions/v1/get-user-credits`
- `/functions/v1/get-models`
- `/functions/v1/get-user-profile`
- `/functions/v1/get-video-jobs`

### Future Versioning Strategy

When breaking changes are needed:

1. Create new Edge Function with version prefix: `v2-device-check`
2. Keep old version active for backward compatibility
3. Deprecate old version after migration period
4. Update iOS app to use new version

---

## 🎯 Error Response Format

All endpoints return consistent error responses:

```json
{
  "error": "Error message here"
}
```

**Status Codes:**
- `200` - Success
- `400` - Bad Request (missing/invalid parameters)
- `401` - Unauthorized (invalid/expired token)
- `403` - Forbidden (insufficient permissions)
- `404` - Not Found
- `429` - Rate Limit Exceeded
- `500` - Internal Server Error

**Enhanced Error Format (Phase 7):**

See [backend-6-operations-testing.md](./backend-6-operations-testing.md) for internationalized error codes.

```json
{
  "error": {
    "code": "ERR_4001",
    "message": "You need 4 credits, but only have 2. Please purchase more credits.",
    "details": {
      "required": 4,
      "available": 2
    }
  }
}
```

---

## 🔧 Shared Utilities

### Logger Utility

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

**Usage:**
```typescript
import { logEvent } from '../_shared/logger.ts'

logEvent('user_onboarded', {
  user_id: newUser.id,
  device_id: device_id,
  credits_granted: 10
})

logEvent('api_error', {
  endpoint: 'device-check',
  error: error.message
}, 'error')
```

---

## 📊 API Performance Considerations

### Caching

1. **Models List:** Consider ETag caching (see Phase 5)
2. **User Profile:** Cache on client side, refresh on update
3. **Credit Balance:** Cache with short TTL (5-10 seconds)

### Pagination

Always use pagination for list endpoints:
- Default limit: 20
- Maximum limit: 100
- Include `has_more` flag in response

### Database Queries

1. Use indexes (see [backend-1-overview-database.md](./backend-1-overview-database.md))
2. Select only needed columns
3. Use `count: 'exact'` for pagination totals

---

## 🚀 Next Steps

After implementing core APIs:

1. **Video Generation** - See [backend-3-generation-workflow.md](./backend-3-generation-workflow.md)
2. **Credit Management** - See [backend-5-credit-system.md](./backend-5-credit-system.md)
3. **Authentication** - See [backend-4-auth-security.md](./backend-4-auth-security.md)

---

**Related Documentation:**
- [backend-INDEX.md](./backend-INDEX.md) - Complete documentation index
- [backend-1-overview-database.md](./backend-1-overview-database.md) - Database schema
- [backend-3-generation-workflow.md](./backend-3-generation-workflow.md) - Video generation APIs
- [backend-4-auth-security.md](./backend-4-auth-security.md) - Authentication details

