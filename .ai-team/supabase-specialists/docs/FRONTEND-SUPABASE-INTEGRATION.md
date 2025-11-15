# Frontend-Supabase Integration Guide

**Complete guide for connecting Next.js/React frontends to Supabase backends**

For solo developers building sustainable systems.

---

## 🎯 Overview

This guide covers how to integrate your frontend (Next.js, React, Vue) with your Supabase backend. It assumes you've already deployed:
- Supabase migrations (credit system, IAP, async jobs)
- Edge Functions (update-credits, verify-iap, generate-video)

**Time to integrate:** 30 minutes with templates, 5+ hours without.

---

## 📐 Architecture Pattern

### The Veteran Pattern

```
Frontend (Next.js)           Supabase Backend
├── Auth Context            ├── Auth (JWT)
├── API Client              ├── PostgreSQL
├── Real-time Updates       ├── Edge Functions
└── Credit Display          └── Realtime Subscriptions
```

**Key Principle:** Frontend is a thin client. All business logic stays in backend.

### Three-Layer Integration

1. **Authentication Layer**
   - JWT-based auth (httpOnly cookies)
   - Session management
   - Route protection

2. **API Layer**
   - Edge Function calls
   - Error handling
   - Idempotency

3. **Real-time Layer**
   - Credit balance updates
   - Job status changes
   - Live notifications

---

## 🚀 Quick Start (Using Templates)

### Step 1: Copy Next.js Template

```bash
cp -r templates/nextjs/* your-app/
cd your-app
npm install @supabase/ssr @supabase/supabase-js
```

### Step 2: Environment Variables

Create `.env.local`:

```env
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### Step 3: Test

```bash
npm run dev
# Visit http://localhost:3000/login
```

**Done!** Authentication, credits, and API calls work out of the box.

---

## 🔐 Authentication Integration

### Pattern 1: Client Components (Interactive)

Use for: Login forms, user menus, interactive UI

```tsx
'use client'
import { useAuth } from '@/components/AuthProvider'

export function UserMenu() {
  const { user, loading } = useAuth()

  if (loading) return <div>Loading...</div>
  if (!user) return <a href="/login">Sign In</a>

  return (
    <div>
      <span>{user.email}</span>
      <button onClick={handleSignOut}>Sign Out</button>
    </div>
  )
}
```

### Pattern 2: Server Components (Fast)

Use for: Initial page load, SEO, secure data fetching

```tsx
import { getUser } from '@/lib/supabase-server'
import { redirect } from 'next/navigation'

export default async function DashboardPage() {
  const user = await getUser()

  if (!user) {
    redirect('/login')
  }

  return <div>Welcome {user.email}</div>
}
```

### Pattern 3: Route Protection (Middleware)

Use for: Protecting entire sections

```typescript
// middleware.ts
const protectedPaths = ['/dashboard', '/profile', '/settings']

if (isProtectedPath && !user) {
  return NextResponse.redirect('/login')
}
```

**Result:** Three layers of protection (middleware → server → client)

---

## 📡 API Integration Patterns

### Pattern 1: Simple Edge Function Call

```tsx
'use client'
import { api } from '@/lib/supabase-client'

async function handleAction() {
  try {
    const result = await api.invoke('my-function', {
      param1: 'value1'
    })
    console.log(result)
  } catch (error) {
    console.error('API error:', error)
  }
}
```

### Pattern 2: Credit Operations

```tsx
// Deduct credits
await api.updateCredits('deduct', 5, 'Video generation')

// Add credits
await api.updateCredits('add', 100, 'Purchase')

// Get current balance
const credits = await api.getCredits()
```

### Pattern 3: Async Job Creation (Idempotent)

```tsx
'use client'
import { supabase } from '@/lib/supabase-client'

async function generateVideo(prompt: string) {
  // Generate idempotency key (store in state or localStorage)
  const idempotencyKey = `video-${Date.now()}-${Math.random()}`

  try {
    const { data, error } = await supabase.functions.invoke('generate-video', {
      body: { prompt, theme_id: selectedTheme },
      headers: {
        'Idempotency-Key': idempotencyKey
      }
    })

    if (error) throw error

    // Poll for job completion or use Realtime
    const jobId = data.job_id
    pollJobStatus(jobId)
  } catch (error) {
    console.error('Generation failed:', error)
  }
}
```

### Pattern 4: Database Queries (Direct)

```tsx
// Fetch data
const { data, error } = await supabase
  .from('video_jobs')
  .select('*')
  .eq('user_id', user.id)
  .order('created_at', { ascending: false })
  .limit(10)

// Insert data
const { data, error } = await supabase
  .from('feedback')
  .insert({ user_id: user.id, message: 'Great app!' })
```

**When to use:**
- ✅ Edge Functions: Write operations, business logic, external API calls
- ✅ Direct queries: Read operations, simple filtering

---

## 🔴 Real-time Integration

### Pattern 1: Credit Balance Updates

```tsx
'use client'
import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase-client'

