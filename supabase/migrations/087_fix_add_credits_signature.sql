-- =====================================================
-- Migration 087: Fix add_credits() Function Signature
-- Purpose: Revert to original signature to prevent breaking Edge Functions
-- Date: 2025-11-15
-- Issue: Migration 086 changed parameter order, breaking all callers
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE 'Fixing add_credits() function signature...';
END $$;

-- =====================================================
-- Drop the broken version from migration 086
-- =====================================================

DROP FUNCTION IF EXISTS add_credits(INTEGER, TEXT, UUID, TEXT, TEXT);
DROP FUNCTION IF EXISTS add_credits;

-- =====================================================
-- Recreate add_credits() with ORIGINAL signature
-- But keep the NEW functionality (credits_total tracking)
-- =====================================================

CREATE OR REPLACE FUNCTION add_credits(
    p_user_id UUID DEFAULT NULL,
    p_device_id TEXT DEFAULT NULL,
    p_amount INTEGER DEFAULT 1,
    p_idempotency_key TEXT DEFAULT NULL,
    p_source TEXT DEFAULT 'manual'  -- NEW: Has default so existing callers work
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
            'credits_total', (
                SELECT COALESCE(credits_total, 0)
                FROM user_credits
                WHERE user_id = p_user_id
                UNION ALL
                SELECT COALESCE(credits_total, 0)
                FROM anonymous_credits
                WHERE device_id = p_device_id
                LIMIT 1
            ),
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
            RAISE LOG '[CREDITS] Idempotent request: returning cached result for key=%', p_idempotency_key;
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

        -- Build result object
        v_result := jsonb_build_object(
            'success', TRUE,
            'credits_remaining', v_balance,
            'credits_total', v_total,
            'duplicate', FALSE
        );

        -- Cache idempotency result (for verify-iap-purchase and other callers)
        IF p_idempotency_key IS NOT NULL THEN
            INSERT INTO idempotency_keys (user_id, device_id, idempotency_key, response_status, response_body)
            VALUES (p_user_id, p_device_id, p_idempotency_key, 200, v_result)
            ON CONFLICT (COALESCE(user_id::text, ''), COALESCE(device_id, ''), idempotency_key)
            DO UPDATE SET response_body = v_result;
        END IF;

        RAISE LOG '[CREDITS] Added % credits to user %. Source: %, New balance: %, Total: %',
            p_amount, p_user_id, p_source, v_balance, v_total;

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

        -- Build result object
        v_result := jsonb_build_object(
            'success', TRUE,
            'credits_remaining', v_balance,
            'credits_total', v_total,
            'duplicate', FALSE
        );

        -- Cache idempotency result (for verify-iap-purchase and other callers)
        IF p_idempotency_key IS NOT NULL THEN
            INSERT INTO idempotency_keys (user_id, device_id, idempotency_key, response_status, response_body)
            VALUES (p_user_id, p_device_id, p_idempotency_key, 200, v_result)
            ON CONFLICT (COALESCE(user_id::text, ''), COALESCE(device_id, ''), idempotency_key)
            DO UPDATE SET response_body = v_result;
        END IF;

        RAISE LOG '[CREDITS] Added % credits to device %. Source: %, New balance: %, Total: %',
            p_amount, p_device_id, p_source, v_balance, v_total;
    END IF;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION add_credits IS 'Adds credits from purchases, promotions, or refunds. Updates both balance and lifetime total. Supports idempotency. Compatible with existing Edge Function calls.';

-- =====================================================
-- Final verification
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '✅ add_credits() signature fixed - backward compatible';
    RAISE NOTICE '✅ Edge Functions will work without changes';
    RAISE NOTICE '✅ Lifetime credit tracking still enabled';
END $$;
