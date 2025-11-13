# 💳 Comprehensive Credit System Analysis

**Date:** 2025-01-27  
**System:** BananaUniverse Credit Management  
**Status:** ✅ Production Active

---

## 📋 Executive Summary

Your credit system is a **persistent balance-based** system that replaced the daily quota system. It's well-architected with server-authoritative enforcement, idempotency protection, and comprehensive error handling. However, there are some gaps in transaction logging and analytics that should be addressed.

**Overall Assessment:** ⭐⭐⭐⭐ (4/5) - Production-ready with recommended improvements

---

## 1. How Does the Credit System Function?

### 1.1 Core Architecture

**Type:** Persistent Credit Balance System  
**Replacement:** Migrated from daily quota system (Nov 2025)

**Key Characteristics:**
- ✅ **Persistent Balance:** Credits never reset (unlike daily quotas)
- ✅ **Server-Authoritative:** All credit operations enforced server-side
- ✅ **Idempotent:** Prevents double-charging via unique idempotency keys
- ✅ **Hybrid Support:** Works for both authenticated users and anonymous devices
- ✅ **Premium Bypass:** Premium users get unlimited credits (bypass all checks)

### 1.2 Credit Definition

**Initial Grant:**
- **New Users:** 10 credits on signup (automatic via trigger)
- **New Anonymous Users:** 10 credits on first use (auto-created)
- **Existing Users:** Migrated with 10 credits (one-time migration)

**Replenishment:**
- ❌ **No automatic replenishment** (credits are persistent, not time-based)
- ✅ **Manual replenishment** via:
  - In-app purchases (IAP) - **NOT YET IMPLEMENTED**
  - Admin grants (via `add_credits()` function)
  - Refunds (automatic on job failures)

**Credit Cost:**
- **Image Processing:** 1 credit per job
- **Fixed Cost:** All operations cost 1 credit (no variable pricing)

**Premium Users:**
- **Unlimited Credits:** Premium users bypass all credit checks
- **Premium Detection:** Server-side check via `subscriptions` table
- **Status Check:** `status = 'active' AND expires_at > NOW() AND status != 'cancelled'`

---

## 2. What User Actions Consume Credits?

### 2.1 Credit-Consuming Operations

**Primary Action:**
1. **Image Processing Job Submission** (`submit-job` Edge Function)
   - **Cost:** 1 credit per job
   - **When:** Before submitting to fal.ai
   - **Location:** ```251:343:supabase/functions/submit-job/index.ts```
   - **Function:** `consumeCredits()` → calls `consume_credits()` RPC

**Flow:**
```
User submits image → submit-job Edge Function → consume_credits() RPC → 
Check premium → Check balance → Deduct 1 credit → Submit to fal.ai
```

### 2.2 Non-Consuming Operations

