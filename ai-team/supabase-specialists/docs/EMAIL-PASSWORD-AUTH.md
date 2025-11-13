# Email/Password Authentication with Supabase

**Purpose:** Simple, secure email/password authentication using Supabase Auth (built-in, no custom code needed).

**Generated:** 2025-01-15

**Target:** Solo developers, vibe coders, sustainable systems

---

## 🎯 Why Use Supabase Auth?

**Already built-in to Supabase:**
- ✅ bcrypt password hashing (automatic)
- ✅ Email verification (automatic)
- ✅ Password reset (automatic)
- ✅ Rate limiting (built-in)
- ✅ Session management (automatic)
- ✅ Free tier: Unlimited users
- ✅ No custom backend code needed

**You just configure and use it.** That's it!

---

## 📋 Setup Checklist

### Step 1: Enable Email/Password Auth (1 minute)

- [ ] Open Supabase dashboard
- [ ] Go to **Authentication → Providers**
- [ ] Find **Email** provider
- [ ] Toggle **Enable Email Provider** to ON
- [ ] Click **Save**

Done! Email/Password auth is now enabled.

### Step 2: Configure Password Requirements (2 minutes)

- [ ] Go to **Authentication → Policies**
- [ ] Click **Password Requirements**
- [ ] Set minimum password length: **8 characters** (recommended)
- [ ] Enable **Require at least one number** (optional but recommended)
- [ ] Enable **Require at least one special character** (optional, can skip for simplicity)
- [ ] Click **Save**

**Recommended Simple Settings:**
```
Minimum length: 8 characters
Require number: Yes
Require special character: No (optional)
Require uppercase: No (optional)
```

**This allows passwords like:**
- ✅ `mypass123` (simple, memorable)
- ✅ `hello2024` (simple, memorable)
- ❌ `short1` (too short)
- ❌ `nodigits` (no number)

### Step 3: Enable Email Verification (1 minute)

- [ ] Go to **Authentication → Settings**
- [ ] Find **Email Confirmation** section
- [ ] Toggle **Enable email confirmations** to ON
- [ ] Click **Save**

**What this does:**
- User signs up → Receives verification email
- User clicks link → Email verified
- User can now log in

**To skip email verification (for development only):**
- [ ] Toggle **Enable email confirmations** to OFF
- [ ] Users can log in immediately after signup (not recommended for production)

### Step 4: Configure Redirect URLs (2 minutes)

**For Mobile Apps (iOS/Android):**
- [ ] Go to **Authentication → URL Configuration**
- [ ] Add your app's deep link:
  ```
  yourapp://auth/callback
  ```
- [ ] Click **Save**

**For Web Apps:**
- [ ] Add your web URL:
  ```
  https://yourdomain.com/auth/callback
  ```
- [ ] For local development, also add:
  ```
  http://localhost:3000/auth/callback
  ```
- [ ] Click **Save**

**What this does:**
- After email verification, user is redirected to your app
- After password reset, user is redirected to set new password

### Step 5: Customize Email Templates (5 minutes)

Already covered in `EMAIL-SERVICE-INTEGRATION.md`, but quick recap:

- [ ] Go to **Authentication → Email Templates**
- [ ] Customize **Confirm Signup** template
- [ ] Customize **Reset Password** template
- [ ] Keep them simple and clean

**Done!** Your auth is configured.

---

## 💻 Implementation: 3 Simple API Calls

### API Call 1: Sign Up

**Client-side code (iOS Swift):**
```swift
import Supabase

let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://your-project.supabase.co")!,
    supabaseKey: "your-anon-key"
)

// Sign up new user
Task {
    do {
        try await supabase.auth.signUp(
            email: "user@example.com",
            password: "mypass123"
        )
        // Success! User receives verification email
        print("Check your email to verify")
    } catch {
        // Handle error (email already exists, weak password, etc.)
        print("Error: \(error)")
    }
}
```

**Client-side code (JavaScript/Web):**
```typescript
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  'https://your-project.supabase.co',
  'your-anon-key'
)

// Sign up new user
const { data, error } = await supabase.auth.signUp({
  email: 'user@example.com',
  password: 'mypass123'
})

if (error) {
  console.error('Error:', error.message)
} else {
  console.log('Check your email to verify')
}
```

**What happens:**
1. User submits email + password
2. Supabase hashes password with bcrypt
3. Creates user account (unverified)
4. Sends verification email via Resend
5. User clicks link → Email verified → Can log in

**No backend code needed!**

---

### API Call 2: Log In

**Client-side code (iOS Swift):**
```swift
// Log in existing user
Task {
    do {
        try await supabase.auth.signIn(
            email: "user@example.com",
            password: "mypass123"
        )
        // Success! User is logged in
        let session = supabase.auth.session
        print("Access token: \(session?.accessToken)")
    } catch {
        // Handle error (wrong password, email not verified, etc.)
        print("Error: \(error)")
    }
}
```

