-- =====================================================
-- Migration 086: Add Lifetime Credit Tracking & Initial Grant
-- Purpose: Track lifetime credits and prevent reinstall abuse
-- Date: 2025-11-15
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE 'Adding lifetime credit tracking and initial grant flags...';
END $$;

-- =====================================================
-- STEP 1: Add columns to user_credits
-- =====================================================

ALTER TABLE user_credits
ADD COLUMN IF NOT EXISTS credits_total INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS initial_grant_claimed BOOLEAN DEFAULT FALSE;

COMMENT ON COLUMN user_credits.credits_total IS 'Lifetime total credits ever granted/purchased (never decreases)';
COMMENT ON COLUMN user_credits.initial_grant_claimed IS 'Whether user has received their one-time 10 credit grant';

-- =====================================================
-- STEP 2: Add columns to anonymous_credits
-- =====================================================

ALTER TABLE anonymous_credits
ADD COLUMN IF NOT EXISTS credits_total INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS initial_grant_claimed BOOLEAN DEFAULT FALSE;

COMMENT ON COLUMN anonymous_credits.credits_total IS 'Lifetime total credits ever granted/purchased (never decreases)';
COMMENT ON COLUMN anonymous_credits.initial_grant_claimed IS 'Whether device has received their one-time 10 credit grant';

-- =====================================================
-- STEP 3: Migrate existing users (give them credit for current balance)
-- =====================================================

-- For authenticated users
UPDATE user_credits
SET credits_total = credits,
    initial_grant_claimed = TRUE  -- Existing users already got their grant
WHERE credits_total = 0;

-- For anonymous users
UPDATE anonymous_credits
SET credits_total = credits,
    initial_grant_claimed = TRUE  -- Existing devices already got their grant
WHERE credits_total = 0;

-- =====================================================
-- STEP 4: Add idempotency_key to credit_transactions
-- =====================================================

ALTER TABLE credit_transactions
ADD COLUMN IF NOT EXISTS idempotency_key TEXT;

COMMENT ON COLUMN credit_transactions.idempotency_key IS 'Prevents duplicate credit grants (purchases, promos, etc.)';

-- Create index for fast idempotency checks
CREATE INDEX IF NOT EXISTS idx_credit_transactions_idempotency
ON credit_transactions(idempotency_key)
WHERE idempotency_key IS NOT NULL;

-- =====================================================
-- STEP 5: Update get_credits() function
-- =====================================================

CREATE OR REPLACE FUNCTION get_credits(
    p_user_id UUID DEFAULT NULL,
    p_device_id TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_balance INTEGER;
    v_total INTEGER;
    v_granted BOOLEAN;
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
            'credits_total', 0
        );
    END IF;

    -- Get balance for authenticated users
    IF p_user_id IS NOT NULL THEN
        SELECT credits, credits_total, initial_grant_claimed
        INTO v_balance, v_total, v_granted
        FROM user_credits
        WHERE user_id = p_user_id;

        -- Create new user with initial grant
        IF NOT FOUND THEN
            INSERT INTO user_credits (
                user_id,
                credits,
                credits_total,
                initial_grant_claimed
            )
            VALUES (p_user_id, 10, 10, TRUE)
            RETURNING credits, credits_total, initial_grant_claimed
            INTO v_balance, v_total, v_granted;

            -- Log the initial grant
            INSERT INTO credit_transactions (
                user_id,
                amount,
                balance_after,
                reason,
                created_at
            )
            VALUES (
                p_user_id,
                10,
                10,
                'initial_grant',
                NOW()
            );

            RAISE LOG '[CREDITS] Initial grant: user % received 10 credits', p_user_id;
        END IF;

        RETURN jsonb_build_object(
            'success', TRUE,
            'credits_remaining', v_balance,
            'credits_total', v_total,
            'initial_grant_claimed', v_granted
        );

    -- Get balance for anonymous users
    ELSIF p_device_id IS NOT NULL THEN
        SELECT credits, credits_total, initial_grant_claimed
        INTO v_balance, v_total, v_granted
        FROM anonymous_credits
        WHERE device_id = p_device_id;

        -- Create new device with initial grant
        IF NOT FOUND THEN
            INSERT INTO anonymous_credits (
                device_id,
                credits,
                credits_total,
                initial_grant_claimed
            )
            VALUES (p_device_id, 10, 10, TRUE)
            RETURNING credits, credits_total, initial_grant_claimed
            INTO v_balance, v_total, v_granted;

            -- Log the initial grant
            INSERT INTO credit_transactions (
                device_id,
                amount,
                balance_after,
                reason,
                created_at
            )
            VALUES (
                p_device_id,
                10,
                10,
                'initial_grant',
                NOW()
            );

            RAISE LOG '[CREDITS] Initial grant: device % received 10 credits', p_device_id;
        END IF;

        RETURN jsonb_build_object(
            'success', TRUE,
            'credits_remaining', v_balance,
            'credits_total', v_total,
            'initial_grant_claimed', v_granted
        );
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_credits IS 'Gets credit balance and grants initial 10 credits to new users/devices (one-time only)';