**These operations do NOT consume credits:**
- ✅ Fetching job results (`get-result`)
- ✅ Checking credit balance (read-only)
- ✅ Premium subscription purchase (grants unlimited, doesn't consume)
- ✅ Viewing processed images
- ✅ Downloading images

---

## 3. Integration for Recharging/Purchasing Credits

### 3.1 Current Status: ⚠️ **NOT FULLY IMPLEMENTED**

**What Exists:**
- ✅ `credit_transactions` table schema (migration 002)
- ✅ `add_credits()` function supports purchases
- ✅ iOS `StoreKitService` has purchase flow
- ✅ Subscription sync to Supabase

**What's Missing:**
- ❌ **No `update-credits` Edge Function** for IAP verification
- ❌ **No credit package products** in App Store Connect
- ❌ **No IAP-to-credit mapping** (product_id → credit amount)
- ❌ **No transaction logging** in `credit_transactions` table

**Current Purchase Flow (Incomplete):**
```swift
// StoreKitService.swift (lines 63-89)
1. User purchases subscription via StoreKit
2. Transaction verified locally
3. Subscription synced to Supabase subscriptions table
4. Premium status updated
5. ❌ NO CREDIT GRANT for one-time purchases
```

**What Needs to Be Built:**
1. **Edge Function:** `update-credits` for IAP verification
2. **Product Mapping:** Database table or hardcoded mapping (product_id → credits)
3. **Transaction Logging:** Insert into `credit_transactions` on purchase
4. **Refund Handling:** Detect Apple refunds and deduct credits

---

## 4. Data Structure & Flow

### 4.1 Database Schema

#### 4.1.1 `user_credits` Table (Authenticated Users)

**Location:** Migration 002, 062

```sql
CREATE TABLE user_credits (
    id UUID PRIMARY KEY,
    user_id UUID UNIQUE REFERENCES auth.users(id),
    credits INTEGER NOT NULL DEFAULT 10 CHECK (credits >= 0),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Key Features:**
- ✅ One record per user (UNIQUE constraint)
- ✅ Default 10 credits for new users
- ✅ Auto-initialized via trigger on signup
- ✅ Non-negative balance (CHECK constraint)

**Indexes:**
- `idx_user_credits_user_id` - Fast user lookups

#### 4.1.2 `anonymous_credits` Table (Anonymous Users)

**Location:** Migration 002, 062

```sql
CREATE TABLE anonymous_credits (
    id UUID PRIMARY KEY,
    device_id TEXT UNIQUE NOT NULL,
    credits INTEGER NOT NULL DEFAULT 10 CHECK (credits >= 0),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Key Features:**
- ✅ One record per device (UNIQUE constraint)
- ✅ Default 10 credits for new devices
- ✅ Auto-created on first use
- ✅ RLS policies for device-based access

**Indexes:**
- `idx_anonymous_credits_device_id` - Fast device lookups
- `idx_anonymous_credits_created_at` - For cleanup queries

#### 4.1.3 `idempotency_keys` Table (Prevents Double-Charging)

**Location:** Migration 050

```sql
CREATE TABLE idempotency_keys (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id),
    device_id TEXT,
    idempotency_key TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    response_status INTEGER,
    response_body JSONB,
    
    -- Unique constraint prevents duplicate operations
    UNIQUE(COALESCE(user_id::text, ''), COALESCE(device_id, ''), idempotency_key)
);
```

**Purpose:**
- Prevents double-charging on retries
- Caches response for idempotent requests
- Used by both `consume_credits()` and `add_credits()`

**Key Index:**
- `idx_idempotency_unique` - Composite unique index

#### 4.1.4 `credit_transactions` Table (⚠️ **DEFINED BUT NOT USED**)

**Location:** Migration 002

```sql
CREATE TABLE credit_transactions (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id),
    amount INTEGER NOT NULL,  -- Positive = add, Negative = spend
    balance_after INTEGER NOT NULL,
    source VARCHAR(50) NOT NULL,  -- 'purchase', 'migration', 'spend', 'refund'
    transaction_metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**⚠️ CRITICAL ISSUE:** This table is **defined but never populated** by the credit functions!

**Current State:**
- ✅ Table exists with proper schema
- ✅ RLS policies configured
- ✅ Indexes created
- ❌ **NOT USED** by `consume_credits()` or `add_credits()`
- ❌ **NO TRANSACTION HISTORY** is being logged

**Impact:**
- No audit trail for credit operations
- Cannot analyze credit usage patterns
- Cannot track refunds vs purchases
- Analytics queries (migration 014, 015) will return empty results

---

### 4.2 Credit Functions

#### 4.2.1 `consume_credits()` Function

**Location:** ```19:221:supabase/migrations/064_create_credit_functions.sql```

**Signature:**
```sql
consume_credits(
    p_user_id UUID DEFAULT NULL,
    p_device_id TEXT DEFAULT NULL,
    p_amount INTEGER DEFAULT 1,
    p_idempotency_key TEXT DEFAULT NULL
) RETURNS JSONB
```

**Flow:**
1. **Idempotency Check:** Returns cached result if key exists
2. **Premium Check:** Bypasses if user has active subscription
3. **Balance Check:** Validates sufficient credits
4. **Atomic Deduction:** Uses `FOR UPDATE` lock to prevent race conditions
5. **Idempotency Cache:** Stores result for future retries

**Response Format:**
```json
{
  "success": true,
  "credits_remaining": 9,
  "is_premium": false
}
```

**Error Response:**
```json
{
  "success": false,
  "error": "Insufficient credits",
  "credits_remaining": 0,
  "is_premium": false
}
```

#### 4.2.2 `add_credits()` Function

**Location:** ```230:342:supabase/migrations/064_create_credit_functions.sql```

**Signature:**
```sql
add_credits(
    p_user_id UUID DEFAULT NULL,
    p_device_id TEXT DEFAULT NULL,
    p_amount INTEGER DEFAULT 1,
    p_idempotency_key TEXT DEFAULT NULL
) RETURNS JSONB
```

**Flow:**
1. **Idempotency Check:** Returns cached result if key exists
2. **Atomic Addition:** Uses `ON CONFLICT` for upsert
3. **Idempotency Cache:** Stores result for future retries

**Use Cases:**
- ✅ Refunds (on job failures)
- ✅ Purchases (when IAP is implemented)
- ✅ Admin grants (manual adjustments)

**Response Format:**
```json
{
  "success": true,
  "credits_remaining": 11
}
```

#### 4.2.3 `get_credits()` Function

**Location:** ```350:438:supabase/migrations/064_create_credit_functions.sql```

**Signature:**
```sql
get_credits(
    p_user_id UUID DEFAULT NULL,
    p_device_id TEXT DEFAULT NULL
) RETURNS JSONB
```

**Purpose:** Read-only balance check (no idempotency needed)

**Response Format:**
```json
{
  "success": true,
  "credits_remaining": 10,
  "is_premium": false
}
```

---

### 4.3 Validations During Credit Usage

#### 4.3.1 Balance Checks

**Location:** ```126:132:supabase/migrations/064_create_credit_functions.sql``` (authenticated)  
**Location:** ```170:176:supabase/migrations/064_create_credit_functions.sql``` (anonymous)

**Validation:**
```sql
IF v_balance < p_amount THEN
    RETURN jsonb_build_object(
        'success', FALSE,
        'error', 'Insufficient credits',
        'credits_remaining', v_balance
    );
END IF;
```

**Edge Function Handling:**
```typescript
// submit-job/index.ts (lines 311-327)
if (!quotaResult.success) {
  return {
    error: new Response(
      JSON.stringify({
        success: false,
        error: quotaResult.error || 'Insufficient credits...',
        quota_info: {
          credits_remaining: quotaResult.credits_remaining || 0,
          is_premium: updatedIsPremium
        }
      }),
      { status: 402 }  // Payment Required
    )
  };
}
```

#### 4.3.2 Retries & Error Handling

**Idempotency Protection:**
- ✅ Duplicate requests return cached result (no double-charge)
- ✅ Idempotency key format: `requestId` for consumption, `refund-${requestId}` for refunds
- ✅ Cached for 30+ days (no automatic cleanup)

**Error Handling:**
- ✅ Database errors caught and returned as JSONB
- ✅ Refund attempts on failures (4 locations in submit-job)
- ✅ Logging for all operations

**Race Condition Protection:**
- ✅ `FOR UPDATE` lock on credit row (lines 116, 160)
- ✅ Atomic UPDATE with RETURNING clause
- ✅ Prevents concurrent modifications

---

## 5. Core Use Cases

### 5.1 Successful Credit Deduction Flow

**Step-by-Step:**

1. **User Submits Job** (iOS App)
   ```swift
   // SupabaseService.swift (line 256)
   POST /functions/v1/submit-job
   Body: { image_url, prompt, device_id, user_id, client_request_id }
   ```

2. **Edge Function Receives Request**
   ```typescript
   // submit-job/index.ts (line 48)
   const parseResult = await parseAndValidateRequest(req, corsHeaders);
   ```

3. **Credit Consumption**
   ```typescript
   // submit-job/index.ts (line 262)
   const { data, error } = await supabase.rpc('consume_credits', {
     p_user_id: userType === 'authenticated' ? userIdentifier : null,
     p_device_id: userType === 'anonymous' ? userIdentifier : null,
     p_amount: 1,
     p_idempotency_key: requestId
   });
   ```

4. **Database Function Execution**
   ```sql
   -- consume_credits() function (lines 59-70)
   -- Check idempotency → Check premium → Check balance → Deduct credits
   UPDATE user_credits 
   SET credits = credits - 1 
   WHERE user_id = p_user_id
   RETURNING credits;
   ```

5. **Response to Client**
   ```json
   {
     "success": true,
     "job_id": "fal-abc-123",
     "status": "pending",
     "quota_info": {
       "credits_remaining": 9,
       "is_premium": false
     }
   }
   ```

**Logs Generated:**
- `🚀 [SUBMIT-JOB] Request started`
- `🔑 [SUBMIT-JOB] Request ID: <uuid>`
- `🆕 [CREDITS] Consuming credits...`
- `✅ [CREDITS] Credit consumed: 9 remaining`
- `✅ [SUBMIT-JOB] Success: {...}`

---

### 5.2 Insufficient Credits Flow

**Step-by-Step:**

1. **User Submits Job** (has 0 credits)

2. **Credit Check Fails**
   ```sql
   -- consume_credits() (line 126)
   IF v_balance < p_amount THEN
       RETURN jsonb_build_object('success', FALSE, 'error', 'Insufficient credits');
   END IF;
   ```

3. **Edge Function Returns Error**
   ```typescript
   // submit-job/index.ts (line 314-326)
   return {
     error: new Response(
       JSON.stringify({
         success: false,
         error: 'Insufficient credits. Purchase more credits to continue.',
         quota_info: {
           credits_remaining: 0,
           is_premium: false
         }
       }),
       { status: 402 }  // Payment Required
     )
   };
   ```

4. **iOS App Receives 402 Status**
   ```swift
   // SupabaseService.swift (line 285)
   if httpResponse.statusCode == 429 {  // Should be 402
       throw SupabaseError.quotaExceeded
   }
   ```

**⚠️ ISSUE:** iOS code checks for 429, but function returns 402. This mismatch should be fixed.

**User Experience:**
- Error message displayed: "Insufficient credits"
- User prompted to purchase credits (if IAP implemented)
- Balance shown: 0 credits remaining

---

### 5.3 Credit Refund Flow (Job Failure)

**Step-by-Step:**

1. **Job Fails** (fal.ai returns FAILED status)

2. **Webhook Handler Processes Failure**
   ```typescript
   // webhook-handler/index.ts (line 76-78)
   if (status === 'FAILED' || error) {
     const failedResult = await handleFailedJob(...);
   }
   ```

3. **Credit Refund Executed**
   ```typescript
   // webhook-handler/index.ts (line 328-333)
   const { data: refundData, error: refundError } = await supabase.rpc('add_credits', {
     p_user_id: existingJob.user_id || null,
     p_device_id: existingJob.device_id || null,
     p_amount: 1,
     p_idempotency_key: `refund-${request_id}`
   });
   ```

4. **Database Function Adds Credit**
   ```sql
   -- add_credits() (lines 285-291)
   INSERT INTO user_credits (user_id, credits)
   VALUES (p_user_id, p_amount)
   ON CONFLICT (user_id)
   DO UPDATE SET credits = user_credits.credits + p_amount;
   ```

5. **User Balance Restored**
   - Balance increases by 1
   - Idempotency prevents double-refund
   - Logged: `✅ [WEBHOOK] Credit refunded successfully`

**Refund Locations:**
1. ✅ `webhook-handler` - Job failure (line 328)
2. ✅ `submit-job` - FAL_AI_API_KEY missing (line 359)
3. ✅ `submit-job` - fal.ai submission fails (line 401)
4. ✅ `submit-job` - Exception during submission (line 431)
5. ✅ `submit-job` - Job result insert fails (line 465)

---

## 6. Edge Cases & Security

### 6.1 Double-Deduction Prevention

#### 6.1.1 Idempotency Mechanism

**Implementation:**
```sql
-- consume_credits() (lines 59-70)
IF p_idempotency_key IS NOT NULL THEN
    SELECT response_body INTO v_result
    FROM idempotency_keys
    WHERE (COALESCE(user_id::text, '') = COALESCE(p_user_id::text, '')
           AND COALESCE(device_id, '') = COALESCE(p_device_id, ''))
      AND idempotency_key = p_idempotency_key;

    IF FOUND AND v_result IS NOT NULL THEN
        RETURN v_result;  -- Return cached result
    END IF;
END IF;
```

**Key Generation:**
- **Consumption:** `requestId` (UUID from client or generated server-side)
- **Refund:** `refund-${request_id}` (prefix prevents collision)

**Storage:**
- Cached in `idempotency_keys` table
- Includes full response body
- Prevents duplicate operations forever (no expiration)

**⚠️ CONCERN:** No cleanup mechanism for old idempotency keys. Table will grow indefinitely.

#### 6.1.2 Race Condition Protection

**Database-Level Locking:**
```sql
-- consume_credits() (line 116)
SELECT credits INTO v_balance
FROM user_credits
WHERE user_id = p_user_id
FOR UPDATE;  -- ← Row-level lock prevents concurrent modifications
```

**Atomic Operations:**
```sql
-- consume_credits() (lines 137-141)
UPDATE user_credits
SET credits = credits - p_amount,
    updated_at = NOW()
WHERE user_id = p_user_id
RETURNING credits INTO v_balance;  -- ← Atomic update
```

**Effectiveness:**
- ✅ Prevents concurrent credit deductions
- ✅ Ensures balance consistency
- ✅ No race conditions possible

---

### 6.2 Premium Bypass (No Credit Consumption)

**Implementation:**
```sql
-- consume_credits() (lines 75-106)
SELECT EXISTS(
    SELECT 1 FROM subscriptions
    WHERE (
        (p_user_id IS NOT NULL AND user_id = p_user_id)
        OR (p_device_id IS NOT NULL AND device_id = p_device_id)
    )
    AND status = 'active'
    AND expires_at > NOW()
    AND status != 'cancelled'
) INTO v_is_premium;

IF v_is_premium THEN
    RETURN jsonb_build_object(
        'success', TRUE,
        'is_premium', TRUE,
        'credits_remaining', 999999  -- Unlimited
    );
END IF;
```

**Security:**
- ✅ **Server-side validation** (cannot be bypassed by client)
- ✅ **Real-time check** (not cached, always queries database)
- ✅ **Multiple conditions** (status, expiration, cancellation)

**Premium Users:**
- ✅ Never consume credits
- ✅ Always get `credits_remaining: 999999`
- ✅ Bypass all credit checks

---

### 6.3 Malicious/Erroneous Usage Prevention

#### 6.3.1 Input Validation

**Amount Validation:**
```sql
-- consume_credits() (lines 47-54)
IF p_amount <= 0 THEN
    RETURN jsonb_build_object(
        'success', FALSE,
        'error', 'Amount must be positive'
    );
END IF;
```

**Identifier Validation:**
```sql
-- consume_credits() (lines 37-44)
IF p_user_id IS NULL AND p_device_id IS NULL THEN
    RETURN jsonb_build_object(
        'success', FALSE,
        'error', 'Either user_id or device_id required'
    );
END IF;
```

#### 6.3.2 Balance Protection

**Non-Negative Constraint:**
```sql
-- user_credits table (migration 002, line 10)
credits INTEGER NOT NULL DEFAULT 0 CHECK (credits >= 0)
```

**Pre-Check Before Deduction:**
- Balance checked BEFORE deduction (lines 126, 170)
- Deduction only happens if `balance >= amount`
- Prevents negative balances at database level

#### 6.3.3 RLS (Row Level Security)

**Authenticated Users:**
```sql
-- Migration 002 (lines 36-53)
CREATE POLICY "Users can view their own credits"
    ON user_credits FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own credits"
    ON user_credits FOR UPDATE
    USING (auth.uid() = user_id);
```

**Anonymous Users:**
```sql
-- Migration 062 (lines 75-98)
CREATE POLICY "anon_select_own_credits"
    ON anonymous_credits FOR SELECT
    USING (device_id = current_setting('request.device_id', true));
```

**Service Role:**
- ✅ Full access for Edge Functions
- ✅ Can modify any user's credits (for refunds, admin grants)

**⚠️ SECURITY CONCERN:** Service role has unrestricted access. Consider adding audit logging for service role operations.

---

## 7. Analysis & Reporting

### 7.1 Current Analytics Capabilities

#### 7.1.1 Available Queries

**Location:** `supabase/migrations/014_admin_analytics_queries.sql`

**Views Created:**
1. `admin_daily_usage_summary` - Daily credit usage (last 30 days)
2. `admin_weekly_trends` - Weekly patterns
3. `admin_top_spenders` - Most active users
4. `admin_user_retention` - User engagement
5. `admin_credit_sources` - How users acquire credits
6. `admin_revenue_analytics` - Purchase patterns

**⚠️ CRITICAL ISSUE:** All these queries depend on `credit_transactions` table, which is **NOT BEING POPULATED**!

**Current State:**
- ✅ Queries are well-written
- ✅ Views are created
- ❌ **Will return empty results** because no transactions are logged

#### 7.1.2 Monitoring Queries

**Location:** `supabase/migrations/015_admin_monitoring_queries.sql`

**Functions:**
1. `admin_daily_system_check()` - Daily health metrics
2. `admin_weekly_growth_analysis()` - Growth trends
3. `admin_monthly_summary()` - Monthly reports

**⚠️ SAME ISSUE:** All depend on `credit_transactions` table.

---

### 7.2 Missing Analytics Features

**What You CAN'T Track:**
- ❌ Daily/monthly total credits consumed
- ❌ Most active credit users
- ❌ Functions/services with highest credit usage
- ❌ Ratio of failed/refunded operations
- ❌ Credit purchase patterns
- ❌ User lifetime value (credits spent)

**What You CAN Track (Limited):**
- ✅ Current credit balances (via `user_credits` table)
- ✅ Premium user count (via `subscriptions` table)
- ✅ Job success/failure rates (via `job_results` table)
- ✅ Idempotent request rate (via `idempotency_keys` table)

---

## 8. Logging & Monitoring

### 8.1 Current Logging

#### 8.1.1 Edge Function Logs

**submit-job Function:**
- ✅ Request start/end logs
- ✅ Credit consumption logs
- ✅ Premium status logs
- ✅ Error logs with context
- ✅ Idempotency detection logs

**Example Logs:**
```
🚀 [SUBMIT-JOB] Request started
🔑 [SUBMIT-JOB] Request ID: abc-123
🆕 [CREDITS] Consuming credits with persistent balance system...
✅ [CREDITS] Credit consumed: 9 remaining
✅ [SUBMIT-JOB] Success: {...}
```

**webhook-handler Function:**
- ✅ Webhook received logs
- ✅ Credit refund logs
- ✅ Job status update logs
- ✅ Error logs

**Example Logs:**
```
🔔 [WEBHOOK] Received callback from fal.ai
❌ [WEBHOOK] Job failed: Processing failed
💰 [WEBHOOK] Refunding credit for failed job...
✅ [WEBHOOK] Credit refunded successfully
```

#### 8.1.2 Database Function Logs

**PostgreSQL RAISE LOG:**
```sql
-- consume_credits() (line 149)
RAISE LOG '[CREDITS] Consumed % credits for user %, remaining: %', 
    p_amount, p_user_id, v_balance;
```

**Logs Available:**
- ✅ Credit consumption events
- ✅ Premium status checks
- ✅ Idempotent request detection
- ✅ Error conditions

**⚠️ LIMITATION:** PostgreSQL logs are not easily queryable. Consider using a logging service.

---

### 8.2 Transaction History

#### 8.2.1 Current State: ❌ **NOT IMPLEMENTED**

**Table Exists:**
- ✅ `credit_transactions` table created (migration 002)
- ✅ Schema is correct
- ✅ Indexes are created
- ✅ RLS policies configured

**But:**
- ❌ **NO INSERT statements** in `consume_credits()`
- ❌ **NO INSERT statements** in `add_credits()`
- ❌ **NO TRANSACTION HISTORY** is being recorded

**Impact:**
- Cannot audit credit operations
- Cannot track refunds vs purchases
- Cannot analyze usage patterns
- Analytics queries return empty

#### 8.2.2 Helper Function Available (Unused)

**Location:** Migration 002 (lines 100-127)

```sql
CREATE OR REPLACE FUNCTION log_credit_transaction(
    p_user_id UUID,
    p_amount INTEGER,
    p_source VARCHAR(50),
    p_metadata JSONB DEFAULT '{}'::JSONB
) RETURNS UUID
```

**Purpose:** Log transactions to `credit_transactions` table

**⚠️ ISSUE:** This function exists but is **NEVER CALLED** by credit functions!

---

### 8.3 API/Dashboard Access

#### 8.3.1 Current Access Methods

**Direct Database Queries:**
- ✅ Admin can query `user_credits` table
- ✅ Admin can query `anonymous_credits` table
- ✅ Admin views available (migration 014, 015)

**Edge Functions:**
- ✅ `get-result` - Returns job status (includes credit info in response)
- ❌ **No dedicated credit balance API endpoint**

**iOS Client:**
- ✅ `CreditManager.loadQuota()` - Fetches balance
- ✅ Uses `get_credits()` RPC function
- ✅ Caches balance locally

#### 8.3.2 Missing Features

**No Admin Dashboard:**
- ❌ No web interface for credit management
- ❌ No API endpoint for credit analytics
- ❌ No real-time credit monitoring

**No User-Facing History:**
- ❌ No transaction history endpoint
- ❌ No credit purchase history
- ❌ No spending breakdown

---

## 9. Weaknesses & Missing Features

### 9.1 Critical Issues

#### 🔴 **CRITICAL: No Transaction Logging**

**Problem:**
- `credit_transactions` table exists but is never populated
- No audit trail for credit operations
- Cannot analyze usage patterns

**Impact:**
- ❌ Cannot track credit consumption over time
- ❌ Cannot identify top users
- ❌ Cannot analyze refund rates
- ❌ Analytics queries return empty

**Fix Required:**
- Add `INSERT INTO credit_transactions` in `consume_credits()`
- Add `INSERT INTO credit_transactions` in `add_credits()`
- Use existing `log_credit_transaction()` function or inline inserts

#### 🔴 **CRITICAL: No IAP Purchase Integration**

**Problem:**
- No Edge Function for IAP verification
- No product-to-credit mapping
- Users cannot purchase credits

**Impact:**
- ❌ No revenue generation from credit sales
- ❌ Users stuck with initial 10 credits
- ❌ No monetization path

**Fix Required:**
- Create `update-credits` Edge Function
- Implement Apple App Store Server API verification
- Map product IDs to credit amounts
- Call `add_credits()` on successful purchase

---

### 9.2 High Priority Issues

#### 🟡 **HIGH: Idempotency Key Cleanup Missing**

**Problem:**
- `idempotency_keys` table grows indefinitely
- No automatic cleanup of old keys
- Will eventually impact performance

**Impact:**
- Table size grows unbounded
- Slower queries over time
- Storage costs increase

**Fix Required:**
- Add cleanup job (delete keys older than 90 days)
- Or add to existing `cleanup-db` function

#### 🟡 **HIGH: Status Code Mismatch**

**Problem:**
- Edge function returns `402` (Payment Required)
- iOS code checks for `429` (Too Many Requests)

**Location:**
- Edge Function: ```324:324:supabase/functions/submit-job/index.ts```
- iOS Code: ```285:285:BananaUniverse/Core/Services/SupabaseService.swift```

**Fix Required:**
- Update iOS to check for `402` status code
- Or change Edge Function to return `429` (less semantically correct)

---

### 9.3 Medium Priority Issues

#### 🟠 **MEDIUM: No Credit Package System**

**Problem:**
- No database table for credit packages
- No dynamic product management
- Hard to run promotions

**Impact:**
- Cannot offer different credit packages
- Cannot run A/B tests on pricing
- Changes require code deployment

**Recommendation:**
- Create `credit_packages` table (optional, from migration docs)
- Or use hardcoded mapping in Edge Function (simpler)

#### 🟠 **MEDIUM: No Refund Detection**

**Problem:**
- No Apple refund webhook handler
- No automatic credit deduction on refunds
- Manual intervention required

**Impact:**
- Users can get refunds and keep credits
- Revenue loss
- Manual cleanup needed

**Fix Required:**
- Implement Apple App Store Server Notifications webhook
- Detect refund events
- Call `add_credits()` with negative amount (or create `deduct_credits()`)

#### 🟠 **MEDIUM: No Credit Expiration**

**Problem:**
- Credits never expire
- Users can hoard credits indefinitely
- No incentive to use credits

**Impact:**
- Reduced engagement
- Credits accumulate without usage
- No urgency to purchase more

**Recommendation:**
- Consider adding expiration dates (optional)
- Or implement "use it or lose it" campaigns

---

### 9.4 Low Priority Issues

#### 🔵 **LOW: No Credit Transfer System**

**Problem:**
- Users cannot gift credits to others
- No referral bonus system

**Impact:**
- Missed engagement opportunities
- No viral growth mechanism

#### 🔵 **LOW: No Credit Usage Breakdown**

**Problem:**
- Cannot see which operations consumed credits
- No per-feature credit tracking

**Impact:**
- Limited analytics
- Cannot optimize pricing per feature

---

## 10. Security Analysis

### 10.1 Strengths

✅ **Server-Authoritative Enforcement**
- All credit operations happen server-side
- Client cannot manipulate balances
- Database functions use `SECURITY DEFINER`

✅ **RLS Policies**
- Users can only access their own credits
- Anonymous users restricted to their device_id
- Service role has controlled access

✅ **Idempotency Protection**
- Prevents double-charging
- Unique constraint on idempotency keys
- Cached responses prevent race conditions

✅ **Atomic Operations**
- `FOR UPDATE` locks prevent race conditions
- Database-level constraints prevent negative balances
- Transaction-safe operations

---

### 10.2 Security Concerns

#### ⚠️ **CONCERN: Service Role Access**

**Issue:**
- Service role can modify any user's credits
- No audit trail for service role operations
- No rate limiting on credit grants

**Risk:**
- Accidental credit grants
- Malicious credit manipulation
- No accountability

**Recommendation:**
- Add audit logging for service role operations
- Implement rate limits on `add_credits()` calls
- Require admin approval for large credit grants

#### ⚠️ **CONCERN: No Rate Limiting on Refunds**

**Issue:**
- `add_credits()` has no rate limiting
- Could be abused for credit farming

**Risk:**
- Users could trigger failures to get refunds
- No limit on refund frequency

**Recommendation:**
- Add daily refund limit (e.g., max 5 refunds/day)
- Track refund patterns
- Flag suspicious refund activity

#### ⚠️ **CONCERN: Idempotency Key Reuse**

**Issue:**
- Same idempotency key can be reused across different operations
- No expiration on cached results

**Risk:**
- Stale cached results
- Potential for key collision (low probability)

**Recommendation:**
- Add expiration to idempotency cache (90 days)
- Use operation-specific key prefixes

---

## 11. Recommended Improvements

### 11.1 Immediate Actions (Critical)

#### 1. Implement Transaction Logging

**Priority:** 🔴 **CRITICAL**

**Changes Required:**

**File:** `supabase/migrations/064_create_credit_functions.sql`

**In `consume_credits()` function, after successful deduction:**
```sql
-- After line 141 (authenticated) or 185 (anonymous)
INSERT INTO credit_transactions (
    user_id, 
    device_id, 
    amount, 
    balance_after, 
    source, 
    transaction_metadata
)
VALUES (
    p_user_id,
    p_device_id,
    -p_amount,  -- Negative for deduction
    v_balance,
    'image_processing',
    jsonb_build_object('job_id', p_idempotency_key, 'operation', 'consume')
);
```

**In `add_credits()` function, after successful addition:**
```sql
-- After line 291 (authenticated) or 311 (anonymous)
INSERT INTO credit_transactions (
    user_id,
    device_id,
    amount,
    balance_after,
    source,
    transaction_metadata
)
VALUES (
    p_user_id,
    p_device_id,
    p_amount,  -- Positive for addition
    v_balance,
    CASE 
        WHEN p_idempotency_key LIKE 'refund-%' THEN 'refund'
        ELSE 'purchase'  -- Or determine from metadata
    END,
    jsonb_build_object('idempotency_key', p_idempotency_key)
);
```

**Benefits:**
- ✅ Complete audit trail
- ✅ Analytics queries will work
- ✅ Can track usage patterns
- ✅ Can identify refund rates

---

#### 2. Create IAP Purchase Edge Function

**Priority:** 🔴 **CRITICAL**

**New File:** `supabase/functions/update-credits/index.ts`

**Required Features:**
- Verify Apple transaction via App Store Server API
- Map product_id to credit amount
- Call `add_credits()` with purchase source
- Log to `credit_transactions` table
- Handle duplicate purchases (idempotency)

**Product Mapping:**
```typescript
const PRODUCT_CREDITS = {
  'com.banana.credits.10': 10,
  'com.banana.credits.50': 50,
  'com.banana.credits.100': 100,
  'com.banana.credits.500': 500
};
```

---

#### 3. Fix Status Code Mismatch

**Priority:** 🟡 **HIGH**

**Option A: Update iOS (Recommended)**
```swift
// SupabaseService.swift (line 285)
if httpResponse.statusCode == 402 {  // Changed from 429
    throw SupabaseError.quotaExceeded
}
```

**Option B: Change Edge Function**
```typescript
// submit-job/index.ts (line 324)
{ status: 429 }  // Changed from 402
```

**Recommendation:** Use Option A (402 is semantically correct for "Payment Required")

---

### 11.2 Short-Term Improvements

#### 4. Add Idempotency Key Cleanup

**Priority:** 🟡 **HIGH**

**Add to `cleanup-db` function:**
```typescript
// Delete idempotency keys older than 90 days
const { error } = await supabase
  .from('idempotency_keys')
  .delete()
  .lt('created_at', new Date(Date.now() - 90 * 24 * 60 * 60 * 1000).toISOString());
```

---

#### 5. Add Refund Rate Limiting

**Priority:** 🟠 **MEDIUM**

**In `add_credits()` function:**
```sql
-- Check daily refund limit
IF p_idempotency_key LIKE 'refund-%' THEN
    SELECT COUNT(*) INTO v_refund_count
    FROM credit_transactions
    WHERE user_id = p_user_id
      AND source = 'refund'
      AND created_at >= CURRENT_DATE;
    
    IF v_refund_count >= 5 THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Daily refund limit exceeded'
        );
    END IF;
END IF;
```

---

#### 6. Add Credit Balance API Endpoint

**Priority:** 🟠 **MEDIUM**

**New Edge Function:** `get-credits/index.ts`

**Purpose:**
- Dedicated endpoint for credit balance
- Returns transaction history (optional)
- Better than direct RPC calls

---

### 11.3 Long-Term Improvements

#### 7. Implement Credit Packages System

**Priority:** 🔵 **LOW**

**Create `credit_packages` table:**
```sql
CREATE TABLE credit_packages (
    id TEXT PRIMARY KEY,
    credits INTEGER NOT NULL,
    price_usd DECIMAL(10,2),
    product_id TEXT UNIQUE,
    active BOOLEAN DEFAULT true,
    display_order INTEGER
);
```

**Benefits:**
- Dynamic product management
- A/B testing capabilities
- Promotional campaigns

---

#### 8. Add Credit Expiration

**Priority:** 🔵 **LOW**

**Add to `user_credits` table:**
```sql
ALTER TABLE user_credits 
ADD COLUMN credits_expire_at TIMESTAMPTZ;
```

**Implement cleanup:**
- Expire credits after 90 days of inactivity
- Or implement "use it or lose it" campaigns

---

#### 9. Add Admin Dashboard

**Priority:** 🔵 **LOW**

**Features:**
- Real-time credit balance monitoring
- Transaction history viewer
- Credit grant interface
- Analytics dashboard
- User credit management

---

## 12. Best Practices Recommendations

### 12.1 Code Quality

✅ **Already Implemented:**
- Server-authoritative enforcement
- Idempotency protection
- Atomic operations
- Comprehensive error handling
- Premium bypass logic

### 12.2 Monitoring

**Recommended:**
- Set up alerts for high refund rates
- Monitor credit balance distributions
- Track premium conversion rates
- Alert on suspicious credit grants

### 12.3 Testing

**Missing:**
- ❌ No unit tests for credit functions
- ❌ No integration tests
- ❌ No load testing for race conditions

**Recommendation:**
- Add unit tests for `consume_credits()` and `add_credits()`
- Test idempotency behavior
- Test concurrent request handling
- Test refund scenarios

---

## 13. Summary & Action Items

### ✅ What's Working Well

1. **Core Functionality:** Credit system is production-ready
2. **Security:** Server-authoritative, RLS-protected, idempotent
3. **Error Handling:** Comprehensive refund logic on failures
4. **Premium Support:** Proper bypass for premium users
5. **Hybrid Auth:** Supports both authenticated and anonymous users

### 🔴 Critical Fixes Needed

1. **Implement Transaction Logging** - Add inserts to `credit_transactions` table
2. **Create IAP Purchase Function** - Enable credit purchases
3. **Fix Status Code Mismatch** - Align iOS and Edge Function

### 🟡 High Priority Improvements

1. **Add Idempotency Cleanup** - Prevent table growth
2. **Add Refund Rate Limiting** - Prevent abuse
3. **Create Credit Balance API** - Better client access

### 📊 Analytics Gap

**Current State:** Analytics infrastructure exists but returns empty results

**Required:** Implement transaction logging to enable:
- Daily/monthly consumption tracking
- Top user identification
- Refund rate analysis
- Revenue tracking

---

## 14. Code References

### Key Files

**Database Functions:**
- `supabase/migrations/064_create_credit_functions.sql` - Main credit functions
- `supabase/migrations/062_activate_credit_system.sql` - System activation
- `supabase/migrations/002_create_user_credits.sql` - Schema creation

**Edge Functions:**
- `supabase/functions/submit-job/index.ts` - Credit consumption
- `supabase/functions/webhook-handler/index.ts` - Credit refunds
- `supabase/functions/get-result/index.ts` - Read-only (no credit operations)

**iOS Client:**
- `BananaUniverse/Core/Services/CreditManager.swift` - Credit state management
- `BananaUniverse/Core/Services/SupabaseService.swift` - API calls
- `BananaUniverse/Core/Services/QuotaService.swift` - Network layer

**Analytics:**
- `supabase/migrations/014_admin_analytics_queries.sql` - Analytics views
- `supabase/migrations/015_admin_monitoring_queries.sql` - Monitoring functions

---

**Report Generated:** 2025-01-27  
**Status:** ✅ System is functional but needs transaction logging and IAP integration  
**Overall Grade:** ⭐⭐⭐⭐ (4/5) - Production-ready with recommended improvements

