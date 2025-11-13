# Backend Authentication Decision Framework

**Purpose:** Document authentication patterns and decision points for AI agents to replicate across projects

**Generated:** 2025-01-15

---

## 🎯 Authentication Methods Status

### Currently Implemented ✅
- **Apple Sign-In** - Full implementation with DeviceCheck fraud prevention
- **Anonymous/Guest Auth** - Supabase anonymous authentication

### Not Yet Implemented ⚠️
- **Google Sign-In** - Roadmap item (needed for Android support)
- **Email/Password** - Roadmap item (needed for web users or users without Apple/Google)

### Decision Framework: Which Auth Methods to Support?

```
Platform Support Decision Tree:

1. iOS-only app?
   → START: Apple Sign-In (required by App Store guidelines)
   → OPTIONAL: Guest/Anonymous mode (reduce friction)

2. iOS + Android?
   → ADD: Google Sign-In (most Android users)
   → KEEP: Apple Sign-In for iOS
   → OPTIONAL: Guest mode

3. iOS + Android + Web?
   → ADD: Email/Password (web users need this)
   → KEEP: Apple + Google Sign-In
   → OPTIONAL: Guest mode

4. Enterprise/B2B?
   → ADD: SSO/SAML
   → KEEP: Standard auth methods as fallback
```

**Implementation Priority:**
1. Apple Sign-In (iOS requirement)
2. Guest/Anonymous mode (reduce friction, increase conversions)
3. Google Sign-In (if Android support needed)
4. Email/Password (if web support needed)

---

## 💰 Critical Decision: Anonymous User Purchases

### The Core Question

**Should anonymous/guest users be allowed to purchase credits/subscriptions?**

This is a **critical architecture decision** that affects:
- User experience (friction vs security)
- Revenue (conversion rate vs fraud risk)
- Technical complexity (account merging logic)
- Support burden (lost purchase recovery)

---

### Option A: Require Login Before Purchase 🔒

**Pattern:** Force users to sign in with Apple/Google/Email before allowing any IAP

**Flow:**
```
User opens app
  ↓
Browse as guest ✅
  ↓
Generate videos with free credits ✅
  ↓
Try to purchase credits
  ↓
❌ BLOCKED: "Sign in to purchase"
  ↓
User signs in with Apple/Google/Email
  ↓
Now can purchase ✅
```

**Pros:**
- ✅ **No account merging complexity** - Purchases always tied to authenticated account
- ✅ **Easier support** - Can recover purchases via email/Apple ID
- ✅ **Lower fraud risk** - Authenticated users are accountable
- ✅ **Simple implementation** - No merge logic needed
- ✅ **Better for subscriptions** - Auto-renewal requires authenticated account

**Cons:**
- ❌ **Higher friction** - Users must sign in before buying (conversion loss)
- ❌ **Lower impulse purchases** - Extra step reduces spontaneous buys
- ❌ **Worse UX for iOS** - Users expect "try then buy" pattern
- ❌ **Privacy concerns** - Users forced to share identity before knowing if they like the app

**Best For:**
- Subscription-based apps (requires authenticated account anyway)
- Enterprise/B2B apps (authentication expected)
- Apps with high average revenue per user (worth the friction)
- Apps where fraud is a major concern

**Code Pattern:**
```typescript
// In IAP endpoint
if (user.is_guest) {
  return new Response(
    JSON.stringify({
      error: 'Please sign in to purchase',
      error_code: 'AUTH_REQUIRED',
      sign_in_required: true
    }),
    { status: 403 }
  )
}
```

---

### Option B: Allow Anonymous Purchases (with Safeguards) 🛡️

**Pattern:** Allow guest users to purchase, then merge account when they sign in

**Flow:**
```
User opens app
  ↓
Browse as guest ✅
  ↓
Generate videos with free credits ✅
  ↓
Purchase credits (as guest) ✅
  ↓
Use purchased credits ✅
  ↓
[Later] User signs in with Apple/Google
  ↓
MERGE: Guest purchases + authenticated account ✅
```

**Pros:**
- ✅ **Lower friction** - Buy immediately without sign-in
- ✅ **Higher conversion** - Impulse purchases more likely
- ✅ **Better for mobile** - Matches iOS "try then buy" pattern
- ✅ **Privacy-friendly** - Users can remain anonymous
- ✅ **Flexible** - Sign in is optional, not forced