-- =====================================================
-- STEP 6: Create add_credits() function
-- =====================================================

-- Drop all existing versions of add_credits function
-- Old signature: (p_user_id UUID, p_device_id TEXT, p_amount INTEGER, p_idempotency_key TEXT)
DROP FUNCTION IF EXISTS add_credits(UUID, TEXT, INTEGER, TEXT);
DROP FUNCTION IF EXISTS add_credits;

CREATE OR REPLACE FUNCTION add_credits(
    p_amount INTEGER,
    p_source TEXT,
    p_user_id UUID DEFAULT NULL,
    p_device_id TEXT DEFAULT NULL,
    p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_balance INTEGER;
    v_total INTEGER;
    v_result JSONB;
BEGIN
    -- Set device_id session for RLS
    IF p_device_id IS NOT NULL THEN
        PERFORM set_config('request.device_id', p_device_id, true);
    END IF;

    -- Validate inputs
    IF p_user_id IS NULL AND p_device_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Either user_id or device_id required'
        );
    END IF;

    IF p_amount <= 0 THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Amount must be positive'
        );
    END IF;

    -- ========================================
    -- IDEMPOTENCY CHECK
    -- ========================================
    IF p_idempotency_key IS NOT NULL THEN
        -- Check if already processed
        SELECT jsonb_build_object(
            'success', TRUE,
            'credits_remaining', balance_after,
            'duplicate', TRUE
        ) INTO v_result
        FROM credit_transactions
        WHERE idempotency_key = p_idempotency_key
        AND (
            (user_id IS NOT NULL AND user_id = p_user_id) OR
            (device_id IS NOT NULL AND device_id = p_device_id)
        )
        LIMIT 1;

        IF v_result IS NOT NULL THEN
            RAISE LOG '[CREDITS] Duplicate transaction detected: %', p_idempotency_key;
            RETURN v_result;
        END IF;
    END IF;

    -- ========================================
    -- ADD CREDITS (Authenticated Users)
    -- ========================================
    IF p_user_id IS NOT NULL THEN
        -- Lock row and add credits
        UPDATE user_credits
        SET
            credits = credits + p_amount,              -- Increase balance
            credits_total = credits_total + p_amount,  -- Increase lifetime total
            updated_at = NOW()
        WHERE user_id = p_user_id
        RETURNING credits, credits_total INTO v_balance, v_total;

        -- Create record if doesn't exist
        IF NOT FOUND THEN
            INSERT INTO user_credits (
                user_id,
                credits,
                credits_total,
                initial_grant_claimed
            )
            VALUES (
                p_user_id,
                p_amount,
                p_amount,
                FALSE  -- They haven't claimed their free 10 yet
            )
            RETURNING credits, credits_total INTO v_balance, v_total;
        END IF;

        -- Log transaction
        INSERT INTO credit_transactions (
            user_id,
            amount,
            balance_after,
            reason,
            idempotency_key,
            created_at
        ) VALUES (
            p_user_id,
            p_amount,
            v_balance,
            p_source,
            p_idempotency_key,
            NOW()
        );

        RAISE LOG '[CREDITS] Added % credits to user %. New balance: %, Total: %',
            p_amount, p_user_id, v_balance, v_total;

    -- ========================================
    -- ADD CREDITS (Anonymous Users)
    -- ========================================
    ELSIF p_device_id IS NOT NULL THEN
        -- Lock row and add credits
        UPDATE anonymous_credits
        SET
            credits = credits + p_amount,
            credits_total = credits_total + p_amount,
            updated_at = NOW()
        WHERE device_id = p_device_id
        RETURNING credits, credits_total INTO v_balance, v_total;

        -- Create record if doesn't exist
        IF NOT FOUND THEN
            INSERT INTO anonymous_credits (
                device_id,
                credits,
                credits_total,
                initial_grant_claimed
            )
            VALUES (
                p_device_id,
                p_amount,
                p_amount,
                FALSE  -- They haven't claimed their free 10 yet
            )
            RETURNING credits, credits_total INTO v_balance, v_total;
        END IF;

        -- Log transaction
        INSERT INTO credit_transactions (
            device_id,
            amount,
            balance_after,
            reason,
            idempotency_key,
            created_at
        ) VALUES (
            p_device_id,
            p_amount,
            v_balance,
            p_source,
            p_idempotency_key,
            NOW()
        );

        RAISE LOG '[CREDITS] Added % credits to device %. New balance: %, Total: %',
            p_amount, p_device_id, v_balance, v_total;
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'credits_remaining', v_balance,
        'credits_total', v_total,
        'duplicate', FALSE
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION add_credits IS 'Adds credits from purchases, promotions, or refunds. Updates both balance and lifetime total. Supports idempotency.';

-- =====================================================
-- Final verification
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Lifetime credit tracking added successfully';
    RAISE NOTICE '✅ Initial grant logic implemented';
    RAISE NOTICE '✅ Existing users migrated';
    RAISE NOTICE '✅ add_credits() function created';
END $$;
