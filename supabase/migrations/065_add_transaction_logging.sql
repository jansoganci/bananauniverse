-- =====================================================
-- Migration 065: Add Transaction Logging to Credit System
-- Purpose: Enable complete audit trail for all credit operations
-- Date: 2025-01-27
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE 'Adding transaction logging to credit system...';
END $$;

-- =====================================================
-- STEP 1: Update credit_transactions Table Schema
-- =====================================================
-- Add missing columns to support anonymous users and better audit trail

-- Add device_id column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'credit_transactions' AND column_name = 'device_id'
    ) THEN
        ALTER TABLE credit_transactions ADD COLUMN device_id TEXT;
        RAISE NOTICE 'Added device_id column to credit_transactions';
    END IF;
END $$;

-- Add balance_before column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'credit_transactions' AND column_name = 'balance_before'
    ) THEN
        ALTER TABLE credit_transactions ADD COLUMN balance_before INTEGER;
        RAISE NOTICE 'Added balance_before column to credit_transactions';
    END IF;
END $$;

-- Add idempotency_key column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'credit_transactions' AND column_name = 'idempotency_key'
    ) THEN
        ALTER TABLE credit_transactions ADD COLUMN idempotency_key TEXT;
        RAISE NOTICE 'Added idempotency_key column to credit_transactions';
    END IF;
END $$;

-- Make user_id nullable (for anonymous users)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'credit_transactions' 
        AND column_name = 'user_id' 
        AND is_nullable = 'NO'
    ) THEN
        ALTER TABLE credit_transactions ALTER COLUMN user_id DROP NOT NULL;
        RAISE NOTICE 'Made user_id nullable in credit_transactions';
    END IF;
END $$;

-- Add CHECK constraint to ensure either user_id or device_id exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'credit_transactions_identifier_check'
    ) THEN
        ALTER TABLE credit_transactions 
        ADD CONSTRAINT credit_transactions_identifier_check 
        CHECK ((user_id IS NOT NULL) OR (device_id IS NOT NULL));
        RAISE NOTICE 'Added identifier check constraint';
    END IF;
END $$;

-- Rename 'source' to 'reason' if 'reason' doesn't exist
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'credit_transactions' AND column_name = 'source'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'credit_transactions' AND column_name = 'reason'
    ) THEN
        ALTER TABLE credit_transactions RENAME COLUMN source TO reason;
        RAISE NOTICE 'Renamed source column to reason';
    END IF;
END $$;

-- Add indexes for device_id and idempotency_key
CREATE INDEX IF NOT EXISTS idx_credit_transactions_device_id 
ON credit_transactions(device_id) 
WHERE device_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_credit_transactions_idempotency_key 
ON credit_transactions(idempotency_key) 
WHERE idempotency_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_credit_transactions_reason 
ON credit_transactions(reason);

-- Update existing index to include device_id
DROP INDEX IF EXISTS idx_credit_transactions_user_id;
CREATE INDEX IF NOT EXISTS idx_credit_transactions_user_id 
ON credit_transactions(user_id, created_at DESC) 
WHERE user_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_credit_transactions_device_created 
ON credit_transactions(device_id, created_at DESC) 
WHERE device_id IS NOT NULL;

-- =====================================================
-- STEP 2: Update RLS Policies for Anonymous Users
-- =====================================================

-- Add policy for anonymous users to view their own transactions
DROP POLICY IF EXISTS "anon_select_device_transactions" ON credit_transactions;
CREATE POLICY "anon_select_device_transactions"
    ON credit_transactions
    FOR SELECT
    USING (
        device_id IS NOT NULL
        AND device_id = current_setting('request.device_id', true)
    );

-- Service role can do everything (for Edge Functions)
DROP POLICY IF EXISTS "service_role_all_transactions" ON credit_transactions;
CREATE POLICY "service_role_all_transactions"
    ON credit_transactions
    FOR ALL
    USING (auth.role() = 'service_role')
    WITH CHECK (auth.role() = 'service_role');

-- =====================================================
-- STEP 3: Create Enhanced Logging Function
-- =====================================================

CREATE OR REPLACE FUNCTION log_credit_transaction(
    p_amount INTEGER,
    p_balance_before INTEGER,
    p_balance_after INTEGER,
    p_reason TEXT,
    p_user_id UUID DEFAULT NULL,
    p_device_id TEXT DEFAULT NULL,
    p_idempotency_key TEXT DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'::JSONB
)
RETURNS UUID AS $$
DECLARE
    v_transaction_id UUID;
