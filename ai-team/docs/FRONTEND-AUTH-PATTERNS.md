# Frontend Authentication Patterns

**Complete authentication patterns for Supabase + Next.js**

Copy-paste ready patterns for solo developers.

---

## 🎯 Overview

This guide covers all authentication patterns you'll need:
- Email/Password authentication
- Session management
- Route protection
- Social login (Google, Apple)
- Guest/anonymous mode
- Account merging

**Time to implement:** Already done if you copied `templates/nextjs/`

---

## 🔐 Authentication Methods

### Method 1: Email/Password (Template Included)

**Use for:** Standard web apps

```tsx
// lib/supabase-client.ts (already in template)
export const auth = {
  signUp: async (email: string, password: string) => {
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
    })
    if (error) throw error
    return data
  },

  signIn: async (email: string, password: string) => {
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password,
    })
    if (error) throw error
    return data
  },

  signOut: async () => {
    await supabase.auth.signOut()
  }
}
```

**Signup flow:**
1. User enters email + password
2. Supabase creates account
3. Sends verification email (automatic)
4. User clicks link → Email verified
5. User can sign in

**No custom backend code needed!**

---

### Method 2: Social Login (Google, Apple)

**Use for:** Faster onboarding, mobile apps

```tsx
// Add to lib/supabase-client.ts
export const auth = {
  // ... existing methods

  signInWithGoogle: async () => {
    const { data, error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo: `${window.location.origin}/auth/callback`
      }
    })
    if (error) throw error
    return data
  },

  signInWithApple: async () => {
    const { data, error } = await supabase.auth.signInWithOAuth({
      provider: 'apple',
      options: {
        redirectTo: `${window.location.origin}/auth/callback`
      }
    })
    if (error) throw error
    return data
  }
}
```

**Setup (Supabase Dashboard):**
1. Go to Authentication → Providers
2. Enable Google/Apple
3. Add OAuth credentials
4. Save

**Callback handler:**

```tsx
// app/auth/callback/route.ts
import { createClient } from '@/lib/supabase-server'
import { NextResponse } from 'next/server'

export async function GET(request: Request) {
  const requestUrl = new URL(request.url)
  const code = requestUrl.searchParams.get('code')

  if (code) {
    const supabase = createClient()
    await supabase.auth.exchangeCodeForSession(code)
  }

  return NextResponse.redirect(`${requestUrl.origin}/dashboard`)
}
```

**Usage:**

```tsx
<button onClick={() => auth.signInWithGoogle()}>
  Sign in with Google
</button>
```

---

### Method 3: Magic Link (Passwordless)

**Use for:** No password to remember

```tsx
export const auth = {
  sendMagicLink: async (email: string) => {
    const { error } = await supabase.auth.signInWithOtp({
      email,
      options: {
        emailRedirectTo: `${window.location.origin}/auth/callback`
      }
    })
    if (error) throw error
  }
}
```

**Flow:**
1. User enters email
2. Supabase sends email with link
3. User clicks link
4. Automatically signed in

---

### Method 4: Anonymous/Guest Mode

**Use for:** Try before signup, demo mode

```tsx
export const auth = {
  signInAnonymously: async () => {
    const { data, error } = await supabase.auth.signInAnonymously()
    if (error) throw error
    return data
  },

  convertGuestToUser: async (email: string, password: string) => {
    // First, update the anonymous user with email
    const { error: updateError } = await supabase.auth.updateUser({
      email,
      password
    })
    if (updateError) throw updateError

    // Supabase automatically sends verification email
  }
}
```

**Use case:**
1. User opens app → Signed in as guest automatically
2. User tries premium feature → Prompted to create account
3. Convert guest → full user (keeps all data)

---

## 🛡 Session Management

### Pattern 1: Cookie-Based Sessions (Template Default)

**Why:** Secure, works with Server Components

