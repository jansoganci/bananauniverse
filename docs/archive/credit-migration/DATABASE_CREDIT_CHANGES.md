# Database Credit System Changes

This document details all PostgreSQL schema, function, RLS policy, and migration changes required to migrate from the quota system to the credit system.

---

## Overview

The database migration involves:
1. **New Tables**: `user_credits`, `credit_transactions`, `credit_packages` (optional)
2. **New Functions**: `deduct_credits`, `add_credits`, `get_credits`
3. **RLS Policies**: Mirror quota system patterns (user_id + device_id)
4. **Migration Strategy**: Create new schema, optional seeding, drop old quota tables

**Key Principle**: Server-authoritative credit enforcement with atomic operations and idempotency.

---

## 1. New Tables

### 1.1 `user_credits` Table

**Purpose**: Stores persistent credit balance for each user/device.

#### Schema
```sql
CREATE TABLE user_credits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id TEXT,
    balance INTEGER NOT NULL DEFAULT 0 CHECK (balance >= 0),
    lifetime_purchased INTEGER NOT NULL DEFAULT 0,
    lifetime_spent INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- One record per user/device combination
    UNIQUE(user_id, device_id),

    -- Must have either user_id OR device_id
    CHECK ((user_id IS NOT NULL) OR (device_id IS NOT NULL))
);
```

#### Indexes
```sql
CREATE INDEX idx_user_credits_user
ON user_credits(user_id)
WHERE user_id IS NOT NULL;

CREATE INDEX idx_user_credits_device
ON user_credits(device_id)
WHERE device_id IS NOT NULL;
```

#### Columns Explained
- `balance`: Current credit balance (never negative due to CHECK constraint)
- `lifetime_purchased`: Total credits purchased (via IAP or admin grant)
- `lifetime_spent`: Total credits spent (for analytics)
- `user_id`: Authenticated user (NULL for anonymous)
- `device_id`: Anonymous device identifier (NULL for authenticated)

#### Constraints
- `UNIQUE(user_id, device_id)`: Prevents duplicate records
- `CHECK (balance >= 0)`: Prevents negative balances (insufficient credit errors happen before update)
- `CHECK ((user_id IS NOT NULL) OR (device_id IS NOT NULL))`: Must have identifier

---

### 1.2 `credit_transactions` Table

**Purpose**: Audit log for all credit operations + idempotency enforcement.

#### Schema
```sql
CREATE TABLE credit_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id TEXT,
    amount INTEGER NOT NULL,  -- Positive = add, Negative = deduct
    balance_before INTEGER NOT NULL,
    balance_after INTEGER NOT NULL,
    reason TEXT NOT NULL CHECK (reason IN (
        'purchase', 'bonus', 'refund', 'image_processing',
        'processing_failed', 'admin_adjustment', 'manual_deduction'
    )),
    idempotency_key TEXT UNIQUE NOT NULL,
    metadata JSONB,  -- Extra context (job_id, tool_id, product_id, etc.)
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CHECK ((user_id IS NOT NULL) OR (device_id IS NOT NULL))
);
```

#### Indexes
```sql
CREATE INDEX idx_credit_txs_user
ON credit_transactions(user_id, created_at DESC)
WHERE user_id IS NOT NULL;

CREATE INDEX idx_credit_txs_device
ON credit_transactions(device_id, created_at DESC)
WHERE device_id IS NOT NULL;

CREATE INDEX idx_credit_txs_idempotency
ON credit_transactions(idempotency_key);

CREATE INDEX idx_credit_txs_reason
ON credit_transactions(reason);
```

#### Columns Explained
- `amount`: Positive for additions (purchase, refund), negative for deductions (processing)
- `balance_before`/`balance_after`: Snapshot of balance for audit trail
- `reason`: Categorizes transaction type (enforced via CHECK constraint)
- `idempotency_key`: Unique key prevents duplicate operations (e.g., requestId, refund-requestId)
- `metadata`: JSON field for extra context (e.g., `{"job_id": "abc-123", "tool_id": "upscaler"}`)

---

### 1.3 `credit_packages` Table (Optional)

**Purpose**: Defines available credit packages for in-app purchase (future feature).