**Client-side code (JavaScript/Web):**
```typescript
// Log in existing user
const { data, error } = await supabase.auth.signInWithPassword({
  email: 'user@example.com',
  password: 'mypass123'
})

if (error) {
  console.error('Error:', error.message)
} else {
  console.log('Logged in! Access token:', data.session.access_token)
}
```

**What happens:**
1. User submits email + password
2. Supabase verifies password (bcrypt comparison)
3. Checks if email is verified (if enabled)
4. Returns JWT access token + refresh token
5. Store tokens securely (Keychain on iOS, localStorage on web)

**No backend code needed!**

---

### API Call 3: Reset Password

**Client-side code (iOS Swift):**
```swift
// Send password reset email
Task {
    do {
        try await supabase.auth.resetPasswordForEmail(
            "user@example.com"
        )
        // Success! User receives reset email
        print("Check your email for reset link")
    } catch {
        print("Error: \(error)")
    }
}

// After user clicks link and is redirected to your app:
// Show a form to enter new password

// Update password
Task {
    do {
        try await supabase.auth.updateUser(
            attributes: UserAttributes(password: "newpass123")
        )
        print("Password updated!")
    } catch {
        print("Error: \(error)")
    }
}
```

**Client-side code (JavaScript/Web):**
```typescript
// Send password reset email
const { error } = await supabase.auth.resetPasswordForEmail(
  'user@example.com',
  {
    redirectTo: 'https://yourdomain.com/reset-password'
  }
)

if (error) {
  console.error('Error:', error.message)
} else {
  console.log('Check your email for reset link')
}

// After user clicks link and is redirected:
// Show a form to enter new password

// Update password
const { error } = await supabase.auth.updateUser({
  password: 'newpass123'
})

if (error) {
  console.error('Error:', error.message)
} else {
  console.log('Password updated!')
}
```

**What happens:**
1. User enters email
2. Supabase sends reset email via Resend
3. User clicks link → Redirected to your app
4. User enters new password
5. Supabase updates password (bcrypt hashing)

**No backend code needed!**

---

## 🔐 Security Features (Built-in)

Supabase Auth handles security automatically:

**Password Security:**
- ✅ bcrypt hashing (slow, secure, industry standard)
- ✅ Password strength validation (configurable)
- ✅ Passwords never stored in plain text
- ✅ Passwords never sent in responses

**Session Security:**
- ✅ JWT tokens with expiration
- ✅ Refresh tokens for long sessions
- ✅ Automatic token refresh
- ✅ Secure token storage recommendations

**Rate Limiting (Built-in):**
- ✅ Max 4 failed login attempts per hour
- ✅ Email confirmation rate limiting
- ✅ Password reset rate limiting

**Email Verification:**
- ✅ Prevents fake signups
- ✅ Ensures valid email addresses
- ✅ One-time use tokens
- ✅ Tokens expire after 24 hours

**You get all this for free!**

---

## 🚨 Common Implementation Patterns

### Pattern 1: Get Current User

**iOS Swift:**
```swift
// Get currently logged in user
if let user = supabase.auth.currentUser {
    print("User ID: \(user.id)")
    print("Email: \(user.email)")
} else {
    print("No user logged in")
}
```

**JavaScript:**
```typescript
// Get currently logged in user
const { data: { user } } = await supabase.auth.getUser()

if (user) {
  console.log('User ID:', user.id)
  console.log('Email:', user.email)
} else {
  console.log('No user logged in')
}
```

---

### Pattern 2: Log Out

**iOS Swift:**
```swift
// Log out current user
Task {
    try await supabase.auth.signOut()
    print("Logged out")
}
```

**JavaScript:**
```typescript
// Log out current user
await supabase.auth.signOut()
console.log('Logged out')
```

---

### Pattern 3: Check if Email is Verified

**iOS Swift:**
```swift
if let user = supabase.auth.currentUser {
    if user.emailConfirmedAt != nil {
        print("Email verified")
    } else {
        print("Email not verified - check your inbox")
    }
}
```

**JavaScript:**
```typescript
const { data: { user } } = await supabase.auth.getUser()

if (user?.email_confirmed_at) {
  console.log('Email verified')
} else {
  console.log('Email not verified - check your inbox')
}
```

---

### Pattern 4: Resend Verification Email

**iOS Swift:**
```swift
// Resend verification email
Task {
    try await supabase.auth.resend(
        type: .signup,
        email: "user@example.com"
    )
    print("Verification email sent")
}
```

**JavaScript:**
```typescript
// Resend verification email
await supabase.auth.resend({
  type: 'signup',
  email: 'user@example.com'
})
console.log('Verification email sent')
```

---

### Pattern 5: Listen for Auth State Changes