export function CreditDisplay() {
  const [credits, setCredits] = useState<number | null>(null)

  useEffect(() => {
    // Fetch initial
    fetchCredits().then(setCredits)

    // Subscribe to changes
    const channel = supabase
      .channel('credits-updates')
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'users',
          filter: `id=eq.${userId}`
        },
        (payload) => {
          setCredits(payload.new.credits_remaining)
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [userId])

  return <div>{credits} credits</div>
}
```

### Pattern 2: Job Status Updates

```tsx
function pollJobStatus(jobId: string) {
  const channel = supabase
    .channel(`job-${jobId}`)
    .on(
      'postgres_changes',
      {
        event: 'UPDATE',
        schema: 'public',
        table: 'video_jobs',
        filter: `id=eq.${jobId}`
      },
      (payload) => {
        const status = payload.new.status

        if (status === 'completed') {
          alert('Video ready!')
          channel.unsubscribe()
        } else if (status === 'failed') {
          alert('Generation failed')
          channel.unsubscribe()
        }
      }
    )
    .subscribe()
}
```

**Enable Realtime:**
- Supabase Dashboard → Database → Replication
- Enable for: `users`, `video_jobs`, etc.

---

## 🎨 Component Patterns

### Pattern 1: Credit Badge (Reusable)

```tsx
// components/CreditBadge.tsx
'use client'

export function CreditBadge() {
  const { user } = useAuth()
  const credits = useCredits(user?.id)

  return (
    <div className="badge">
      {credits} credits
    </div>
  )
}

// Use everywhere
<Header>
  <CreditBadge />
</Header>
```

### Pattern 2: Protected Component

```tsx
export function PremiumFeature() {
  const { user } = useAuth()
  const { tier } = useUserData()

  if (tier !== 'premium') {
    return <div>Upgrade to access this feature</div>
  }

  return <PremiumContent />
}
```

### Pattern 3: Async Action Button

```tsx
export function GenerateButton() {
  const [loading, setLoading] = useState(false)

  const handleGenerate = async () => {
    setLoading(true)
    try {
      await api.generateVideo(prompt, themeId)
      alert('Generation started!')
    } catch (error) {
      alert('Failed: ' + error.message)
    } finally {
      setLoading(false)
    }
  }

  return (
    <button onClick={handleGenerate} disabled={loading}>
      {loading ? 'Generating...' : 'Generate Video'}
    </button>
  )
}
```

---

## 🔒 Security Best Practices

### 1. NEVER Trust Client Input

```tsx
// ❌ BAD: Client-side validation only
if (credits >= 5) {
  await deductCredits(5)
}

// ✅ GOOD: Backend validates and deducts atomically
await api.invoke('generate-video', { prompt })
// Edge Function checks credits AND deducts in one transaction
```

### 2. Use RLS Policies

```sql
-- Users can only see their own data
CREATE POLICY "Users can view own data"
ON users FOR SELECT
USING (auth.uid() = id);

-- Users can only update their own profile
CREATE POLICY "Users can update own profile"
ON users FOR UPDATE
USING (auth.uid() = id);
```

### 3. Validate on Server

```typescript
// Edge Function
const { prompt, theme_id } = await req.json()

// Validate
if (!prompt || prompt.length < 3) {
  return new Response('Invalid prompt', { status: 400 })
}

// Check credits
const user = await requireAuth(req)
const credits = await getCredits(user.id)

if (credits < 5) {
  return new Response('Insufficient credits', { status: 402 })
}

// Deduct + create job atomically
// ...
```

### 4. Use Idempotency Keys

```tsx
// Generate unique key per action
const key = `${actionType}-${userId}-${Date.now()}`

await supabase.functions.invoke('my-function', {
  headers: { 'Idempotency-Key': key }
})
```

---

## 🛠 Error Handling Patterns

### Pattern 1: Try-Catch with User Feedback

```tsx
async function handleAction() {
  try {
    const result = await api.invoke('my-function')
    setSuccess('Action completed!')
  } catch (error: any) {
    // Parse Supabase errors
    if (error.status === 401) {
      setError('Please sign in')
      router.push('/login')
    } else if (error.status === 402) {
      setError('Insufficient credits')
    } else {
      setError('Something went wrong')
    }
  }
}
```

### Pattern 2: Global Error Handler

```tsx
// lib/api-client.ts
export async function callAPI(fn: string, body: any) {
  try {
    return await supabase.functions.invoke(fn, { body })
  } catch (error: any) {
    // Log to Sentry
    Sentry.captureException(error)

    // Parse error
    if (error.message?.includes('credits')) {
      throw new Error('INSUFFICIENT_CREDITS')
    }

    throw error
  }
}
```

### Pattern 3: Optimistic Updates with Rollback

```tsx
function useOptimisticCredits() {
  const [credits, setCredits] = useState(100)

  const deductCredits = async (amount: number) => {
    // Optimistic update
    const previous = credits
    setCredits(prev => prev - amount)

    try {
      await api.updateCredits('deduct', amount)
    } catch (error) {
      // Rollback on error
      setCredits(previous)
      throw error
    }
  }

  return { credits, deductCredits }
}
```

---

## 📱 Mobile Integration (React Native / iOS)

### iOS (Swift + Supabase)

```swift
// Use templates/ios/Services/SupabaseAuth.swift

import Supabase

class SupabaseClient {
    static let shared = SupabaseClient()

    let client = SupabaseClient(
        supabaseURL: URL(string: "https://your-project.supabase.co")!,
        supabaseKey: "your-anon-key"
    )

    func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(email: email, password: password)
    }

    func callEdgeFunction(name: String, body: [String: Any]) async throws -> Data {
        try await client.functions.invoke(name, body: body)
    }
}
```

**See:** `templates/ios/Services/` for complete examples

### React Native

```tsx
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  'https://your-project.supabase.co',
  'your-anon-key'
)