BEGIN
    -- Validate inputs
    IF p_user_id IS NULL AND p_device_id IS NULL THEN
        RAISE EXCEPTION 'Either user_id or device_id required for transaction logging';
    END IF;

    IF p_amount = 0 THEN
        RAISE EXCEPTION 'Transaction amount cannot be zero';
    END IF;

    -- Insert transaction record
    INSERT INTO credit_transactions (
        user_id,
        device_id,
        amount,
        balance_before,
        balance_after,
        reason,
        idempotency_key,
        transaction_metadata,
        created_at
    )
    VALUES (
        p_user_id,
        p_device_id,
        p_amount,
        p_balance_before,
        p_balance_after,
        p_reason,
        p_idempotency_key,
        p_metadata,
        NOW()
    )
    RETURNING id INTO v_transaction_id;

    RAISE LOG '[TRANSACTION] Logged: user_id=%, device_id=%, amount=%, reason=%, idempotency_key=%',
        p_user_id, p_device_id, p_amount, p_reason, p_idempotency_key;

    RETURN v_transaction_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION log_credit_transaction(INTEGER, INTEGER, INTEGER, TEXT, UUID, TEXT, TEXT, JSONB) TO service_role;
GRANT EXECUTE ON FUNCTION log_credit_transaction(INTEGER, INTEGER, INTEGER, TEXT, UUID, TEXT, TEXT, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION log_credit_transaction(INTEGER, INTEGER, INTEGER, TEXT, UUID, TEXT, TEXT, JSONB) TO anon;

COMMENT ON FUNCTION log_credit_transaction(INTEGER, INTEGER, INTEGER, TEXT, UUID, TEXT, TEXT, JSONB) IS
'Logs a credit transaction to credit_transactions table. Supports both authenticated and anonymous users.';

-- =====================================================
-- STEP 4: Update consume_credits() to Log Transactions
-- =====================================================

CREATE OR REPLACE FUNCTION consume_credits(
    p_user_id UUID DEFAULT NULL,
    p_device_id TEXT DEFAULT NULL,
    p_amount INTEGER DEFAULT 1,
    p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_balance INTEGER;
    v_balance_before INTEGER;
    v_result JSONB;
    v_is_premium BOOLEAN := FALSE;
BEGIN
    -- Set device_id session for RLS
    IF p_device_id IS NOT NULL THEN
        PERFORM set_config('request.device_id', p_device_id, true);
    END IF;

    -- Validate inputs
    IF p_user_id IS NULL AND p_device_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Either user_id or device_id required',
            'credits_remaining', 0,
            'is_premium', FALSE
        );
    END IF;

    -- Validate amount is positive
    IF p_amount <= 0 THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Amount must be positive',
            'credits_remaining', 0,
            'is_premium', FALSE
        );
    END IF;

    -- ========================================
    -- STEP 1: IDEMPOTENCY CHECK
    -- ========================================
    IF p_idempotency_key IS NOT NULL THEN
        SELECT response_body INTO v_result
        FROM idempotency_keys
        WHERE (COALESCE(user_id::text, '') = COALESCE(p_user_id::text, '')
               AND COALESCE(device_id, '') = COALESCE(p_device_id, ''))
          AND idempotency_key = p_idempotency_key;

        IF FOUND AND v_result IS NOT NULL THEN
            RAISE LOG '[CREDITS] Idempotent request: returning cached result for key=%', p_idempotency_key;
            RETURN v_result;
        END IF;
    END IF;

    -- ========================================
    -- STEP 2: CHECK PREMIUM STATUS
    -- ========================================
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

    RAISE LOG '[CREDITS] Premium check: user_id=%, device_id=%, is_premium=%',
        p_user_id, p_device_id, v_is_premium;

    -- Premium users bypass credit checks
    IF v_is_premium THEN
        v_result := jsonb_build_object(
            'success', TRUE,
            'is_premium', TRUE,
            'credits_remaining', 999999
        );

        -- Cache idempotency result
        IF p_idempotency_key IS NOT NULL THEN
            INSERT INTO idempotency_keys (user_id, device_id, idempotency_key, response_status, response_body)
            VALUES (p_user_id, p_device_id, p_idempotency_key, 200, v_result)
            ON CONFLICT (COALESCE(user_id::text, ''), COALESCE(device_id, ''), idempotency_key)
            DO UPDATE SET response_body = v_result;
        END IF;

        RETURN v_result;
    END IF;

    -- ========================================
    -- STEP 3: CONSUME CREDITS (Authenticated Users)
    -- ========================================
    IF p_user_id IS NOT NULL THEN
        -- Lock row and get current balance
        SELECT credits INTO v_balance_before
        FROM user_credits
        WHERE user_id = p_user_id
        FOR UPDATE;

        -- Create record if doesn't exist
        IF NOT FOUND THEN
            INSERT INTO user_credits (user_id, credits)
            VALUES (p_user_id, 10)
            RETURNING credits INTO v_balance_before;
        END IF;

        -- Check if sufficient balance
        IF v_balance_before < p_amount THEN
            v_result := jsonb_build_object(
                'success', FALSE,
                'error', 'Insufficient credits',
                'credits_remaining', v_balance_before,
                'is_premium', FALSE
            );

            RAISE LOG '[CREDITS] Insufficient: user has % credits, needs %', v_balance_before, p_amount;
        ELSE
            -- Atomically deduct credits
            UPDATE user_credits
            SET credits = credits - p_amount,
                updated_at = NOW()
            WHERE user_id = p_user_id
            RETURNING credits INTO v_balance;

            -- Log transaction (only on successful deduction)
            PERFORM log_credit_transaction(
                p_amount := -p_amount,  -- Negative for deduction
                p_balance_before := v_balance_before,
                p_balance_after := v_balance,
                p_reason := 'image_processing',
                p_user_id := p_user_id,
                p_device_id := NULL,
                p_idempotency_key := p_idempotency_key,
                p_metadata := jsonb_build_object(
                    'operation', 'consume_credits',
                    'idempotency_key', p_idempotency_key
                )
            );

            v_result := jsonb_build_object(
                'success', TRUE,
                'credits_remaining', v_balance,
                'is_premium', FALSE
            );

            RAISE LOG '[CREDITS] Consumed % credits for user %, remaining: %', p_amount, p_user_id, v_balance;
        END IF;

    -- ========================================
    -- STEP 4: CONSUME CREDITS (Anonymous Users)
    -- ========================================
    ELSE
        -- Lock row and get current balance
        SELECT credits INTO v_balance_before
        FROM anonymous_credits
        WHERE device_id = p_device_id
        FOR UPDATE;

        -- Create record if doesn't exist
        IF NOT FOUND THEN
            INSERT INTO anonymous_credits (device_id, credits)
            VALUES (p_device_id, 10)
            RETURNING credits INTO v_balance_before;
        END IF;

        -- Check if sufficient balance
        IF v_balance_before < p_amount THEN
            v_result := jsonb_build_object(
                'success', FALSE,
                'error', 'Insufficient credits',
                'credits_remaining', v_balance_before,
                'is_premium', FALSE
            );

            RAISE LOG '[CREDITS] Insufficient: device % has % credits, needs %', p_device_id, v_balance_before, p_amount;
        ELSE
            -- Atomically deduct credits
            UPDATE anonymous_credits
            SET credits = credits - p_amount,
                updated_at = NOW()
            WHERE device_id = p_device_id
            RETURNING credits INTO v_balance;

            -- Log transaction (only on successful deduction)
            PERFORM log_credit_transaction(
                p_amount := -p_amount,  -- Negative for deduction
                p_balance_before := v_balance_before,
                p_balance_after := v_balance,
                p_reason := 'image_processing',
                p_user_id := NULL,
                p_device_id := p_device_id,
                p_idempotency_key := p_idempotency_key,
                p_metadata := jsonb_build_object(
                    'operation', 'consume_credits',
                    'idempotency_key', p_idempotency_key
                )
            );

            v_result := jsonb_build_object(
                'success', TRUE,
                'credits_remaining', v_balance,
                'is_premium', FALSE
            );

            RAISE LOG '[CREDITS] Consumed % credits for device %, remaining: %', p_amount, p_device_id, v_balance;
        END IF;
    END IF;

    -- ========================================
    -- STEP 5: CACHE IDEMPOTENCY RESULT
    -- ========================================
    IF p_idempotency_key IS NOT NULL THEN
        INSERT INTO idempotency_keys (user_id, device_id, idempotency_key, response_status, response_body)
        VALUES (p_user_id, p_device_id, p_idempotency_key,
                CASE WHEN (v_result->>'success')::boolean THEN 200 ELSE 402 END,
                v_result)
        ON CONFLICT (COALESCE(user_id::text, ''), COALESCE(device_id, ''), idempotency_key)
        DO UPDATE SET response_body = v_result;
    END IF;

    RETURN v_result;

