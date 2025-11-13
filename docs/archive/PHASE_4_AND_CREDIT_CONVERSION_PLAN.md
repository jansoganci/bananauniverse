# PHASE 4 + CREDIT SYSTEM CONVERSION - MASTER PLAN

**Date**: 2025-11-13
**Status**: READY TO EXECUTE
**Estimated Time**: 5.5 hours

---

## OVERVIEW

This plan covers TWO major changes:

1. **PHASE 4**: Remove old polling code (webhook cleanup)
2. **CREDIT CONVERSION**: Replace daily quota system with persistent credit balance system

---

## PART A: PHASE 4 - REMOVE OLD POLLING CODE

### Goal
Delete all old synchronous/polling code, keep ONLY webhook architecture.

### Files to Modify

#### 1. `BananaUniverse/Features/Chat/ViewModels/ChatViewModel.swift`

**DELETE**:
- Lines 212-357: Entire `processImage()` method (old polling code)
- Lines 202-210: Feature flag check

**CHANGE**:
- Line 200: Remove `if Config.useAsyncWebhooks` check, directly call `processImageWebhook(image)`

**RENAME**:
- Method `processImageWebhook()` → `processImage()` (becomes the only processing method)

#### 2. `BananaUniverse/Core/Config/Config.swift`

**DELETE**:
- Line ~36: `static let useAsyncWebhooks: Bool = true` (feature flag no longer needed)

#### 3. `BananaUniverse/Core/Services/SupabaseService.swift`

**DELETE**:
- `processImageSteveJobsStyle()` method (old synchronous processing method)

---

## PART B: CREDIT SYSTEM CONVERSION

### Goal
Replace daily-reset quota system with persistent pay-per-use credit balance system.

---

## B1. DATABASE MIGRATIONS (3 NEW FILES)

### Migration 062: Activate Credit System

**File**: `supabase/migrations/062_activate_credit_system.sql`

**Actions**:
1. Set default credits to 10 for new users
2. Add indexes on `user_id` and `device_id` for performance
3. Create trigger to auto-initialize credits on user signup
4. Add RLS policies for `user_credits` and `anonymous_credits` tables
5. Initialize existing users with 10 credits (one-time migration)

**Key Changes**:
```sql
-- Set default credits
ALTER TABLE user_credits ALTER COLUMN credits SET DEFAULT 10;
ALTER TABLE anonymous_credits ALTER COLUMN credits SET DEFAULT 10;

-- Auto-initialize credits on signup
CREATE OR REPLACE FUNCTION initialize_user_credits()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO user_credits (user_id, credits)
    VALUES (NEW.id, 10)
    ON CONFLICT (user_id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION initialize_user_credits();
```

---

### Migration 063: Remove Daily Quota System

**File**: `supabase/migrations/063_remove_daily_quota_system.sql`

**Actions**:
1. DROP `daily_quotas` table
2. DROP `consume_quota()` function
3. DROP old `add_credits()` function (quota refund version)
4. DROP `get_quota()` function
5. DROP any quota-related RLS policies
6. DROP any quota-related indexes

**Key Changes**:
```sql
-- Drop old quota functions
DROP FUNCTION IF EXISTS consume_quota(UUID, TEXT, TEXT);
DROP FUNCTION IF EXISTS add_credits(UUID, TEXT, INTEGER, TEXT);
DROP FUNCTION IF EXISTS get_quota(UUID, TEXT);

-- Drop daily_quotas table
DROP TABLE IF EXISTS daily_quotas CASCADE;
```

---

### Migration 064: Create Credit Functions

**File**: `supabase/migrations/064_create_credit_functions.sql`

**Actions**:
1. CREATE `consume_credits()` function (deducts from persistent balance)
2. CREATE `add_credits()` function (adds to persistent balance - refunds)
3. CREATE `get_credits()` function (reads balance)
4. Add idempotency support (reuse `idempotency_keys` table)
5. Add proper error handling

**Key Functions**:

#### `consume_credits(p_user_id, p_device_id, p_amount, p_idempotency_key)`
- Checks idempotency (prevents double-charge)
- Premium users: bypass (return unlimited)
- Free users: check balance, deduct atomically (FOR UPDATE lock)
- Returns: `{success, credits_remaining, is_premium}`
- Throws: "Insufficient credits" if balance < amount

#### `add_credits(p_user_id, p_device_id, p_amount, p_idempotency_key)`
- Checks idempotency (prevents double-refund)
- Adds to persistent balance (never resets)
- Returns: `{success, credits_remaining}`