**Cons:**
- ❌ **Complex account merging** - Must handle guest → authenticated migration
- ❌ **Higher fraud risk** - Anonymous purchases harder to track
- ❌ **Support complexity** - Harder to recover lost purchases
- ❌ **DeviceCheck dependency** - Must use DeviceCheck to prevent abuse
- ❌ **Edge cases** - Multiple devices, reinstalls, etc.

**Best For:**
- Consumer mobile apps (iOS/Android)
- Free-to-play with IAP (casual gaming pattern)
- Apps with low fraud risk (digital goods, not physical)
- Apps optimizing for conversion rate

**Required Safeguards:**
- ✅ DeviceCheck to prevent multiple "free trial" exploits
- ✅ Idempotency to prevent duplicate purchases
- ✅ Account merge logic (documented below)
- ✅ Purchase recovery mechanism
- ✅ Rate limiting on anonymous purchases

**Code Pattern:**
```typescript
// In IAP endpoint
// Allow purchase for both guest and authenticated users
const verification = await verifyAppleTransaction(transaction_id)

if (!verification.valid) {
  return new Response(
    JSON.stringify({ error: 'Invalid transaction' }),
    { status: 400 }
  )
}

// Grant credits regardless of is_guest status
await supabaseClient.rpc('add_credits', {
  p_user_id: user_id, // Works for both guest and authenticated
  p_amount: credits,
  p_transaction_id: transaction_id
})
```

---

### Option C: Hybrid Approach (Recommended) ⚖️

**Pattern:** Allow small purchases as guest, require login for larger amounts or subscriptions

**Flow:**
```
User opens app as guest
  ↓
Small purchase (< $10) → Allow ✅
  ↓
Large purchase (≥ $10) → Require sign-in ❌
  ↓
Subscription → Require sign-in ❌
```

