-- =====================================================
-- Migration 061: Fix add_credits to Use Index Instead of Constraint
-- Purpose: Fix ON CONFLICT to use expression-based syntax
-- Date: 2025-11-13
-- =====================================================

CREATE OR REPLACE FUNCTION add_credits(
    p_user_id UUID DEFAULT NULL,
    p_device_id TEXT DEFAULT NULL,
    p_credits INTEGER DEFAULT 1,
    p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_today DATE;
    v_quota_record RECORD;
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
            'credits', 0
        );
    END IF;

    -- Validate credits is positive
    IF p_credits <= 0 THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Credits must be positive',
            'credits', 0
        );
    END IF;

    -- Use UTC for quota date (consistent with consume_quota)
    v_today := (NOW() AT TIME ZONE 'UTC')::DATE;

    -- ========================================
    -- STEP 1: IDEMPOTENCY CHECK (Return cached result)
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
    -- STEP 2: GET OR CREATE QUOTA RECORD
    -- ========================================
    -- Ensure quota record exists for today
    INSERT INTO daily_quotas (user_id, device_id, date, used, limit_value, is_premium)
    VALUES (p_user_id, p_device_id, v_today, 0, 3, FALSE)
    ON CONFLICT (COALESCE(user_id::text, ''), COALESCE(device_id, ''), date)
    DO NOTHING;

    -- Lock row and get current quota state (FOR UPDATE prevents race conditions)
    SELECT * INTO v_quota_record
    FROM daily_quotas
    WHERE COALESCE(user_id::text, '') = COALESCE(p_user_id::text, '')
      AND COALESCE(device_id, '') = COALESCE(p_device_id, '')
      AND date = v_today
    FOR UPDATE;  -- ← CRITICAL: Row-level lock prevents concurrent modifications

    -- ========================================
    -- STEP 3: ATOMICALLY REFUND CREDITS
    -- ========================================
    -- Decrease 'used' by p_credits, but never go below 0
    UPDATE daily_quotas
    SET used = GREATEST(0, used - p_credits),  -- Floor at 0
        updated_at = NOW()
    WHERE COALESCE(user_id::text, '') = COALESCE(p_user_id::text, '')
      AND COALESCE(device_id, '') = COALESCE(p_device_id, '')
      AND date = v_today
    RETURNING used, limit_value INTO v_quota_record.used, v_quota_record.limit_value;

    v_result := jsonb_build_object(
        'success', TRUE,
        'credits', p_credits,
        'quota_used', v_quota_record.used,
        'quota_limit', v_quota_record.limit_value,
        'quota_remaining', v_quota_record.limit_value - v_quota_record.used
    );

    RAISE LOG '[REFUND] Refunded % credits: %/% used', p_credits, v_quota_record.used, v_quota_record.limit_value;

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
            'credits', 0
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- PERMISSIONS
-- =====================================================
ALTER FUNCTION add_credits(UUID, TEXT, INTEGER, TEXT) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION add_credits(UUID, TEXT, INTEGER, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION add_credits(UUID, TEXT, INTEGER, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION add_credits(UUID, TEXT, INTEGER, TEXT) TO anon;

-- =====================================================
-- COMMENTS
-- =====================================================
COMMENT ON FUNCTION add_credits(UUID, TEXT, INTEGER, TEXT) IS
'Refunds credits to user by decreasing daily_quotas.used value. Uses expression-based ON CONFLICT. Fixed in migration 061.';

-- =====================================================
-- VERIFICATION
-- =====================================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'add_credits') THEN
        RAISE EXCEPTION 'add_credits function not created';
    END IF;

    RAISE NOTICE 'SUCCESS: add_credits() function updated with correct ON CONFLICT syntax';
END $$;