```typescript
// middleware.ts (already in template)
// Automatically refreshes expired sessions
const { data: { user } } = await supabase.auth.getUser()
```

**Session lifecycle:**
1. User signs in → JWT stored in httpOnly cookie
2. Every request → Middleware refreshes if needed
3. Expires after 1 hour → Auto-refresh if <5 min left
4. User inactive 7 days → Must sign in again

**No manual refresh needed!**

### Pattern 2: Client-Side Session (React Context)

**Why:** Reactive auth state in components

```tsx
// components/AuthProvider.tsx (already in template)
export function AuthProvider({ children }) {
  const [user, setUser] = useState(null)

  useEffect(() => {
    // Get initial session
    supabase.auth.getSession().then(({ data: { session } }) => {
      setUser(session?.user ?? null)
    })

    // Listen for changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      (_event, session) => {
        setUser(session?.user ?? null)
      }
    )

    return () => subscription.unsubscribe()
  }, [])

  return (
    <AuthContext.Provider value={{ user }}>
      {children}
    </AuthContext.Provider>
  )
}
```

**Usage:**

```tsx
function MyComponent() {
  const { user } = useAuth()
  return user ? `Hello ${user.email}` : 'Not logged in'
}
```

---

## 🚧 Route Protection

### Layer 1: Middleware (Template Included)

**Protects:** Entire route sections

```typescript
// middleware.ts
const protectedPaths = ['/dashboard', '/profile', '/settings']

if (isProtectedPath && !user) {
  return NextResponse.redirect('/login')
}
```

**Runs on:** Every request (edge runtime, fast)

### Layer 2: Server Components

**Protects:** Individual pages

```tsx
// app/dashboard/page.tsx
import { getUser } from '@/lib/supabase-server'
import { redirect } from 'next/navigation'

export default async function DashboardPage() {
  const user = await getUser()

  if (!user) {
    redirect('/login')
  }

  return <Dashboard user={user} />
}
```

**Runs on:** Initial page load (server-side)

### Layer 3: Client Components

**Protects:** Component-level features

```tsx
'use client'
import { useAuth } from '@/components/AuthProvider'

export function PremiumFeature() {
  const { user } = useAuth()

  if (!user) {
    return <div>Please sign in to access this feature</div>
  }

  return <PremiumContent />
}
```

**Runs on:** Client-side (reactive)

### Complete Protection Example

```tsx
// middleware.ts - First line of defense
if (pathname.startsWith('/dashboard') && !user) redirect('/login')

// page.tsx - Server-side check
export default async function Page() {
  const user = await getUser()
  if (!user) redirect('/login')

  return <Dashboard />
}

// Dashboard.tsx - Client-side guard
function Dashboard() {
  const { user } = useAuth()
  if (!user) return <Loading />

  return <Content />
}
```

**Why three layers?**
- Middleware: Fast edge redirect
- Server: Prevents page render
- Client: Handles race conditions

---

## 🔑 Password Reset Flow

### Pattern: Supabase Built-in (Recommended)

**Setup (5 minutes):**

1. **Customize email template** (Supabase Dashboard):
   - Go to Authentication → Email Templates
   - Customize "Reset Password" template

2. **Add reset handler** (already in template):

```tsx
// lib/supabase-client.ts
export const auth = {
  resetPassword: async (email: string) => {
    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/auth/reset-password`
    })
    if (error) throw error
  }
}
```

3. **Create reset page:**

```tsx
// app/auth/reset-password/page.tsx
'use client'

