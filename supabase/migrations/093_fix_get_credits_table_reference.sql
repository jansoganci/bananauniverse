-- =====================================================
-- Migration 093: Fix get_credits to use user_credits
-- Purpose: Update get_credits() to query unified table after Migration 092
-- Date: 2025-11-21
-- Fixes: CRITICAL bug where get_credits returns stale data from old table
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE 'Starting get_credits table reference fix...';
END $$;

-- =====================================================
-- Recreate get_credits() with Correct Table Reference
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
    -- Validate input
    IF p_user_id IS NULL AND p_device_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Either user_id or device_id required'
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

    -- Get balance for device-based users
    ELSIF p_device_id IS NOT NULL THEN
        SELECT credits, credits_total, initial_grant_claimed
        INTO v_balance, v_total, v_granted
        FROM user_credits
        WHERE device_id = p_device_id;

        -- Create new device with initial grant
        IF NOT FOUND THEN
            INSERT INTO user_credits (
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

COMMENT ON FUNCTION get_credits IS 'Gets credit balance from user_credits table and grants initial 10 credits to new users/devices (one-time only)';

DO $$
BEGIN
    RAISE NOTICE '✅ get_credits() function updated';
END $$;

-- =====================================================
-- VERIFICATION
-- =====================================================

DO $$
DECLARE
    v_function_exists BOOLEAN;
    v_function_source TEXT;
    v_old_table_count INTEGER;
BEGIN
    -- Check if function exists
    SELECT EXISTS (
        SELECT 1 FROM pg_proc
        WHERE proname = 'get_credits'
    ) INTO v_function_exists;

    IF NOT v_function_exists THEN
        RAISE EXCEPTION 'VERIFICATION FAILED: get_credits function not found';
    END IF;

    -- Check if function references the correct table
    SELECT pg_get_functiondef(oid) INTO v_function_source
    FROM pg_proc
    WHERE proname = 'get_credits'
    LIMIT 1;

    -- Count references to old table (should be 0)
    SELECT (LENGTH(v_function_source) - LENGTH(REPLACE(v_function_source, 'anonymous_credits', ''))) / LENGTH('anonymous_credits')
    INTO v_old_table_count;

    IF v_old_table_count > 0 THEN
        RAISE EXCEPTION 'VERIFICATION FAILED: Function still references old table (found % references)', v_old_table_count;
    END IF;

    -- Verify new table is referenced
    IF v_function_source NOT LIKE '%user_credits%' THEN
        RAISE EXCEPTION 'VERIFICATION FAILED: Function does not reference user_credits';
    END IF;

    RAISE NOTICE '========================================';
    RAISE NOTICE 'Migration 093: Fix get_credits Table Reference';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ get_credits() now queries user_credits for device users';
    RAISE NOTICE '✅ get_credits() now inserts into user_credits for new devices';
    RAISE NOTICE '✅ No references to old table remain';
    RAISE NOTICE '✅ Fixes credit sync issue after Migration 092';
    RAISE NOTICE '========================================';
    RAISE NOTICE '🎉 SUCCESS: Critical bug fixed!';
    RAISE NOTICE '========================================';
END $$;