**Rules:**
- Guest users can buy: One-time credits up to $9.99
- Guest users CANNOT buy: Subscriptions, bundles over $10
- After purchase, encourage (but don't force) sign-in

**Pros:**
- ✅ Low friction for small purchases (high conversion)
- ✅ Security for high-value transactions
- ✅ Subscriptions properly managed (requires auth)
- ✅ Balances UX and risk

**Cons:**
- ❌ More complex logic (different rules for different tiers)
- ❌ Users might not understand why some items need login

**Code Pattern:**
```typescript
// In IAP endpoint
const { data: product } = await supabaseClient
  .from('products')
  .select('price_usd, is_subscription')
  .eq('product_id', product_id)
  .single()

if (user.is_guest) {
  if (product.is_subscription) {
    return errorResponse('Subscriptions require sign-in', 403)
  }

  if (product.price_usd >= 10.00) {
    return errorResponse('Large purchases require sign-in', 403)
  }
}

// Allow purchase
```

---

## 🔄 Account Merge Pattern (Guest → Authenticated)

### The Problem

**Scenario:**
1. User installs app, uses as guest
2. Guest purchases 100 credits for $4.99
3. Guest generates 20 videos
4. User signs in with Apple/Google/Email
5. **What happens to guest account?**

### The Pattern: Automatic Account Merge

**Goal:** Transfer all guest data to authenticated account seamlessly

**What to Merge:**
- ✅ Credits remaining
- ✅ Credits total (lifetime)
- ✅ Video generation history
- ✅ Purchase history (quota_log)
- ✅ Settings/preferences

**What NOT to Merge:**
- ❌ Device ID (authenticated user may use multiple devices)
- ❌ Initial grant flag (already claimed on guest account)

---

### Merge Flow Diagram

```
┌─────────────────────────────────────────────────────────┐
│ BEFORE MERGE                                            │
├─────────────────────────────────────────────────────────┤
│ Guest Account:                                          │
│   - ID: guest-uuid-123                                  │
│   - device_id: device-abc                               │
│   - is_guest: true                                      │
│   - credits_remaining: 95                               │
│   - video_jobs: 5 videos                                │
│                                                         │
│ Authenticated Account (just created):                   │
│   - ID: auth-uuid-456                                   │
│   - apple_sub: "apple-id-789"                           │
│   - is_guest: false                                     │
│   - credits_remaining: 10 (initial grant)               │
│   - video_jobs: 0 videos                                │
└─────────────────────────────────────────────────────────┘

                        ↓ MERGE ↓

┌─────────────────────────────────────────────────────────┐
│ AFTER MERGE                                             │
├─────────────────────────────────────────────────────────┤
│ Authenticated Account (merged):                         │
│   - ID: auth-uuid-456                                   │
│   - apple_sub: "apple-id-789"                           │
│   - is_guest: false                                     │
│   - credits_remaining: 105 (95 + 10)                    │
│   - video_jobs: 5 videos (transferred)                  │
│                                                         │
│ Guest Account (soft deleted):                           │
│   - ID: guest-uuid-123                                  │
│   - deleted_at: 2025-01-15 10:30:00                     │
│   - (All data moved to authenticated account)           │
└─────────────────────────────────────────────────────────┘
```

---

### Merge Logic (Stored Procedure Pattern)

```sql
-- Pattern for AI agents to implement

CREATE OR REPLACE FUNCTION merge_guest_account(
    p_guest_id UUID,
    p_authenticated_id UUID
) RETURNS JSONB AS $$
DECLARE
    guest_credits INTEGER;
    auth_credits INTEGER;
    total_credits INTEGER;
BEGIN
    -- 1. LOCK BOTH ACCOUNTS (prevent concurrent operations)
    SELECT credits_remaining INTO guest_credits
    FROM users WHERE id = p_guest_id FOR UPDATE;

    SELECT credits_remaining INTO auth_credits
    FROM users WHERE id = p_authenticated_id FOR UPDATE;

    -- 2. VALIDATE
    IF guest_credits IS NULL OR auth_credits IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Account not found'
        );
    END IF;

    total_credits := guest_credits + auth_credits;

    -- 3. TRANSFER VIDEO JOBS
    UPDATE video_jobs
    SET user_id = p_authenticated_id
    WHERE user_id = p_guest_id;

    -- 4. TRANSFER QUOTA LOG (purchase history)
    UPDATE quota_log
    SET user_id = p_authenticated_id
    WHERE user_id = p_guest_id;

    -- 5. UPDATE AUTHENTICATED ACCOUNT
    UPDATE users
    SET
        credits_remaining = total_credits,
        credits_total = credits_total + guest_credits,
        updated_at = now()
    WHERE id = p_authenticated_id;

    -- 6. SOFT DELETE GUEST ACCOUNT
    UPDATE users
    SET deleted_at = now()
    WHERE id = p_guest_id;

    -- 7. LOG MERGE EVENT
    INSERT INTO quota_log (
        user_id,
        change,
        reason,
        balance_after,
        metadata
    ) VALUES (
        p_authenticated_id,
        guest_credits,
        'account_migration',
        total_credits,
        jsonb_build_object(
            'from_guest_id', p_guest_id,
            'merged_at', now()
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'total_credits', total_credits,
        'migrated_credits', guest_credits,
        'migrated_videos', (SELECT COUNT(*) FROM video_jobs WHERE user_id = p_authenticated_id)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

### When to Trigger Merge

**Automatic vs Manual Merge Decision:**

#### Option 1: Automatic Merge (Recommended)
**When:** User signs in with Apple/Google while already using app as guest

**Flow:**
```
iOS detects: Guest session active + Apple Sign-In completed
  ↓
iOS sends both IDs to backend: { guest_id, apple_user_id }
  ↓
Backend: Check if apple_user_id exists in users table
  ↓
If NEW: Call merge_guest_account(guest_id, new_auth_id)
  ↓
If EXISTS: Handle conflict (user signed in before on different device)
```

**Pros:**
- Seamless UX (user doesn't notice)
- No data loss
- Works automatically

**Cons:**
- Complex error handling
- What if authenticated account already has data?

---

#### Option 2: Manual Merge with Prompt
**When:** User signs in, backend detects guest account exists

**Flow:**
```
User signs in with Apple
  ↓
Backend detects: Guest account with credits exists
  ↓
Return to iOS: { merge_available: true, guest_credits: 95 }
  ↓
iOS shows popup: "You have 95 credits as a guest. Transfer to this account?"
  ↓
User confirms → Backend merges
```

**Pros:**
- User is aware of what's happening
- Can choose to keep accounts separate
- Clear UX

**Cons:**
- Extra step (friction)
- Users might be confused

---

### Edge Cases to Handle

#### Case 1: User Already Signed In on Another Device

**Problem:**
```
Device A: User signed in with Apple (has 50 credits)
Device B: User uses as guest (has 100 credits)
Device B: User signs in with same Apple ID
```

**Solution Options:**

**A) Merge Everything (Recommended)**
```
Result: 150 credits total (50 + 100)
```

**B) Ask User**
```
"You have 50 credits on this account and 100 as a guest. Merge?"
```

**C) Keep Highest**
```
Result: 100 credits (keep whichever is higher)
```

---

#### Case 2: Multiple Guest Accounts (Reinstalls)

**Problem:**
```
User uninstalls app
  ↓
Reinstalls on same device
  ↓
DeviceCheck still marks device as "used"
  ↓
User gets new anonymous account (no initial grant)
  ↓
User signs in with Apple
  ↓
Which guest account to merge?
```

**Solution:**
```sql
-- Only merge the MOST RECENT guest account on this device
SELECT id FROM users
WHERE device_id = current_device_id
  AND is_guest = true
  AND deleted_at IS NULL
ORDER BY created_at DESC
LIMIT 1;
```

---

#### Case 3: Guest Account with Subscription

**Problem:**
```
If you allow anonymous subscriptions (NOT recommended):
  ↓
Guest has active subscription
  ↓
User signs in
  ↓
How to transfer subscription?
```

**Solution:**
```
DON'T allow anonymous subscriptions
Subscriptions MUST require authenticated account
```

**Why:**
- Apple requires user account for auto-renewal
- Can't transfer subscription between Apple IDs
- Support nightmare if user loses access

---

## 📋 Decision Matrix for Your Project

### Questions to Answer:

| Question | Your Answer | Implication |
|----------|-------------|-------------|
| Do you plan Android support? | ? | If YES → Need Google Sign-In |
| Do you plan web support? | ? | If YES → Need Email/Password |
| Will you offer subscriptions? | ? | If YES → Require auth before subscribe |
| Is your app iOS-only? | ? | If YES → Apple Sign-In + Guest mode is enough |
| Do you want maximum conversion? | ? | If YES → Allow anonymous purchases |
| Is fraud a major concern? | ? | If YES → Require auth before purchase |
| What's your average purchase? | ? | If < $10 → Allow guest, If > $10 → Require auth |

---

## 🎯 Recommended Pattern (Based on Your Backend)

Based on your existing architecture, here's the recommended approach:

### Phase 1: Current State ✅
- Apple Sign-In (implemented)
- Guest mode (implemented)
- DeviceCheck fraud prevention (implemented)

### Phase 2: Add Account Merging (Immediate Need)
```
Priority: HIGH
Reason: You allow guest users, so merge is critical
Pattern: Automatic merge (stored procedure exists, need Edge Function endpoint)
```

### Phase 3: Allow Anonymous Purchases (Optional)
```
Decision: Your choice based on decision matrix above
If YES: Use hybrid approach (small purchases OK, subscriptions require auth)
If NO: Require sign-in before any purchase
```

### Phase 4: Add Google Sign-In (When Android Support Needed)
```
Priority: LOW (unless Android is planned)
Pattern: Same as Apple Sign-In, just different provider
```

### Phase 5: Add Email/Password (When Web Support Needed)
```
Priority: LOW (unless web version is planned)
Pattern: Standard Supabase email auth
```

---

## 🚀 Implementation Checklist for AI Agents

When implementing auth in a new project, agents should:

### Step 1: Determine Auth Strategy
- [ ] Platform support (iOS/Android/Web)
- [ ] Guest mode needed? (reduces friction)
- [ ] Anonymous purchases allowed?
- [ ] Subscription support?

### Step 2: Implement Core Auth
- [ ] Apple Sign-In (iOS requirement)
- [ ] Guest/Anonymous mode (if needed)
- [ ] DeviceCheck setup (fraud prevention)
- [ ] JWT token management

### Step 3: Implement Account Merge
- [ ] `merge_guest_account` stored procedure
- [ ] Edge Function endpoint `/merge-guest-account`
- [ ] iOS integration (detect sign-in while guest)
- [ ] Handle edge cases (multiple devices, reinstalls)

### Step 4: Implement Purchase Logic
- [ ] Decision: Auth required or allow guest?
- [ ] If guest allowed: Add safeguards (DeviceCheck, rate limiting)
- [ ] If auth required: Block IAP for `is_guest = true`

### Step 5: Add Additional Providers (If Needed)
- [ ] Google Sign-In (for Android)
- [ ] Email/Password (for web)
- [ ] Account linking (multiple providers per user)

---

## 📝 Template Files Needed for AI Agents

Based on this decision framework, create these templates:

1. **AUTH-PROVIDER-DECISION.md** - Which auth methods to use
2. **GUEST-ACCOUNT-MERGE.md** - How to merge accounts
3. **ANONYMOUS-PURCHASE-PATTERN.md** - Allow guest purchases or not
4. **GOOGLE-SIGNIN-SETUP.md** - Google auth implementation
5. **EMAIL-PASSWORD-SETUP.md** - Email/password auth implementation

---

**This document provides the decision framework. The AI agents will use this to make architecture choices for future projects.**