export default function ResetPasswordPage() {
  const [password, setPassword] = useState('')

  const handleReset = async (e: FormEvent) => {
    e.preventDefault()

    const { error } = await supabase.auth.updateUser({
      password: password
    })

    if (error) {
      alert('Error: ' + error.message)
    } else {
      alert('Password updated!')
      router.push('/dashboard')
    }
  }

  return (
    <form onSubmit={handleReset}>
      <input
        type="password"
        placeholder="New password"
        value={password}
        onChange={(e) => setPassword(e.target.value)}
      />
      <button type="submit">Reset Password</button>
    </form>
  )
}
```

**Flow:**
1. User clicks "Forgot password" → Enters email
2. Supabase sends email with link
3. User clicks link → Redirected to `/auth/reset-password`
4. User enters new password → Updated
5. Redirected to dashboard

**No custom backend needed!**

---

## 👤 User Profile Management

### Pattern 1: Basic Profile

```tsx
// Get current user
const { data: { user } } = await supabase.auth.getUser()

// Update email
await supabase.auth.updateUser({ email: 'new@example.com' })

// Update password
await supabase.auth.updateUser({ password: 'newpassword123' })

// Update metadata (custom fields)
await supabase.auth.updateUser({
  data: { display_name: 'John Doe', avatar_url: 'https://...' }
})
```

### Pattern 2: Extended Profile (Separate Table)

**Schema:**

```sql
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  display_name TEXT,
  avatar_url TEXT,
  bio TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-create profile on signup
