-- =====================================================
-- Migration 059: Fix consume_quota ON CONFLICT Clause
-- Purpose: Update consume_quota to use expression-based ON CONFLICT
-- Date: 2025-11-13
-- =====================================================

-- =====================================================
-- PROBLEM: ON CONFLICT (user_id, device_id, date) doesn't match new index
-- =====================================================
-- Migration 058 created expression-based unique index:
--   idx_daily_quotas_unique_user_device_date
-- But consume_quota still uses column-based ON CONFLICT which doesn't work.

-- =====================================================
-- SOLUTION: Use DO UPDATE instead of DO NOTHING with WHERE clause
-- =====================================================

CREATE OR REPLACE FUNCTION consume_quota(
    p_user_id UUID DEFAULT NULL,
    p_device_id TEXT DEFAULT NULL,
    p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_today DATE;
    v_quota_record RECORD;
    v_result JSONB;
    v_identifier TEXT;
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
            'credits', 0,
            'quota_used', 0,
            'quota_limit', 3,
            'quota_remaining', 3,
            'is_premium', FALSE
        );
    END IF;

    -- Use UTC for quota date (consistent across timezones)
    v_today := (NOW() AT TIME ZONE 'UTC')::DATE;
    v_identifier := COALESCE(p_user_id::text, p_device_id);

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
            RAISE LOG '[QUOTA] Idempotent request: returning cached result for key=%', p_idempotency_key;
            RETURN v_result;
        END IF;
    END IF;

    -- ========================================
    -- STEP 2: GET OR CREATE QUOTA RECORD
    -- ========================================
    -- FIXED: Use INSERT ... ON CONFLICT ... DO UPDATE with WHERE FALSE
    -- This ensures the row exists without actually updating anything on conflict
    INSERT INTO daily_quotas (user_id, device_id, date, used, limit_value, is_premium)
    VALUES (p_user_id, p_device_id, v_today, 0, 3, FALSE)
    ON CONFLICT ON CONSTRAINT idx_daily_quotas_unique_user_device_date
    DO UPDATE SET used = daily_quotas.used WHERE FALSE;

    -- Lock row and get current quota state (FOR UPDATE prevents race conditions)
    SELECT * INTO v_quota_record
    FROM daily_quotas
    WHERE COALESCE(user_id::text, '') = COALESCE(p_user_id::text, '')
      AND COALESCE(device_id, '') = COALESCE(p_device_id, '')
      AND date = v_today
    FOR UPDATE;  -- ← CRITICAL: Row-level lock prevents concurrent modifications

    -- ========================================
    -- STEP 3: CHECK IF PREMIUM (bypass quota)
    -- ========================================
    IF v_quota_record.is_premium THEN
        -- Premium users: unlimited quota
        RAISE LOG '[QUOTA] Premium user % — quota bypassed', v_identifier;

        v_result := jsonb_build_object(
            'success', TRUE,
            'credits', 999999,
            'quota_used', 0,
            'quota_limit', 999999,
            'quota_remaining', 999999,
            'is_premium', TRUE
        );

        -- Cache idempotency result
        IF p_idempotency_key IS NOT NULL THEN
            INSERT INTO idempotency_keys (user_id, device_id, idempotency_key, response_status, response_body)
            VALUES (p_user_id, p_device_id, p_idempotency_key, 200, v_result)
            ON CONFLICT ON CONSTRAINT idx_idempotency_unique
            DO UPDATE SET response_body = v_result;
        END IF;

        RETURN v_result;
    END IF;

    -- ========================================
    -- STEP 4: CHECK QUOTA LIMIT (free users)
    -- ========================================
    IF v_quota_record.used >= v_quota_record.limit_value THEN
        RAISE LOG '[QUOTA] Limit exceeded: %/% for %', v_quota_record.used, v_quota_record.limit_value, v_identifier;

        v_result := jsonb_build_object(
            'success', FALSE,
            'error', 'Daily limit reached. Please try again tomorrow or upgrade to Premium.',
            'credits', 0,
            'quota_used', v_quota_record.used,
            'quota_limit', v_quota_record.limit_value,
            'quota_remaining', 0,
            'is_premium', FALSE
        );

        -- Cache idempotency result (even for failures)
        IF p_idempotency_key IS NOT NULL THEN
            INSERT INTO idempotency_keys (user_id, device_id, idempotency_key, response_status, response_body)
            VALUES (p_user_id, p_device_id, p_idempotency_key, 429, v_result)
            ON CONFLICT ON CONSTRAINT idx_idempotency_unique
            DO UPDATE SET response_body = v_result;
        END IF;

        RETURN v_result;
    END IF;

    -- ========================================
    -- STEP 5: ATOMICALLY CONSUME QUOTA
    -- ========================================
    UPDATE daily_quotas
    SET used = used + 1,
        updated_at = NOW()
    WHERE COALESCE(user_id::text, '') = COALESCE(p_user_id::text, '')
      AND COALESCE(device_id, '') = COALESCE(p_device_id, '')
      AND date = v_today
    RETURNING used, limit_value INTO v_quota_record.used, v_quota_record.limit_value;

    v_result := jsonb_build_object(
        'success', TRUE,
        'credits', v_quota_record.limit_value - v_quota_record.used,
        'quota_used', v_quota_record.used,
        'quota_limit', v_quota_record.limit_value,
        'quota_remaining', v_quota_record.limit_value - v_quota_record.used,
        'is_premium', FALSE
    );

    RAISE LOG '[QUOTA] Consumed: %/% used for %', v_quota_record.used, v_quota_record.limit_value, v_identifier;

    -- ========================================
    -- STEP 6: CACHE IDEMPOTENCY RESULT
    -- ========================================
    IF p_idempotency_key IS NOT NULL THEN
        INSERT INTO idempotency_keys (user_id, device_id, idempotency_key, response_status, response_body)
        VALUES (p_user_id, p_device_id, p_idempotency_key, 200, v_result)
        ON CONFLICT ON CONSTRAINT idx_idempotency_unique
        DO UPDATE SET response_body = v_result;
    END IF;

    RETURN v_result;

EXCEPTION
    WHEN OTHERS THEN
        RAISE LOG '[QUOTA] ERROR: %', SQLERRM;
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Database error: ' || SQLERRM,
            'credits', 0,
            'quota_used', 0,
            'quota_limit', 3,
            'quota_remaining', 3,
            'is_premium', FALSE
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- PERMISSIONS
-- =====================================================
ALTER FUNCTION consume_quota(UUID, TEXT, TEXT) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION consume_quota(UUID, TEXT, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION consume_quota(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION consume_quota(UUID, TEXT, TEXT) TO anon;

-- =====================================================
-- COMMENTS
-- =====================================================
COMMENT ON FUNCTION consume_quota(UUID, TEXT, TEXT) IS
'Consumes 1 quota unit atomically. Uses expression-based ON CONFLICT to handle NULL user_id values. Fixed in migration 059.';

-- =====================================================
-- VERIFICATION
-- =====================================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'consume_quota') THEN
        RAISE EXCEPTION 'consume_quota function not created';
    END IF;

    RAISE NOTICE 'SUCCESS: consume_quota function updated with fixed ON CONFLICT';
END $$;