#### Schema
```sql
CREATE TABLE credit_packages (
    id TEXT PRIMARY KEY,  -- 'starter_10', 'pro_100', etc.
    credits INTEGER NOT NULL CHECK (credits > 0),
    price_usd DECIMAL(10,2) NOT NULL,
    product_id TEXT NOT NULL,  -- App Store product ID
    active BOOLEAN DEFAULT true,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

#### Example Data
```sql
INSERT INTO credit_packages (id, credits, price_usd, product_id, display_order) VALUES
('starter_10',   10,   0.99, 'com.banana.credits.10',   1),
('standard_50',  50,   3.99, 'com.banana.credits.50',   2),
('pro_100',     100,   6.99, 'com.banana.credits.100',  3),
('premium_500', 500,  29.99, 'com.banana.credits.500',  4);
```

**Note**: Not required for initial migration (subscriptions still use `subscriptions` table). This is for future credit purchase feature.

---

## 2. New Functions

### 2.1 `deduct_credits()`

**Purpose**: Atomic credit deduction with idempotency, premium bypass, and audit logging.

#### Function Signature
```sql
CREATE OR REPLACE FUNCTION deduct_credits(
    p_user_id UUID DEFAULT NULL,
    p_device_id TEXT DEFAULT NULL,
    p_amount INTEGER DEFAULT 1,
    p_request_id TEXT DEFAULT NULL,
    p_reason TEXT DEFAULT 'image_processing'
)
RETURNS JSONB AS $$
DECLARE
    v_balance_before INTEGER;
    v_balance_after INTEGER;
    v_is_premium BOOLEAN := false;
    v_tx_id UUID;
BEGIN
    -- Validate inputs
    IF p_user_id IS NULL AND p_device_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Either user_id or device_id must be provided'
        );
    END IF;

    -- Check idempotency
    IF p_request_id IS NOT NULL THEN
        SELECT id, balance_after INTO v_tx_id, v_balance_after
        FROM credit_transactions
        WHERE idempotency_key = p_request_id;

        IF FOUND THEN
            RAISE LOG '[CREDIT] Idempotent request detected: request_id=%', p_request_id;
            RETURN jsonb_build_object(
                'success', true,
                'idempotent', true,
                'balance', v_balance_after,
                'transaction_id', v_tx_id
            );
        END IF;
    END IF;

    -- Check premium status (bypass credit check)
    SELECT EXISTS(
        SELECT 1 FROM subscriptions
        WHERE (user_id = p_user_id OR device_id = p_device_id)
        AND status = 'active'
        AND expires_at > NOW()
    ) INTO v_is_premium;

    IF v_is_premium THEN
        RAISE LOG '[CREDIT] Premium user detected - bypassing credit deduction';
        RETURN jsonb_build_object(
            'success', true,
            'premium_bypass', true,
            'balance', 999999,
            'is_premium', true
        );
    END IF;

    -- Atomic credit deduction
    UPDATE user_credits
    SET balance = balance - p_amount,
        lifetime_spent = lifetime_spent + p_amount,
        updated_at = NOW()
    WHERE (user_id = p_user_id OR (user_id IS NULL AND p_user_id IS NULL))
      AND (device_id = p_device_id OR (device_id IS NULL AND p_device_id IS NULL))
      AND balance >= p_amount  -- Only update if sufficient credits
    RETURNING balance + p_amount, balance INTO v_balance_before, v_balance_after;

    -- Check if update succeeded
    IF NOT FOUND THEN
        RAISE LOG '[CREDIT] Insufficient credits for user_id=%, device_id=%', p_user_id, p_device_id;

        -- Get current balance for error message
        SELECT balance INTO v_balance_after
        FROM user_credits
        WHERE (user_id = p_user_id OR (user_id IS NULL AND p_user_id IS NULL))
          AND (device_id = p_device_id OR (device_id IS NULL AND p_device_id IS NULL));

        RETURN jsonb_build_object(
            'success', false,
            'error', 'Insufficient credits',
            'balance', COALESCE(v_balance_after, 0),
            'is_premium', false
        );
    END IF;

    -- Log transaction for audit + idempotency
    INSERT INTO credit_transactions (
        user_id, device_id, amount, balance_before, balance_after,
        reason, idempotency_key
    ) VALUES (
        p_user_id, p_device_id, -p_amount, v_balance_before, v_balance_after,
        p_reason, p_request_id
    )
    RETURNING id INTO v_tx_id;

    RAISE LOG '[CREDIT] Deducted % credits. Balance: % → %', p_amount, v_balance_before, v_balance_after;

    -- Return success
    RETURN jsonb_build_object(
        'success', true,
        'balance', v_balance_after,
        'transaction_id', v_tx_id,
        'is_premium', false
    );