CREATE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id)
  VALUES (NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();
```

**Usage:**

```tsx
// Fetch profile
const { data } = await supabase
  .from('profiles')
  .select('*')
  .eq('id', user.id)
  .single()

// Update profile
await supabase
  .from('profiles')
  .update({ display_name: 'New Name' })
  .eq('id', user.id)
```

---

## 🔄 Account Linking

### Pattern: Merge Guest → Authenticated

**Use case:** User started as guest, now wants full account

```tsx
async function convertGuestAccount(email: string, password: string) {
  const { data: { user } } = await supabase.auth.getUser()

  if (!user?.is_anonymous) {
    throw new Error('Not a guest account')
  }

  // Update guest user with email + password
  const { error } = await supabase.auth.updateUser({
    email,
    password
  })

  if (error) throw error

  // All guest data (credits, history) automatically retained!
  // User ID stays the same
}
```

**Benefits:**
- User doesn't lose progress
- Same user_id in database
- No data migration needed

---

## 🎨 UI Component Patterns

### Pattern 1: Login Form (Template Included)

```tsx
// app/(auth)/login/page.tsx - see template
<form onSubmit={handleLogin}>
  <input type="email" value={email} onChange={...} />
  <input type="password" value={password} onChange={...} />
  <button type="submit">Sign In</button>
  <button onClick={handleForgotPassword}>Forgot Password?</button>
</form>
```

### Pattern 2: Auth Modal

```tsx
function AuthModal({ isOpen, onClose }) {
  const [mode, setMode] = useState<'signin' | 'signup'>('signin')

  return (
    <Modal isOpen={isOpen} onClose={onClose}>
      {mode === 'signin' ? (
        <LoginForm onSuccess={onClose} />
      ) : (
        <SignupForm onSuccess={onClose} />
      )}

      <button onClick={() => setMode(mode === 'signin' ? 'signup' : 'signin')}>
        {mode === 'signin' ? 'Create account' : 'Already have account?'}
      </button>
    </Modal>
  )
}
```

### Pattern 3: Protected Button

```tsx
function ProtectedAction() {
  const { user } = useAuth()
  const [showAuthModal, setShowAuthModal] = useState(false)

  const handleClick = () => {
    if (!user) {
      setShowAuthModal(true)
      return
    }

    performAction()
  }

  return (
    <>
      <button onClick={handleClick}>
        {user ? 'Generate Video' : 'Sign in to Generate'}
      </button>

      <AuthModal isOpen={showAuthModal} onClose={() => setShowAuthModal(false)} />
    </>
  )
}
```

---

## 🧪 Testing Authentication

### Test 1: Signup Flow

```bash
1. Go to /signup
2. Enter email + password
3. Check inbox for verification email
4. Click verification link
5. Should redirect to dashboard
```

### Test 2: Login Flow

```bash
1. Go to /login
2. Enter valid credentials → Should login
3. Enter invalid credentials → Should show error
4. Should redirect to ?redirect param if set
```

### Test 3: Protected Routes

```bash
1. Sign out
2. Try to visit /dashboard → Should redirect to /login
3. Sign in
4. Should redirect back to /dashboard
```

### Test 4: Session Persistence

```bash
1. Sign in
2. Close browser
3. Open browser
4. Visit /dashboard → Should still be logged in (no redirect)
```

### Test 5: Password Reset

```bash
1. Click "Forgot password"
2. Enter email
3. Check inbox for reset link
4. Click link → Redirected to reset page
5. Enter new password
6. Should be logged in with new password
```

---

## 🔒 Security Best Practices

### 1. Use RLS Policies

```sql
-- Users can only see their own data
CREATE POLICY "Users see own data"
ON users FOR SELECT
USING (auth.uid() = id);

-- Users can only update their own data
CREATE POLICY "Users update own data"
ON users FOR UPDATE
USING (auth.uid() = id);
```

### 2. Validate on Server

```typescript
// Edge Function
const user = await requireAuth(req)

if (!user) {
  return new Response('Unauthorized', { status: 401 })
}

// Use user.id for queries, NEVER trust client-provided user_id
```

### 3. Rate Limit Auth Endpoints

```typescript
// Supabase Dashboard → Authentication → Rate Limits
// Default: 30 requests per hour per IP (signup/login)
```

### 4. Enable Email Verification

```typescript
// Supabase Dashboard → Authentication → Email Auth
// ✅ Enable email confirmations
```

### 5. Strong Password Requirements

```typescript
// Client-side validation
if (password.length < 8) {
  return 'Password must be at least 8 characters'
}

// Supabase enforces minimum 6 characters by default
// Customize in Dashboard → Authentication → Auth Providers → Email
```

---

## 🚀 Quick Reference

### Common Auth Operations

```tsx
// Sign up
await auth.signUp(email, password)

// Sign in
await auth.signIn(email, password)

// Sign out
await auth.signOut()

// Get current user
const user = await auth.getUser()

// Check if logged in
const session = await auth.getSession()
const isLoggedIn = !!session

// Reset password
await auth.resetPassword(email)

// Update password
await supabase.auth.updateUser({ password: newPassword })

// Update email
await supabase.auth.updateUser({ email: newEmail })

// Social login
await auth.signInWithGoogle()
await auth.signInWithApple()
```

### Common Hooks (Client Components)

```tsx
// Get current user
const { user, loading } = useAuth()

// Require auth (redirect if not logged in)
useRequireAuth() // Custom hook

// Get session
const session = useSession() // Custom hook
```

### Server-Side Helpers

```tsx
// Get user (returns null if not logged in)
const user = await getUser()

// Require auth (throws error if not logged in)
const user = await requireAuth()

// Get user with credits
const userData = await getUserWithCredits()
```

---

## 📚 Additional Resources

- **Templates:** `templates/nextjs/` - Copy-paste ready auth
- **Integration:** `docs/FRONTEND-SUPABASE-INTEGRATION.md` - Full integration guide
- **Supabase Auth:** https://supabase.com/docs/guides/auth
- **RLS Policies:** https://supabase.com/docs/guides/auth/row-level-security

---

## 🤝 Philosophy

**Auth should be boring.**

- ✅ Use Supabase built-in auth (no custom backend)
- ✅ Copy templates (don't write from scratch)
- ✅ Test once, reuse forever

**NOT:**
- ❌ Build custom auth system
- ❌ Manage JWTs manually
- ❌ Handle password hashing
- ❌ Send verification emails yourself

**Supabase handles all of this. Just use the templates.**

---

**Time to implement: 30 minutes (with templates)**
**Time without: 10-20 hours**
**Security: Battle-tested by Supabase**

Happy Authenticating! 🔐✨