EXCEPTION
    WHEN OTHERS THEN
        RAISE LOG '[CREDITS] ERROR: %', SQLERRM;
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Database error: ' || SQLERRM,
            'credits_remaining', 0,
            'is_premium', FALSE
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- STEP 5: Update add_credits() to Log Transactions
-- =====================================================

CREATE OR REPLACE FUNCTION add_credits(
    p_user_id UUID DEFAULT NULL,
    p_device_id TEXT DEFAULT NULL,
    p_amount INTEGER DEFAULT 1,
    p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_balance INTEGER;
    v_balance_before INTEGER;
    v_result JSONB;
    v_reason TEXT;
BEGIN
    -- Set device_id session for RLS
    IF p_device_id IS NOT NULL THEN
        PERFORM set_config('request.device_id', p_device_id, true);
    END IF;

    -- Validate inputs
    IF p_user_id IS NULL AND p_device_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Either user_id or device_id required',
            'credits_remaining', 0
        );
    END IF;

    -- Validate amount is positive
    IF p_amount <= 0 THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Amount must be positive',
            'credits_remaining', 0
        );
    END IF;

    -- Determine reason based on idempotency key
    IF p_idempotency_key IS NOT NULL AND p_idempotency_key LIKE 'refund-%' THEN
        v_reason := 'refund';
    ELSIF p_idempotency_key IS NOT NULL AND p_idempotency_key LIKE 'purchase-%' THEN
        v_reason := 'purchase';
    ELSIF p_idempotency_key IS NOT NULL AND p_idempotency_key LIKE 'admin-%' THEN
        v_reason := 'admin_adjustment';
    ELSE
        v_reason := 'bonus';  -- Default for grants, bonuses, etc.
    END IF;

    -- ========================================
    -- STEP 1: IDEMPOTENCY CHECK
    -- ========================================
    IF p_idempotency_key IS NOT NULL THEN
        SELECT response_body INTO v_result
        FROM idempotency_keys
        WHERE (COALESCE(user_id::text, '') = COALESCE(p_user_id::text, '')
               AND COALESCE(device_id, '') = COALESCE(p_device_id, ''))
          AND idempotency_key = p_idempotency_key;

        IF FOUND AND v_result IS NOT NULL THEN
            RAISE LOG '[REFUND] Idempotent request: returning cached result for key=%', p_idempotency_key;
            RETURN v_result;
        END IF;
    END IF;

    -- ========================================
    -- STEP 2: ADD CREDITS (Authenticated Users)
    -- ========================================
    IF p_user_id IS NOT NULL THEN
        -- Get current balance before update
        SELECT COALESCE(credits, 0) INTO v_balance_before
        FROM user_credits
        WHERE user_id = p_user_id;

        -- Ensure user record exists
        INSERT INTO user_credits (user_id, credits)
        VALUES (p_user_id, p_amount)
        ON CONFLICT (user_id)
        DO UPDATE SET
            credits = user_credits.credits + p_amount,
            updated_at = NOW()
        RETURNING credits INTO v_balance;

        -- If record didn't exist, balance_before was 0
        IF v_balance_before IS NULL THEN
            v_balance_before := 0;
        END IF;

        -- Log transaction
        PERFORM log_credit_transaction(
            p_amount := p_amount,  -- Positive for addition
            p_balance_before := v_balance_before,
            p_balance_after := v_balance,
            p_reason := v_reason,
            p_user_id := p_user_id,
            p_device_id := NULL,
            p_idempotency_key := p_idempotency_key,
            p_metadata := jsonb_build_object(
                'operation', 'add_credits',
                'idempotency_key', p_idempotency_key
            )
        );

        v_result := jsonb_build_object(
            'success', TRUE,
            'credits_remaining', v_balance
        );

        RAISE LOG '[REFUND] Added % credits for user %, new balance: %', p_amount, p_user_id, v_balance;

    -- ========================================
    -- STEP 3: ADD CREDITS (Anonymous Users)
    -- ========================================
    ELSE
        -- Get current balance before update
        SELECT COALESCE(credits, 0) INTO v_balance_before
        FROM anonymous_credits
        WHERE device_id = p_device_id;

        -- Ensure device record exists
        INSERT INTO anonymous_credits (device_id, credits)
        VALUES (p_device_id, p_amount)
        ON CONFLICT (device_id)
        DO UPDATE SET
            credits = anonymous_credits.credits + p_amount,
            updated_at = NOW()
        RETURNING credits INTO v_balance;

        -- If record didn't exist, balance_before was 0
        IF v_balance_before IS NULL THEN
            v_balance_before := 0;
        END IF;

        -- Log transaction
        PERFORM log_credit_transaction(
            p_amount := p_amount,  -- Positive for addition
            p_balance_before := v_balance_before,
            p_balance_after := v_balance,
            p_reason := v_reason,
            p_user_id := NULL,
            p_device_id := p_device_id,
            p_idempotency_key := p_idempotency_key,
            p_metadata := jsonb_build_object(
                'operation', 'add_credits',
                'idempotency_key', p_idempotency_key
            )
        );

        v_result := jsonb_build_object(
            'success', TRUE,
            'credits_remaining', v_balance
        );

        RAISE LOG '[REFUND] Added % credits for device %, new balance: %', p_amount, p_device_id, v_balance;
    END IF;

    -- ========================================
    -- STEP 4: CACHE IDEMPOTENCY RESULT
    -- ========================================
    IF p_idempotency_key IS NOT NULL THEN
        INSERT INTO idempotency_keys (user_id, device_id, idempotency_key, response_status, response_body)
        VALUES (p_user_id, p_device_id, p_idempotency_key, 200, v_result)
        ON CONFLICT (COALESCE(user_id::text, ''), COALESCE(device_id, ''), idempotency_key)
        DO UPDATE SET response_body = v_result;
    END IF;

    RETURN v_result;