EXCEPTION
    WHEN OTHERS THEN
        RAISE LOG '[CREDIT] ERROR: %', SQLERRM;
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Database error: ' || SQLERRM
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

#### Grants
```sql
GRANT EXECUTE ON FUNCTION deduct_credits(UUID, TEXT, INTEGER, TEXT, TEXT)
TO authenticated, anon, service_role;
```

---

### 2.2 `add_credits()`

**Purpose**: Add credits (purchase, refund, admin grant) with idempotency.

#### Function Signature
```sql
CREATE OR REPLACE FUNCTION add_credits(
    p_user_id UUID DEFAULT NULL,
    p_device_id TEXT DEFAULT NULL,
    p_amount INTEGER DEFAULT 1,
    p_reason TEXT DEFAULT 'purchase',
    p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_balance_before INTEGER;
    v_balance_after INTEGER;
    v_tx_id UUID;
BEGIN
    -- Validate inputs
    IF p_user_id IS NULL AND p_device_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Either user_id or device_id must be provided'
        );
    END IF;

    IF p_amount <= 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Amount must be positive'
        );
    END IF;

    -- Check idempotency
    IF p_idempotency_key IS NOT NULL THEN
        SELECT id, balance_after INTO v_tx_id, v_balance_after
        FROM credit_transactions
        WHERE idempotency_key = p_idempotency_key;

        IF FOUND THEN
            RAISE LOG '[CREDIT] Idempotent add request: key=%', p_idempotency_key;
            RETURN jsonb_build_object(
                'success', true,
                'idempotent', true,
                'balance', v_balance_after,
                'transaction_id', v_tx_id
            );
        END IF;
    END IF;

    -- Upsert credits (create record if doesn't exist)
    INSERT INTO user_credits (user_id, device_id, balance, lifetime_purchased)
    VALUES (p_user_id, p_device_id, p_amount, p_amount)
    ON CONFLICT (user_id, device_id)
    DO UPDATE SET
        balance = user_credits.balance + p_amount,
        lifetime_purchased = user_credits.lifetime_purchased + CASE
            WHEN p_reason IN ('purchase', 'bonus') THEN p_amount
            ELSE 0
        END,
        updated_at = NOW()
    RETURNING balance - p_amount, balance INTO v_balance_before, v_balance_after;

    -- Log transaction
    INSERT INTO credit_transactions (
        user_id, device_id, amount, balance_before, balance_after,
        reason, idempotency_key
    ) VALUES (
        p_user_id, p_device_id, p_amount, v_balance_before, v_balance_after,
        p_reason, p_idempotency_key
    )
    RETURNING id INTO v_tx_id;

    RAISE LOG '[CREDIT] Added % credits (reason: %). Balance: % → %',
        p_amount, p_reason, v_balance_before, v_balance_after;

    RETURN jsonb_build_object(
        'success', true,
        'balance', v_balance_after,
        'transaction_id', v_tx_id
    );

EXCEPTION
    WHEN OTHERS THEN
        RAISE LOG '[CREDIT] ERROR: %', SQLERRM;
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Database error: ' || SQLERRM
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

#### Grants
```sql
GRANT EXECUTE ON FUNCTION add_credits(UUID, TEXT, INTEGER, TEXT, TEXT)
TO authenticated, anon, service_role;
```

---

### 2.3 `get_credits()`

**Purpose**: Fetch current credit balance (used by iOS app).

#### Function Signature
```sql
CREATE OR REPLACE FUNCTION get_credits(
    p_user_id UUID DEFAULT NULL,
    p_device_id TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_balance INTEGER := 0;
    v_lifetime_purchased INTEGER := 0;
    v_lifetime_spent INTEGER := 0;
    v_is_premium BOOLEAN := false;
BEGIN
    -- Fetch credit balance
    SELECT balance, lifetime_purchased, lifetime_spent
    INTO v_balance, v_lifetime_purchased, v_lifetime_spent
    FROM user_credits
    WHERE (user_id = p_user_id OR (user_id IS NULL AND p_user_id IS NULL))
      AND (device_id = p_device_id OR (device_id IS NULL AND p_device_id IS NULL));

    -- Check premium status
    SELECT EXISTS(
        SELECT 1 FROM subscriptions
        WHERE (user_id = p_user_id OR device_id = p_device_id)
        AND status = 'active'
        AND expires_at > NOW()
    ) INTO v_is_premium;

    RETURN jsonb_build_object(
        'balance', COALESCE(v_balance, 0),
        'lifetime_purchased', COALESCE(v_lifetime_purchased, 0),
        'lifetime_spent', COALESCE(v_lifetime_spent, 0),
        'is_premium', v_is_premium
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

#### Grants
```sql
GRANT EXECUTE ON FUNCTION get_credits(UUID, TEXT)
TO authenticated, anon, service_role;
```

---

## 3. RLS Policies

### 3.1 `user_credits` Table Policies

```sql
ALTER TABLE user_credits ENABLE ROW LEVEL SECURITY;

-- Authenticated users can view their own credits
CREATE POLICY "users_select_own_credits" ON user_credits
FOR SELECT USING (auth.uid() = user_id);

-- Anonymous users can view credits via device_id
CREATE POLICY "anon_select_device_credits" ON user_credits
FOR SELECT USING (
    device_id IS NOT NULL
    AND device_id = current_setting('request.device_id', true)
);

-- Service role has full access
CREATE POLICY "service_role_full_access_credits" ON user_credits
FOR ALL TO service_role USING (true) WITH CHECK (true);
```

**Note**: Users cannot INSERT or UPDATE directly - only via `deduct_credits()` / `add_credits()` functions (SECURITY DEFINER bypasses RLS).

---

### 3.2 `credit_transactions` Table Policies

```sql
ALTER TABLE credit_transactions ENABLE ROW LEVEL SECURITY;

-- Authenticated users can view their own transactions
CREATE POLICY "users_select_own_transactions" ON credit_transactions
FOR SELECT USING (auth.uid() = user_id);

-- Anonymous users can view transactions via device_id
CREATE POLICY "anon_select_device_transactions" ON credit_transactions
FOR SELECT USING (
    device_id IS NOT NULL
    AND device_id = current_setting('request.device_id', true)
);

-- Service role has full access
CREATE POLICY "service_role_full_access_transactions" ON credit_transactions
FOR ALL TO service_role USING (true) WITH CHECK (true);
```

**Note**: Transactions are append-only. Users can SELECT but not INSERT/UPDATE/DELETE directly.

---

### 3.3 `credit_packages` Table Policies (Optional)

```sql
ALTER TABLE credit_packages ENABLE ROW LEVEL SECURITY;

-- All users can view active packages
CREATE POLICY "public_select_active_packages" ON credit_packages
FOR SELECT USING (active = true);

-- Only service_role can modify
CREATE POLICY "service_role_full_access_packages" ON credit_packages
FOR ALL TO service_role USING (true) WITH CHECK (true);
```

---

## 4. Migration Strategy

### 4.1 Migration File: `052_create_credit_system.sql`

**File Path**: `supabase/migrations/052_create_credit_system.sql`

#### Full Migration Script
```sql
-- =====================================================
-- Migration 052: Create Credit System
-- Purpose: Replace daily quota with persistent credits
-- =====================================================

BEGIN;

-- 1. Create user_credits table
CREATE TABLE user_credits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id TEXT,
    balance INTEGER NOT NULL DEFAULT 0 CHECK (balance >= 0),
    lifetime_purchased INTEGER NOT NULL DEFAULT 0,
    lifetime_spent INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, device_id),
    CHECK ((user_id IS NOT NULL) OR (device_id IS NOT NULL))
);

CREATE INDEX idx_user_credits_user ON user_credits(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_user_credits_device ON user_credits(device_id) WHERE device_id IS NOT NULL;

-- 2. Create credit_transactions table
CREATE TABLE credit_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id TEXT,
    amount INTEGER NOT NULL,
    balance_before INTEGER NOT NULL,
    balance_after INTEGER NOT NULL,
    reason TEXT NOT NULL CHECK (reason IN (
        'purchase', 'bonus', 'refund', 'image_processing',
        'processing_failed', 'admin_adjustment', 'manual_deduction'
    )),
    idempotency_key TEXT UNIQUE NOT NULL,
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK ((user_id IS NOT NULL) OR (device_id IS NOT NULL))
);

CREATE INDEX idx_credit_txs_user ON credit_transactions(user_id, created_at DESC) WHERE user_id IS NOT NULL;
CREATE INDEX idx_credit_txs_device ON credit_transactions(device_id, created_at DESC) WHERE device_id IS NOT NULL;
CREATE INDEX idx_credit_txs_idempotency ON credit_transactions(idempotency_key);
CREATE INDEX idx_credit_txs_reason ON credit_transactions(reason);

-- 3. (Optional) Create credit_packages table
CREATE TABLE credit_packages (
    id TEXT PRIMARY KEY,
    credits INTEGER NOT NULL CHECK (credits > 0),
    price_usd DECIMAL(10,2) NOT NULL,
    product_id TEXT NOT NULL,
    active BOOLEAN DEFAULT true,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Enable RLS
ALTER TABLE user_credits ENABLE ROW LEVEL SECURITY;
ALTER TABLE credit_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE credit_packages ENABLE ROW LEVEL SECURITY;

-- 5. Create RLS policies
CREATE POLICY "users_select_own_credits" ON user_credits
FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "anon_select_device_credits" ON user_credits
FOR SELECT USING (device_id IS NOT NULL AND device_id = current_setting('request.device_id', true));

CREATE POLICY "service_role_full_access_credits" ON user_credits
FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "users_select_own_transactions" ON credit_transactions
FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "anon_select_device_transactions" ON credit_transactions
FOR SELECT USING (device_id IS NOT NULL AND device_id = current_setting('request.device_id', true));

CREATE POLICY "service_role_full_access_transactions" ON credit_transactions
FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "public_select_active_packages" ON credit_packages
FOR SELECT USING (active = true);

CREATE POLICY "service_role_full_access_packages" ON credit_packages
FOR ALL TO service_role USING (true) WITH CHECK (true);

-- 6. Create functions (see section 2 for full implementations)
-- Insert deduct_credits() function here
-- Insert add_credits() function here
-- Insert get_credits() function here

COMMIT;
```

---

### 4.2 Optional: Seed Initial Credits

**Goal**: Give existing users 10 free credits as migration bonus.

**Script**:
```sql
-- Grant 10 credits to all users who used quota system today
INSERT INTO user_credits (user_id, device_id, balance, lifetime_purchased)
SELECT
    user_id,
    device_id,
    10,  -- Free credits
    10   -- Count as lifetime purchased
FROM daily_quota
WHERE date = CURRENT_DATE
ON CONFLICT (user_id, device_id) DO NOTHING;

-- Alternative: Grant to ALL users in auth.users
INSERT INTO user_credits (user_id, device_id, balance, lifetime_purchased)
SELECT
    id,
    NULL,
    10,
    10
FROM auth.users
ON CONFLICT (user_id, device_id) DO NOTHING;
```

**Note**: This is optional. New users will automatically get credits set to 0 on first `add_credits()` call.

---

## 5. Idempotency Implementation

### 5.1 How It Works

**Idempotency Key**: `credit_transactions.idempotency_key` (UNIQUE constraint)

**Flow**:
1. Edge Function generates `requestId` (e.g., `abc-123`)
2. Calls `deduct_credits(p_request_id := 'abc-123')`
3. Function checks: `SELECT * FROM credit_transactions WHERE idempotency_key = 'abc-123'`
4. If FOUND: Return cached result (idempotent)
5. If NOT FOUND: Deduct credit, INSERT transaction with `idempotency_key = 'abc-123'`
6. Client retries with same `requestId` → cached result returned, no double-charge

---

### 5.2 Idempotency Key Patterns

| Operation | Key Format | Example |
|-----------|------------|---------|
| Credit deduction | `requestId` | `abc-123-def-456` |
| Refund | `refund-{requestId}` | `refund-abc-123-def-456` |
| Purchase | `purchase-{transactionId}` | `purchase-apple-tx-789` |
| Admin grant | `admin-{timestamp}-{userId}` | `admin-2025-01-15-user-123` |

---

### 5.3 Race Condition Prevention

**Scenario**: Two concurrent requests with same `requestId`

**Handling**:
```sql
-- First request
INSERT INTO credit_transactions (..., idempotency_key)
VALUES (..., 'abc-123');  -- ✅ Succeeds

-- Second request (concurrent)
INSERT INTO credit_transactions (..., idempotency_key)
VALUES (..., 'abc-123');  -- ❌ Fails: UNIQUE constraint violation

-- Function catches error and returns cached result
```

**Postgres UNIQUE constraint ensures atomic idempotency check.**

---

## 6. Cleanup (Phase 7)

### 6.1 Drop Old Quota Tables

**Run AFTER iOS + Edge Function updates are live and tested (48+ hours):**

```sql
-- Drop old quota tables
DROP TABLE IF EXISTS daily_quotas CASCADE;
DROP TABLE IF EXISTS quota_consumption_log CASCADE;
DROP TABLE IF EXISTS daily_quota CASCADE;  -- Legacy, if exists

-- Drop old quota functions
DROP FUNCTION IF EXISTS consume_quota(UUID, TEXT, BOOLEAN, UUID);
DROP FUNCTION IF EXISTS get_quota(UUID, TEXT);
DROP FUNCTION IF EXISTS refund_quota(UUID, TEXT, UUID);
DROP FUNCTION IF EXISTS validate_user_daily_quota(UUID, BOOLEAN);
DROP FUNCTION IF EXISTS validate_anonymous_daily_quota(TEXT, BOOLEAN);
DROP FUNCTION IF EXISTS consume_credit_with_quota(UUID, TEXT, BOOLEAN);
DROP FUNCTION IF EXISTS cleanup_quota_consumption_logs();
DROP FUNCTION IF EXISTS cleanup_old_daily_quotas();
```

---

### 6.2 Remove Old Migrations (Optional)

**Files to Archive** (move to `supabase/migrations/archive/`):
- `017_create_daily_quota.sql`
- `018_create_quota_functions.sql`
- `011_add_daily_quota_tracking.sql`
- `012_add_quota_validation_functions.sql`
- All related quota patches (019-049)

**Why Archive Instead of Delete?** Historical reference, rollback capability.

---

## 7. Testing SQL Functions

### 7.1 Test `deduct_credits`

**Test 1: Successful Deduction**
```sql
-- Setup: Create user with 10 credits
INSERT INTO user_credits (user_id, device_id, balance, lifetime_purchased)
VALUES ('test-user-id'::uuid, NULL, 10, 10);

-- Test: Deduct 1 credit
SELECT deduct_credits(
    p_user_id := 'test-user-id'::uuid,
    p_device_id := NULL,
    p_amount := 1,
    p_request_id := 'test-request-1',
    p_reason := 'test'
);

-- Expected: {"success": true, "balance": 9, "transaction_id": "..."}

-- Verify:
SELECT balance FROM user_credits WHERE user_id = 'test-user-id'::uuid;
-- Expected: 9
```

**Test 2: Insufficient Credits**
```sql
-- Setup: User has 0 credits
UPDATE user_credits SET balance = 0 WHERE user_id = 'test-user-id'::uuid;

-- Test: Attempt to deduct 1 credit
SELECT deduct_credits(
    p_user_id := 'test-user-id'::uuid,
    p_device_id := NULL,
    p_amount := 1,
    p_request_id := 'test-request-2',
    p_reason := 'test'
);

-- Expected: {"success": false, "error": "Insufficient credits", "balance": 0}
```

**Test 3: Idempotency**
```sql
-- Test: Same request_id twice
SELECT deduct_credits(p_user_id := 'test-user-id'::uuid, p_request_id := 'test-request-3', p_amount := 1);
SELECT deduct_credits(p_user_id := 'test-user-id'::uuid, p_request_id := 'test-request-3', p_amount := 1);

-- Expected: Second call returns {"success": true, "idempotent": true, "balance": X}
-- Balance should only decrease once
```

**Test 4: Premium Bypass**
```sql
-- Setup: Create active subscription
INSERT INTO subscriptions (user_id, status, product_id, expires_at, original_transaction_id)
VALUES ('test-user-id'::uuid, 'active', 'banana_weekly', NOW() + INTERVAL '7 days', 'test-tx-123');

-- Test: Deduct credits (should bypass)
SELECT deduct_credits(
    p_user_id := 'test-user-id'::uuid,
    p_request_id := 'test-request-4',
    p_amount := 1
);

-- Expected: {"success": true, "premium_bypass": true, "balance": 999999}
```

---

### 7.2 Test `add_credits`

**Test 1: Add Credits**
```sql
SELECT add_credits(
    p_user_id := 'test-user-id'::uuid,
    p_amount := 10,
    p_reason := 'purchase',
    p_idempotency_key := 'test-add-1'
);

-- Expected: {"success": true, "balance": X+10}
```

**Test 2: Idempotent Add**
```sql
SELECT add_credits(p_user_id := 'test-user-id'::uuid, p_amount := 10, p_idempotency_key := 'test-add-2');
SELECT add_credits(p_user_id := 'test-user-id'::uuid, p_amount := 10, p_idempotency_key := 'test-add-2');

-- Expected: Balance increases only once
```

---

### 7.3 Test `get_credits`

```sql
SELECT get_credits(p_user_id := 'test-user-id'::uuid);

-- Expected: {"balance": X, "lifetime_purchased": Y, "lifetime_spent": Z, "is_premium": true/false}
```

---

## 8. Monitoring & Analytics

### 8.1 Useful Queries

**Top credit spenders (last 7 days)**:
```sql
SELECT
    COALESCE(user_id::text, device_id) as identifier,
    SUM(ABS(amount)) as credits_spent,
    COUNT(*) as transactions
FROM credit_transactions
WHERE created_at > NOW() - INTERVAL '7 days'
  AND amount < 0  -- Only deductions
GROUP BY identifier
ORDER BY credits_spent DESC
LIMIT 10;
```

**Refund rate**:
```sql
SELECT
    COUNT(*) FILTER (WHERE reason = 'processing_failed') * 100.0 / COUNT(*) as refund_rate_pct
FROM credit_transactions
WHERE created_at > NOW() - INTERVAL '7 days'
  AND amount > 0;  -- Only additions
```

**Average credit balance**:
```sql
SELECT
    AVG(balance) as avg_balance,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY balance) as median_balance
FROM user_credits;
```

---

### 8.2 Alerts to Set Up

- **High refund rate** (> 10%) → AI processing issues
- **Negative balance attempts** (should never succeed) → Bug in function
- **Duplicate idempotency keys** (normal, but spike indicates retries) → Network issues

---

## 9. Security Considerations

### 9.1 RLS Protection

- ✅ Users can only view their own credits (via `user_id` or `device_id`)
- ✅ Credit deduction/addition only via SECURITY DEFINER functions (bypass RLS)
- ✅ Service role has full access for admin operations

### 9.2 SQL Injection Prevention

- ✅ All functions use parameterized queries (no string concatenation)
- ✅ CHECK constraints prevent negative balances
- ✅ UNIQUE constraints enforce idempotency

### 9.3 Race Condition Protection

- ✅ Atomic UPDATE with `balance >= p_amount` condition
- ✅ UNIQUE idempotency_key prevents duplicate transactions
- ✅ `RETURNING` clause ensures consistent balance reads

---

## 10. Deployment Checklist

### Pre-Deployment
- [ ] Review migration script `052_create_credit_system.sql`
- [ ] Test all functions on local Supabase (`supabase start`)
- [ ] Verify RLS policies work for authenticated + anonymous users
- [ ] Test idempotency with duplicate requests
- [ ] Test premium bypass with active subscription

### Deployment
- [ ] Run migration on staging database
- [ ] Verify tables, indexes, functions created
- [ ] Test RPC calls from Edge Function (staging)
- [ ] Run migration on production database
- [ ] Monitor logs for errors

### Post-Deployment (48 hours)
- [ ] Verify no credit double-charges
- [ ] Verify refunds work correctly
- [ ] Check refund rate (should be < 5%)
- [ ] Monitor balance accuracy (compare with transaction log)

### Cleanup (After iOS Update is Live)
- [ ] Drop old quota tables (`daily_quotas`, `quota_consumption_log`)
- [ ] Drop old quota functions
- [ ] Archive old migrations

---

## Next Steps

1. Review this document with database team
2. Test migration script on local environment
3. Deploy to staging and run full test suite
4. Deploy to production during low-traffic window
5. Monitor for 48 hours before cleanup
6. Execute cleanup (drop old tables/functions)
