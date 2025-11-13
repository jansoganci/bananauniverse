-- =====================================================
-- Migration 064: Create Credit Functions
-- Purpose: Implement persistent credit balance system
-- Date: 2025-11-13
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE 'Creating credit system functions...';
END $$;

-- =====================================================
-- FUNCTION 1: consume_credits()
-- =====================================================
-- Deducts credits from persistent balance
-- Works for both authenticated and anonymous users
-- Includes idempotency to prevent double-charging

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
        ELSE
            -- Atomically deduct credits
            UPDATE user_credits
            SET credits = credits - p_amount,
                updated_at = NOW()
            WHERE user_id = p_user_id
            RETURNING credits INTO v_balance;

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

            RAISE LOG '[CREDITS] Insufficient: device % has % credits, needs %', p_device_id, v_balance, p_amount;
        ELSE
            -- Atomically deduct credits
            UPDATE anonymous_credits
            SET credits = credits - p_amount,
                updated_at = NOW()
            WHERE device_id = p_device_id
            RETURNING credits INTO v_balance;

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
-- FUNCTION 2: add_credits()
-- =====================================================
-- Adds credits to persistent balance (refunds, purchases, etc.)
-- Works for both authenticated and anonymous users
-- Includes idempotency to prevent double-refunds

CREATE OR REPLACE FUNCTION add_credits(
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
        -- Ensure user record exists
        INSERT INTO user_credits (user_id, credits)
        VALUES (p_user_id, p_amount)
        ON CONFLICT (user_id)
        DO UPDATE SET
            credits = user_credits.credits + p_amount,
            updated_at = NOW()
        RETURNING credits INTO v_balance;

        v_result := jsonb_build_object(
            'success', TRUE,
            'credits_remaining', v_balance
        );

        RAISE LOG '[REFUND] Added % credits for user %, new balance: %', p_amount, p_user_id, v_balance;

    -- ========================================
    -- STEP 3: ADD CREDITS (Anonymous Users)
    -- ========================================
    ELSE
        -- Ensure device record exists
        INSERT INTO anonymous_credits (device_id, credits)
        VALUES (p_device_id, p_amount)
        ON CONFLICT (device_id)
        DO UPDATE SET
            credits = anonymous_credits.credits + p_amount,
            updated_at = NOW()
        RETURNING credits INTO v_balance;

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
-- FUNCTION 3: get_credits()
-- =====================================================
-- Reads current credit balance (read-only)
-- Works for both authenticated and anonymous users

CREATE OR REPLACE FUNCTION get_credits(
    p_user_id UUID DEFAULT NULL,
    p_device_id TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_balance INTEGER;
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

    -- Check premium status
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

    -- Premium users get unlimited
    IF v_is_premium THEN
        RETURN jsonb_build_object(
            'success', TRUE,
            'is_premium', TRUE,
            'credits_remaining', 999999
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

    -- Get balance for anonymous users
    ELSE
        SELECT COALESCE(credits, 0) INTO v_balance
        FROM anonymous_credits
        WHERE device_id = p_device_id;

        -- Create record if doesn't exist
        IF NOT FOUND THEN
            INSERT INTO anonymous_credits (device_id, credits)
            VALUES (p_device_id, 10)
            RETURNING credits INTO v_balance;
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'is_premium', FALSE,
        'credits_remaining', v_balance
    );

EXCEPTION
    WHEN OTHERS THEN
        RAISE LOG '[GET_CREDITS] ERROR: %', SQLERRM;
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Database error: ' || SQLERRM,
            'credits_remaining', 0,
            'is_premium', FALSE
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

ALTER FUNCTION get_credits(UUID, TEXT) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION get_credits(UUID, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION get_credits(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_credits(UUID, TEXT) TO anon;

-- =====================================================
-- COMMENTS
-- =====================================================

COMMENT ON FUNCTION consume_credits(UUID, TEXT, INTEGER, TEXT) IS
'Deducts credits from persistent balance. Uses idempotency to prevent double-charging. Premium users bypass.';

COMMENT ON FUNCTION add_credits(UUID, TEXT, INTEGER, TEXT) IS
'Adds credits to persistent balance (refunds, purchases). Uses idempotency to prevent double-refunds.';

COMMENT ON FUNCTION get_credits(UUID, TEXT) IS
'Reads current credit balance (read-only). Premium users get unlimited.';

-- =====================================================
-- VERIFICATION
-- =====================================================

DO $$
DECLARE
    v_consume_exists BOOLEAN;
    v_add_exists BOOLEAN;
    v_get_exists BOOLEAN;
BEGIN
    -- Check if functions exist
    SELECT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'consume_credits') INTO v_consume_exists;
    SELECT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'add_credits') INTO v_add_exists;
    SELECT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_credits') INTO v_get_exists;

    IF NOT v_consume_exists OR NOT v_add_exists OR NOT v_get_exists THEN
        RAISE EXCEPTION 'Credit functions not created successfully!';
    END IF;

    RAISE NOTICE '========================================';
    RAISE NOTICE 'Credit System Functions Created';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'consume_credits(): ✅ ACTIVE';
    RAISE NOTICE 'add_credits(): ✅ ACTIVE';
    RAISE NOTICE 'get_credits(): ✅ ACTIVE';
    RAISE NOTICE 'Idempotency: ✅ ENABLED';
    RAISE NOTICE 'Premium bypass: ✅ ENABLED';
    RAISE NOTICE 'Anonymous support: ✅ ENABLED';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ SUCCESS: Credit functions ready!';
END $$;

-- =====================================================
-- Migration Complete
-- =====================================================
-- ✅ consume_credits() created
-- ✅ add_credits() created
-- ✅ get_credits() created
-- ✅ Idempotency support added
-- ✅ Premium bypass implemented
-- ✅ Anonymous user support enabled
-- ✅ Permissions granted
--
-- Next: Update Edge Functions to use new credit functions