EXCEPTION
    WHEN OTHERS THEN
        RAISE LOG '[REFUND] ERROR: %', SQLERRM;
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Database error: ' || SQLERRM,
            'credits_remaining', 0
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- PERMISSIONS
-- =====================================================

ALTER FUNCTION consume_credits(UUID, TEXT, INTEGER, TEXT) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION consume_credits(UUID, TEXT, INTEGER, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION consume_credits(UUID, TEXT, INTEGER, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION consume_credits(UUID, TEXT, INTEGER, TEXT) TO anon;

ALTER FUNCTION add_credits(UUID, TEXT, INTEGER, TEXT) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION add_credits(UUID, TEXT, INTEGER, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION add_credits(UUID, TEXT, INTEGER, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION add_credits(UUID, TEXT, INTEGER, TEXT) TO anon;

-- =====================================================
-- VERIFICATION
-- =====================================================

DO $$
DECLARE
    v_consume_exists BOOLEAN;
    v_add_exists BOOLEAN;
    v_log_exists BOOLEAN;
    v_device_id_exists BOOLEAN;
BEGIN
    -- Check if functions exist
    SELECT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'consume_credits') INTO v_consume_exists;
    SELECT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'add_credits') INTO v_add_exists;
    SELECT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'log_credit_transaction') INTO v_log_exists;
    
    -- Check if device_id column exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'credit_transactions' AND column_name = 'device_id'
    ) INTO v_device_id_exists;

    IF NOT v_consume_exists OR NOT v_add_exists OR NOT v_log_exists THEN
        RAISE EXCEPTION 'Credit functions not updated successfully!';
    END IF;

    IF NOT v_device_id_exists THEN
        RAISE EXCEPTION 'credit_transactions table not updated with device_id!';
    END IF;

    RAISE NOTICE '========================================';
    RAISE NOTICE 'Transaction Logging System Activated';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'consume_credits(): ✅ UPDATED with logging';
    RAISE NOTICE 'add_credits(): ✅ UPDATED with logging';
    RAISE NOTICE 'log_credit_transaction(): ✅ ACTIVE';
    RAISE NOTICE 'credit_transactions.device_id: ✅ ADDED';
    RAISE NOTICE 'credit_transactions.balance_before: ✅ ADDED';
    RAISE NOTICE 'credit_transactions.idempotency_key: ✅ ADDED';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ SUCCESS: Transaction logging enabled!';
END $$;

-- =====================================================
-- Migration Complete
-- =====================================================
-- ✅ credit_transactions table updated with device_id, balance_before, idempotency_key
-- ✅ log_credit_transaction() function created/updated
-- ✅ consume_credits() updated to log all deductions
-- ✅ add_credits() updated to log all additions
-- ✅ Supports both authenticated and anonymous users
-- ✅ All transactions include balance_before, balance_after, reason, metadata
-- ✅ Idempotency keys included in transaction logs