// Same API as web
await supabase.auth.signInWithPassword({ email, password })
await supabase.functions.invoke('my-function')
```

---

## 🎯 Complete Integration Checklist

### Phase 1: Setup (30 min)
- [ ] Copy Next.js templates
- [ ] Add environment variables
- [ ] Install dependencies
- [ ] Test login/signup

### Phase 2: Core Features (1-2 hours)
- [ ] Integrate credit display
- [ ] Connect Edge Functions
- [ ] Test credit deduction
- [ ] Add error handling

### Phase 3: Real-time (1 hour)
- [ ] Enable Realtime in Supabase
- [ ] Add credit balance subscription
- [ ] Add job status subscription
- [ ] Test live updates

### Phase 4: Polish (1-2 hours)
- [ ] Add loading states
- [ ] Improve error messages
- [ ] Add optimistic updates
- [ ] Test edge cases

**Total: 4-6 hours** (vs 20+ hours without templates)

---

## 🔍 Testing Integration

### Test 1: Authentication Flow

```bash
1. Visit /signup → Create account → Check email verification
2. Visit /login → Sign in → Should redirect to /dashboard
3. Visit /dashboard (not logged in) → Should redirect to /login
4. Sign out → Should redirect to /
```

### Test 2: Credit Operations

```bash
1. Check credit balance shows on dashboard
2. Call deduct credits API → Balance should decrease immediately
3. Call add credits API → Balance should increase immediately
4. Open two browser tabs → Change credits in one → Should update in both
```

### Test 3: Edge Function Calls

```bash
1. Call generate-video → Should deduct 5 credits
2. Check video_jobs table → Should have new row
3. Wait for job completion → Status should change to 'completed'
4. Credits should NOT be refunded (job succeeded)
```

### Test 4: Error Handling

```bash
1. Try to generate with 0 credits → Should show "Insufficient credits"
2. Try with invalid prompt → Should show validation error
3. Disconnect internet → Should show network error
4. Test with duplicate idempotency key → Should return existing result
```

---

## 🚀 Deployment

### Vercel (Recommended for Next.js)

```bash
# 1. Push to GitHub
git push origin main

# 2. Import to Vercel
vercel

# 3. Add environment variables in Vercel Dashboard
NEXT_PUBLIC_SUPABASE_URL=...
NEXT_PUBLIC_SUPABASE_ANON_KEY=...

# 4. Deploy
vercel --prod
```

### Environment Variables for Production

```env
# Production Supabase
NEXT_PUBLIC_SUPABASE_URL=https://prod-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=prod-anon-key

# Optional: Analytics
NEXT_PUBLIC_ANALYTICS_ID=...
```

---

## 🎓 Common Patterns

### Pattern: Fetch on Mount

```tsx
useEffect(() => {
  async function load() {
    const data = await fetchData()
    setData(data)
  }
  load()
}, [])
```

### Pattern: Debounced Search

```tsx
const debouncedSearch = useMemo(
  () => debounce(async (query: string) => {
    const results = await supabase
      .from('items')
      .select('*')
      .ilike('name', `%${query}%`)
    setResults(results)
  }, 300),
  []
)
```

### Pattern: Infinite Scroll

```tsx
const loadMore = async () => {
  const { data } = await supabase
    .from('items')
    .select('*')
    .range(offset, offset + 20)

  setItems(prev => [...prev, ...data])
  setOffset(prev => prev + 20)
}
```

---

## 📚 Additional Resources

- **Templates:** `templates/nextjs/` - Copy-paste ready
- **Backend Setup:** `templates/supabase/` - Edge Functions and migrations
- **Auth Patterns:** `docs/FRONTEND-AUTH-PATTERNS.md` - Deep dive on auth
- **Supabase Docs:** https://supabase.com/docs

---

## 🤝 Philosophy

**Integration should be boring.**

- ✅ Copy templates
- ✅ Update environment variables
- ✅ Test
- ✅ Deploy

**NOT:**
- ❌ Read 50 tutorials
- ❌ Debug CORS issues
- ❌ Figure out auth patterns
- ❌ Reinvent the wheel

**This guide gives you the wheel. Just clone it.**

---

**Time to integrate: 30 minutes**
**Time without templates: 5-10 hours**
**Time saved: 4.5-9.5 hours per project**

Happy Integrating! 🚀✨
