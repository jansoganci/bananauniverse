-- =====================================================
-- Migration 066: Remove Premium Checks from Credit Functions
-- Purpose: Remove subscription/premium bypass logic from credit system
-- Date: 2025-11-14
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE 'Removing premium checks from credit functions...';
END $$;

-- =====================================================
-- UPDATE: consume_credits()
-- Remove premium status check and bypass logic
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
    -- STEP 2: CONSUME CREDITS (Authenticated Users)
    -- ========================================
    IF p_user_id IS NOT NULL THEN
        -- Lock row and get current balance
        SELECT credits INTO v_balance
        FROM user_credits
        WHERE user_id = p_user_id
        FOR UPDATE;

        -- Create record if doesn't exist
        IF NOT FOUND THEN
            INSERT INTO user_credits (user_id, credits)
            VALUES (p_user_id, 10)
            RETURNING credits INTO v_balance;
        END IF;

        -- Check if sufficient balance
        IF v_balance < p_amount THEN
            v_result := jsonb_build_object(
                'success', FALSE,
                'error', 'Insufficient credits',
                'credits_remaining', v_balance,
                'is_premium', FALSE
            );

            RAISE LOG '[CREDITS] Insufficient: user has % credits, needs %', v_balance, p_amount;

            -- Cache idempotency result
            IF p_idempotency_key IS NOT NULL THEN
                INSERT INTO idempotency_keys (user_id, device_id, idempotency_key, response_status, response_body)
                VALUES (p_user_id, p_device_id, p_idempotency_key, 402, v_result)
                ON CONFLICT (COALESCE(user_id::text, ''), COALESCE(device_id, ''), idempotency_key)
                DO UPDATE SET response_body = v_result;
            END IF;

            RETURN v_result;
        END IF;

        -- Deduct credits
        UPDATE user_credits
        SET credits = credits - p_amount
        WHERE user_id = p_user_id
        RETURNING credits INTO v_balance;

        v_result := jsonb_build_object(
            'success', TRUE,
            'credits_remaining', v_balance,
            'is_premium', FALSE
        );

        RAISE LOG '[CREDITS] Deducted % credits from user %. Remaining: %', p_amount, p_user_id, v_balance;

    -- ========================================
    -- STEP 3: CONSUME CREDITS (Anonymous Users)
    -- ========================================
    ELSIF p_device_id IS NOT NULL THEN
        -- Lock row and get current balance
        SELECT credits INTO v_balance
        FROM anonymous_credits
        WHERE device_id = p_device_id
        FOR UPDATE;

        -- Create record if doesn't exist
        IF NOT FOUND THEN
            INSERT INTO anonymous_credits (device_id, credits)
            VALUES (p_device_id, 10)
            RETURNING credits INTO v_balance;
        END IF;

        -- Check if sufficient balance
        IF v_balance < p_amount THEN
            v_result := jsonb_build_object(
                'success', FALSE,
                'error', 'Insufficient credits',
                'credits_remaining', v_balance,
                'is_premium', FALSE
            );

            RAISE LOG '[CREDITS] Insufficient: device has % credits, needs %', v_balance, p_amount;

            -- Cache idempotency result
            IF p_idempotency_key IS NOT NULL THEN
                INSERT INTO idempotency_keys (user_id, device_id, idempotency_key, response_status, response_body)
                VALUES (p_user_id, p_device_id, p_idempotency_key, 402, v_result)
                ON CONFLICT (COALESCE(user_id::text, ''), COALESCE(device_id, ''), idempotency_key)
                DO UPDATE SET response_body = v_result;
            END IF;

            RETURN v_result;
        END IF;

        -- Deduct credits
        UPDATE anonymous_credits
        SET credits = credits - p_amount
        WHERE device_id = p_device_id
        RETURNING credits INTO v_balance;

        v_result := jsonb_build_object(
            'success', TRUE,
            'credits_remaining', v_balance,
            'is_premium', FALSE
        );

        RAISE LOG '[CREDITS] Deducted % credits from device %. Remaining: %', p_amount, p_device_id, v_balance;
    END IF;

    -- Cache idempotency result
    IF p_idempotency_key IS NOT NULL THEN
        INSERT INTO idempotency_keys (user_id, device_id, idempotency_key, response_status, response_body)
        VALUES (p_user_id, p_device_id, p_idempotency_key, 200, v_result)
        ON CONFLICT (COALESCE(user_id::text, ''), COALESCE(device_id, ''), idempotency_key)
        DO UPDATE SET response_body = v_result;
    END IF;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- UPDATE: get_credits()
-- Remove premium status check and bypass logic
-- =====================================================

CREATE OR REPLACE FUNCTION get_credits(
    p_user_id UUID DEFAULT NULL,
    p_device_id TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_balance INTEGER;
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

    -- Get balance for authenticated users
    IF p_user_id IS NOT NULL THEN
        SELECT COALESCE(credits, 0) INTO v_balance
        FROM user_credits
        WHERE user_id = p_user_id;

        -- Create record if doesn't exist
        IF NOT FOUND THEN
            INSERT INTO user_credits (user_id, credits)
            VALUES (p_user_id, 10)
            RETURNING credits INTO v_balance;
        END IF;

        RETURN jsonb_build_object(
            'success', TRUE,
            'is_premium', FALSE,
            'credits_remaining', v_balance
        );

    -- Get balance for anonymous users
    ELSIF p_device_id IS NOT NULL THEN
        SELECT COALESCE(credits, 0) INTO v_balance
        FROM anonymous_credits
        WHERE device_id = p_device_id;

        -- Create record if doesn't exist
        IF NOT FOUND THEN
            INSERT INTO anonymous_credits (device_id, credits)
            VALUES (p_device_id, 10)
            RETURNING credits INTO v_balance;
        END IF;

        RETURN jsonb_build_object(
            'success', TRUE,
            'is_premium', FALSE,
            'credits_remaining', v_balance
        );
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update function comments
COMMENT ON FUNCTION consume_credits IS 'Deducts credits from persistent balance. Uses idempotency to prevent double-charging. All users consume credits.';
COMMENT ON FUNCTION get_credits IS 'Reads current credit balance (read-only). Returns credit balance for all users.';

-- Final verification
DO $$
BEGIN
    RAISE NOTICE '✅ Premium checks removed from credit functions';
END $$;