**iOS Swift:**
```swift
// Listen for auth state changes (login, logout, etc.)
for await state in supabase.auth.authStateChanges {
    switch state {
    case .signedIn(let session):
        print("User signed in: \(session.user.email)")
    case .signedOut:
        print("User signed out")
    default:
        break
    }
}
```

**JavaScript:**
```typescript
// Listen for auth state changes
supabase.auth.onAuthStateChange((event, session) => {
  if (event === 'SIGNED_IN') {
    console.log('User signed in:', session?.user.email)
  } else if (event === 'SIGNED_OUT') {
    console.log('User signed out')
  }
})
```

---

## 🧪 Testing Checklist

### Manual Testing

**Sign Up Flow:**
- [ ] Sign up with valid email/password
- [ ] Receive verification email
- [ ] Click verification link
- [ ] Redirected correctly
- [ ] Can now log in

**Login Flow:**
- [ ] Log in with verified account (success)
- [ ] Log in with unverified account (should fail)
- [ ] Log in with wrong password (should fail)
- [ ] Log in with non-existent email (should fail)

**Password Reset Flow:**
- [ ] Request password reset
- [ ] Receive reset email
- [ ] Click reset link
- [ ] Redirected correctly
- [ ] Enter new password
- [ ] Password updated successfully
- [ ] Can log in with new password

**Rate Limiting:**
- [ ] Try 5 wrong passwords → Should get rate limited
- [ ] Wait 1 hour → Can try again

**Session Management:**
- [ ] Log in → Token stored
- [ ] Close app → Reopen → Still logged in
- [ ] Log out → Token cleared
- [ ] Reopen → Not logged in

---

## 🔧 Optional: Add to Existing Guest Users

If you have guest users (from DeviceCheck) who want to upgrade to email/password:

**Pattern: Link Email to Existing User**

```swift
// User is logged in as guest
// Now they want to add email/password

Task {
    try await supabase.auth.updateUser(
        attributes: UserAttributes(
            email: "user@example.com",
            password: "mypass123"
        )
    )
    print("Email/password added to guest account")
    // User receives verification email
}
```

**What happens:**
1. Guest user (device-based) is logged in
2. User enters email + password
3. Email/password linked to existing account
4. User receives verification email
5. User can now log in with email/password on any device

**This is covered in AUTH-DECISION-FRAMEWORK.md** under account merging patterns.

---

## 💰 Free Tier Limits

**Supabase Auth Free Tier:**
- Unlimited users
- Unlimited logins
- All features included
- No credit card required

**When to Upgrade:**
- Never for auth alone
- Only if you need more database storage, bandwidth, etc.

**Monitor Usage:**
- Check Supabase dashboard for MAU (Monthly Active Users)
- Free tier is generous for MVPs

---

## 🚨 Common Issues & Fixes

### Issue 1: "Email not confirmed"

**Fix:**
- [ ] Check if email verification is enabled
- [ ] Check spam folder for verification email
- [ ] Resend verification email
- [ ] For development, disable email verification temporarily

### Issue 2: "Invalid password" (but password is correct)

**Fix:**
- [ ] Check password requirements (8+ chars, 1 number)
- [ ] Password is case-sensitive
- [ ] Check for extra spaces

### Issue 3: Verification link not working

**Fix:**
- [ ] Check redirect URL in Supabase settings
- [ ] Ensure redirect URL is in allowed list
- [ ] Check URL scheme (http vs https)
- [ ] Link expires after 24 hours - request new one

### Issue 4: Rate limited after failed logins

**Fix:**
- [ ] Wait 1 hour
- [ ] Check if password is correct
- [ ] User may need to reset password

---

## ✅ Final Setup Summary

**Total Setup Time: ~10 minutes**

1. Enable Email/Password provider (1 min)
2. Configure password requirements (2 min)
3. Enable email verification (1 min)
4. Configure redirect URLs (2 min)
5. Customize email templates (5 min)

**What You Get:**
- ✅ Secure authentication (bcrypt, JWT)
- ✅ Email verification (automatic)
- ✅ Password reset (automatic)
- ✅ Rate limiting (built-in)
- ✅ Session management (automatic)
- ✅ Unlimited users (free tier)
- ✅ No backend code needed

**3 API Calls in Your App:**
- `signUp()` - Create account
- `signIn()` - Log in
- `resetPasswordForEmail()` - Reset password

**You're done!** Supabase handles everything else automatically and securely.

---

## 📚 Additional Resources

**Supabase Docs:**
- Auth quickstart: https://supabase.com/docs/guides/auth
- Email auth: https://supabase.com/docs/guides/auth/auth-email
- Password reset: https://supabase.com/docs/guides/auth/auth-password-reset

**Client Libraries:**
- iOS: `supabase-swift` (official)
- JavaScript: `@supabase/supabase-js` (official)
- React: `@supabase/auth-ui-react` (pre-built UI components)

---

**This template provides a simple, secure email/password authentication system for solo developers using Supabase Auth (built-in, no custom backend needed).**