#### `get_credits(p_user_id, p_device_id)`
- Read-only, no locks
- Returns current credit balance
- Returns: `{success, credits_remaining, is_premium}`

---

## B2. EDGE FUNCTIONS (3 FILES TO MODIFY)

### 1. `supabase/functions/submit-job/index.ts`

**Location**: Line ~181

**BEFORE**:
```typescript
const { data, error } = await supabase.rpc('consume_quota', {
  p_user_id: userType === 'authenticated' ? userIdentifier : null,
  p_device_id: userType === 'anonymous' ? userIdentifier : null,
  p_idempotency_key: requestId
});

if (!data?.success) {
  return new Response(
    JSON.stringify({ error: data?.error || 'Daily quota exceeded' }),
    { status: 429 }
  );
}
```

**AFTER**:
```typescript
const { data, error } = await supabase.rpc('consume_credits', {
  p_user_id: userType === 'authenticated' ? userIdentifier : null,
  p_device_id: userType === 'anonymous' ? userIdentifier : null,
  p_amount: 1,
  p_idempotency_key: requestId
});

if (!data?.success) {
  return new Response(
    JSON.stringify({ error: data?.error || 'Insufficient credits' }),
    { status: 402 }  // Changed from 429 to 402 Payment Required
  );
}
```

**Changes**:
- Replace `consume_quota` → `consume_credits`
- Add `p_amount: 1` parameter
- Change error message: "Daily quota exceeded" → "Insufficient credits"
- Change HTTP status: 429 → 402 (Payment Required)
- Update response to include `credits_remaining`

---

### 2. `supabase/functions/webhook-handler/index.ts`

**Location**: Line ~320 (refund logic on failure)

**BEFORE**:
```typescript
// Refund quota on failure
const { error: refundError } = await supabase.rpc('add_credits', {
  p_user_id: userType === 'authenticated' ? userIdentifier : null,
  p_device_id: userType === 'anonymous' ? userIdentifier : null,
  p_credits: 1,
  p_idempotency_key: `refund_${requestId}`
});
```

**AFTER**:
```typescript
// Refund credits on failure
const { error: refundError } = await supabase.rpc('add_credits', {
  p_user_id: userType === 'authenticated' ? userIdentifier : null,
  p_device_id: userType === 'anonymous' ? userIdentifier : null,
  p_amount: 1,
  p_idempotency_key: `refund_${requestId}`
});
```

**Changes**:
- Parameter rename: `p_credits` → `p_amount`
- Comment update: "Refund quota" → "Refund credits"

---

### 3. `supabase/functions/get-result/index.ts`

**Location**: Response JSON

**BEFORE**:
```typescript
return new Response(
  JSON.stringify({
    status: jobResult.status,
    image_url: jobResult.image_url,
    quota_used: jobResult.quota_used,
    quota_limit: jobResult.quota_limit,
    quota_remaining: jobResult.quota_remaining
  })
);
```

**AFTER**:
```typescript
return new Response(
  JSON.stringify({
    status: jobResult.status,
    image_url: jobResult.image_url,
    credits_remaining: jobResult.credits_remaining,
    is_premium: jobResult.is_premium
  })
);
```

**Changes**:
- Remove: `quota_used`, `quota_limit`, `quota_remaining`
- Add: `credits_remaining`, `is_premium`

---

## B3. IOS CLIENT (RENAME + MODIFY)

### 1. `QuotaInfo.swift` → `CreditInfo.swift`

**File Operations**:
1. RENAME FILE: `BananaUniverse/Core/Models/QuotaInfo.swift` → `CreditInfo.swift`
2. RENAME STRUCT: `QuotaInfo` → `CreditInfo`

**BEFORE**:
```swift
struct QuotaInfo: Codable {
    let credits: Int
    let quotaUsed: Int
    let quotaLimit: Int
    let quotaRemaining: Int
    let isPremium: Bool
    let idempotent: Bool?

    enum CodingKeys: String, CodingKey {
        case credits
        case quotaUsed = "quota_used"
        case quotaLimit = "quota_limit"
        case quotaRemaining = "quota_remaining"
        case isPremium = "is_premium"
        case idempotent
    }
}
```

**AFTER**:
```swift
struct CreditInfo: Codable {
    let creditsRemaining: Int
    let isPremium: Bool
    let idempotent: Bool?

    enum CodingKeys: String, CodingKey {
        case creditsRemaining = "credits_remaining"
        case isPremium = "is_premium"
        case idempotent
    }
}
```

**Changes**:
- REMOVE: `credits`, `quotaUsed`, `quotaLimit`, `quotaRemaining`
- ADD: `creditsRemaining`

---

### 2. `HybridCreditManager.swift` → `CreditManager.swift`

**File Operations**:
1. RENAME FILE: `BananaUniverse/Core/Services/HybridCreditManager.swift` → `CreditManager.swift`
2. RENAME CLASS: `HybridCreditManager` → `CreditManager`

**BEFORE**:
```swift
class HybridCreditManager: ObservableObject {
    static let shared = HybridCreditManager()

    @Published private(set) var dailyQuotaUsed: Int = 0
    @Published private(set) var dailyQuotaLimit: Int = 3
    @Published private(set) var isPremiumUser: Bool = false

    var remainingQuota: Int {
        isPremiumUser ? Int.max : max(0, dailyQuotaLimit - dailyQuotaUsed)
    }

    func canProcessImage() -> Bool {
        isPremiumUser || remainingQuota > 0
    }
}
```

**AFTER**:
```swift
class CreditManager: ObservableObject {
    static let shared = CreditManager()

    @Published private(set) var creditsRemaining: Int = 0
    @Published private(set) var isPremiumUser: Bool = false
    @Published private(set) var isLoading = false

    func canProcessImage() -> Bool {
        isPremiumUser || creditsRemaining > 0
    }

    var creditDisplayText: String {
        isPremiumUser ? "Unlimited" : "\(creditsRemaining)"
    }
}
```

**Changes**:
- REMOVE: `dailyQuotaUsed`, `dailyQuotaLimit`, `remainingQuota`
- ADD: `creditsRemaining`
- UPDATE: All computed properties to use `creditsRemaining`
- UPDATE: All methods to use credits instead of quota

---

### 3. `QuotaService.swift` (Keep File Name, Update Methods)

**File**: `BananaUniverse/Core/Services/QuotaService.swift`

**Changes**:
- UPDATE: Return type `QuotaInfo` → `CreditInfo`
- UPDATE: RPC calls to use `consume_credits`, `add_credits`, `get_credits`
- UPDATE: Response parsing to match new backend format

**BEFORE**:
```swift
func consumeQuota(userId: String?, deviceId: String?) async throws -> QuotaInfo {
    let response = try await supabase.rpc('consume_quota', ...)
    return QuotaInfo(...)
}
```

**AFTER**:
```swift
func consumeCredits(userId: String?, deviceId: String?) async throws -> CreditInfo {
    let response = try await supabase.rpc('consume_credits', ...)
    return CreditInfo(creditsRemaining: response.credits_remaining, isPremium: response.is_premium)
}
```

---

### 4. `QuotaCache.swift` (Update Cache Structure)

**File**: `BananaUniverse/Core/Services/QuotaCache.swift`

**BEFORE**:
```swift
struct CachedQuota {
    let used: Int
    let limit: Int
    let premium: Bool
}
```

**AFTER**:
```swift
struct CachedCredits {
    let creditsRemaining: Int
    let premium: Bool
}
```

**Changes**:
- UPDATE: Cache structure to store `creditsRemaining` instead of `used/limit`
- UPDATE: All save/load methods

---

### 5. `ChatViewModel.swift` (Update References)

**File**: `BananaUniverse/Features/Chat/ViewModels/ChatViewModel.swift`

**Changes**:
- UPDATE: `HybridCreditManager.shared` → `CreditManager.shared`
- UPDATE: All references to quota → credits

---

### 6. ALL VIEW FILES (UI Text Updates)

**Files to Search**:
- `BananaUniverse/Features/**/*.swift`

**Find and Replace**:
- `HybridCreditManager` → `CreditManager`
- `QuotaInfo` → `CreditInfo`
- `"Daily Credits: \(used) / \(limit)"` → `"Credits: \(remaining)"`
- `remainingQuota` → `creditsRemaining`

---

## EXECUTION ORDER

### Step 1: Phase 4 (30 min)
1. Delete old polling code in `ChatViewModel.swift`
2. Remove feature flag in `Config.swift`
3. Delete `processImageSteveJobsStyle()` in `SupabaseService.swift`
4. Rename `processImageWebhook()` → `processImage()`

### Step 2: Database (1 hour)
1. Create migration 062 (activate credit system)
2. Create migration 063 (remove daily quota system)
3. Create migration 064 (create credit functions)
4. Run migrations on Supabase

### Step 3: Edge Functions (1 hour)
1. Update `submit-job/index.ts`
2. Update `webhook-handler/index.ts`
3. Update `get-result/index.ts`
4. Deploy all 3 functions

### Step 4: iOS Client (2 hours)
1. Rename `QuotaInfo.swift` → `CreditInfo.swift`
2. Rename `HybridCreditManager.swift` → `CreditManager.swift`
3. Update `QuotaService.swift`
4. Update `QuotaCache.swift`
5. Update `ChatViewModel.swift`
6. Search/replace all view files

### Step 5: Testing (1 hour)
1. Test credit consumption (authenticated user)
2. Test credit consumption (anonymous user)
3. Test credit refund on failure
4. Test premium user bypass
5. Test idempotency
6. Test iOS UI updates

---

## FILE CHECKLIST

### ✅ Phase 4 Files (Delete Old Code)
- [ ] `BananaUniverse/Features/Chat/ViewModels/ChatViewModel.swift`
- [ ] `BananaUniverse/Core/Config/Config.swift`
- [ ] `BananaUniverse/Core/Services/SupabaseService.swift`

### ✅ Database Migrations (Create New)
- [ ] `supabase/migrations/062_activate_credit_system.sql`
- [ ] `supabase/migrations/063_remove_daily_quota_system.sql`
- [ ] `supabase/migrations/064_create_credit_functions.sql`

### ✅ Edge Functions (Modify)
- [ ] `supabase/functions/submit-job/index.ts`
- [ ] `supabase/functions/webhook-handler/index.ts`
- [ ] `supabase/functions/get-result/index.ts`

### ✅ iOS Core (Rename + Modify)
- [ ] `BananaUniverse/Core/Models/QuotaInfo.swift` → `CreditInfo.swift`
- [ ] `BananaUniverse/Core/Services/HybridCreditManager.swift` → `CreditManager.swift`
- [ ] `BananaUniverse/Core/Services/QuotaService.swift`
- [ ] `BananaUniverse/Core/Services/QuotaCache.swift`

### ✅ iOS Views (Search + Replace)
- [ ] All view files referencing `HybridCreditManager` or `QuotaInfo`

---

## TESTING CHECKLIST

### Database Tests
- [ ] Run migration 062 successfully
- [ ] Run migration 063 successfully
- [ ] Run migration 064 successfully
- [ ] Verify `user_credits` table has default 10 credits
- [ ] Verify `daily_quotas` table is deleted

### Backend Tests
- [ ] Call `consume_credits()` - should deduct 1 credit
- [ ] Call `consume_credits()` with same idempotency key - should return cached result
- [ ] Call `consume_credits()` with 0 credits - should fail with "Insufficient credits"
- [ ] Call `add_credits()` - should add 1 credit
- [ ] Premium user calls `consume_credits()` - should bypass

### iOS Tests
- [ ] Launch app - should show "Credits: 10"
- [ ] Process image - credits should decrease to 9
- [ ] Fail job - credits should refund to 10
- [ ] Premium user - should show "Unlimited"

---

## ROLLBACK PROCEDURE

If something goes wrong:

### Rollback Step 1: Database
```sql
-- Restore daily_quotas table
-- Restore consume_quota() function
-- Restore old add_credits() function
-- Drop new credit functions
```

### Rollback Step 2: Backend
```bash
# Redeploy old Edge Functions from git
git checkout HEAD~1 supabase/functions/
supabase functions deploy submit-job
supabase functions deploy webhook-handler
supabase functions deploy get-result
```

### Rollback Step 3: iOS
```bash
# Revert iOS changes
git checkout HEAD~1 BananaUniverse/
# Rebuild app
xcodebuild ...
```

---

## SUCCESS CRITERIA

Phase 4 + Credit Conversion is successful if:

- ✅ Old polling code completely removed
- ✅ Feature flag removed
- ✅ `daily_quotas` table deleted
- ✅ `user_credits` and `anonymous_credits` tables active
- ✅ All Edge Functions use `consume_credits()` and `add_credits()`
- ✅ iOS app shows "Credits: X" instead of "Daily Credits: X / Y"
- ✅ Credits persist across days (no daily reset)
- ✅ Credit refunds work correctly
- ✅ Premium users bypass credit checks
- ✅ All tests pass

---

**READY TO EXECUTE**: YES

**START DATE**: TBD

**COMPLETION DATE**: TBD

---

## NOTES

- This is a DESTRUCTIVE migration - test thoroughly before running in production
- Backup database before running migrations
- Consider running Phase 4 first, test for 24 hours, then do credit conversion
- Communicate to users about credit system change (daily → persistent)
- Consider giving existing users bonus credits for the migration (e.g., 50 credits)
