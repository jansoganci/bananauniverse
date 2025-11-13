-- =====================================================
-- Migration 047: Update Quota Limit from 5 to 3
-- Purpose: Reduce daily quota limit for free tier users
-- Date: November 3, 2025
-- =====================================================

-- Update consume_quota function with new limit
CREATE OR REPLACE FUNCTION consume_quota(
    p_user_id UUID DEFAULT NULL,
    p_device_id TEXT DEFAULT NULL,
    p_client_request_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_today DATE;
    v_used INTEGER;
    v_limit INTEGER := 3;  -- Free tier limit (updated from 5 to 3)
    v_is_premium BOOLEAN := false;
    v_existing_success BOOLEAN;
    v_existing_refunded BOOLEAN;
    v_existing_response JSONB;
BEGIN
    -- Set device_id session for RLS
    IF p_device_id IS NOT NULL THEN
        PERFORM set_config('request.device_id', p_device_id, true);
    END IF;

    -- Validate inputs
    IF p_user_id IS NULL AND p_device_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Either user_id or device_id required',
            'quota_used', 0,
            'quota_limit', v_limit,
            'quota_remaining', 0
        );
    END IF;

    v_today := CURRENT_DATE;

    -- ========================================
    -- STEP 1: IDEMPOTENCY CHECK (FIXED)
    -- ========================================
    IF p_client_request_id IS NOT NULL THEN
        -- Check for existing request
        SELECT success, refunded
        INTO v_existing_success, v_existing_refunded
        FROM quota_consumption_log
        WHERE request_id = p_client_request_id;

        IF FOUND THEN
            IF v_existing_refunded = true THEN
                -- ✅ FIX: Refunded requests are retryable (quota was restored)
                DELETE FROM quota_consumption_log WHERE request_id = p_client_request_id;
                RAISE LOG '[QUOTA] Refunded request deleted, allowing retry: request_id=%', p_client_request_id;
                -- Continue to normal flow below

            ELSIF v_existing_success = true THEN
                -- ✅ Successful non-refunded request: return cached (idempotent)
                SELECT jsonb_build_object(
                    'success', success,
                    'idempotent', true,
                    'is_premium', (quota_limit > 100),
                    'quota_used', quota_used,
                    'quota_limit', quota_limit,
                    'quota_remaining', quota_limit - quota_used
                ) INTO v_existing_response
                FROM quota_consumption_log
                WHERE request_id = p_client_request_id;

                RAISE LOG '[QUOTA] Returning cached success response for request_id=%', p_client_request_id;
                RETURN v_existing_response;

            ELSE
                -- ✅ Failed non-refunded request: return cached failure (no retry without refund)
                SELECT jsonb_build_object(
                    'success', false,
                    'idempotent', true,
                    'error', error_message,
                    'quota_used', quota_used,
                    'quota_limit', quota_limit,
                    'quota_remaining', 0
                ) INTO v_existing_response
                FROM quota_consumption_log
                WHERE request_id = p_client_request_id;

                RAISE LOG '[QUOTA] Returning cached failure response for request_id=%', p_client_request_id;
                RETURN v_existing_response;
            END IF;
        END IF;
    END IF;

    -- ========================================
    -- STEP 2: SERVER-SIDE PREMIUM CHECK 🔒
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

    RAISE LOG '[QUOTA] Premium check: user_id=%, device_id=%, is_premium=%',
        p_user_id, p_device_id, v_is_premium;

    -- Premium users bypass quota
    IF v_is_premium THEN
        -- Log premium usage (for analytics)
        IF p_client_request_id IS NOT NULL THEN
            INSERT INTO quota_consumption_log (
                request_id, user_id, device_id, quota_used, quota_limit, success
            ) VALUES (
                p_client_request_id, p_user_id, p_device_id, 0, 999999, true
            ) ON CONFLICT (request_id) DO NOTHING;
        END IF;

        RETURN jsonb_build_object(
            'success', true,
            'idempotent', false,
            'is_premium', true,
            'quota_used', 0,
            'quota_limit', 999999,
            'quota_remaining', 999999,
            'premium_bypass', true
        );
    END IF;

    -- ========================================
    -- STEP 3: ROW LOCKING + QUOTA CHECK
    -- ========================================
    BEGIN
        -- Try to insert first (optimistic path for new day)
        INSERT INTO daily_quotas (user_id, device_id, date, used, limit_value)
        VALUES (p_user_id, p_device_id, v_today, 1, v_limit)
        RETURNING used, limit_value INTO v_used, v_limit;

        RAISE LOG '[QUOTA] New record created: used=%, limit=%', v_used, v_limit;

    EXCEPTION
        WHEN unique_violation THEN
            -- Record exists, acquire lock and update
            RAISE LOG '[QUOTA] Record exists, acquiring lock...';

            -- Acquire row lock with FOR UPDATE
            SELECT used, limit_value INTO v_used, v_limit
            FROM daily_quotas
            WHERE COALESCE(user_id::text, '') = COALESCE(p_user_id::text, '')
            AND COALESCE(device_id, '') = COALESCE(p_device_id, '')
            AND date = v_today
            FOR UPDATE;

            -- Check if quota available WHILE HOLDING LOCK
            IF v_used >= v_limit THEN
                -- Log exceeded attempt
                IF p_client_request_id IS NOT NULL THEN
                    INSERT INTO quota_consumption_log (
                        request_id, user_id, device_id, quota_used, quota_limit,
                        success, error_message
                    ) VALUES (
                        p_client_request_id, p_user_id, p_device_id, v_used, v_limit,
                        false, 'Daily quota exceeded'
                    ) ON CONFLICT (request_id) DO NOTHING;
                END IF;

                RETURN jsonb_build_object(
                    'success', false,
                    'error', 'Daily quota exceeded',
                    'quota_used', v_used,
                    'quota_limit', v_limit,
                    'quota_remaining', 0,
                    'is_premium', false
                );
            END IF;

            -- Atomically increment
            UPDATE daily_quotas
            SET used = used + 1, updated_at = NOW()
            WHERE COALESCE(user_id::text, '') = COALESCE(p_user_id::text, '')
            AND COALESCE(device_id, '') = COALESCE(p_device_id, '')
            AND date = v_today
            RETURNING used, limit_value INTO v_used, v_limit;

            RAISE LOG '[QUOTA] Updated: used=%, limit=%', v_used, v_limit;
    END;

    -- ========================================
    -- STEP 4: LOG CONSUMPTION
    -- ========================================
    IF p_client_request_id IS NOT NULL THEN
        INSERT INTO quota_consumption_log (
            request_id, user_id, device_id, quota_used, quota_limit, success
        ) VALUES (
            p_client_request_id, p_user_id, p_device_id, v_used, v_limit, true
        ) ON CONFLICT (request_id) DO NOTHING;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'idempotent', false,
        'is_premium', false,
        'quota_used', v_used,
        'quota_limit', v_limit,
        'quota_remaining', v_limit - v_used
    );

EXCEPTION
    WHEN OTHERS THEN
        RAISE LOG '[QUOTA] ERROR: %', SQLERRM;
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Database error: ' || SQLERRM,
            'quota_used', 0,
            'quota_limit', v_limit,
            'quota_remaining', 0
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Ensure proper ownership and permissions
ALTER FUNCTION consume_quota(UUID, TEXT, UUID) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION consume_quota(UUID, TEXT, UUID) TO anon, authenticated, service_role;

-- Update get_quota function with new limit
CREATE OR REPLACE FUNCTION get_quota(
    p_user_id UUID DEFAULT NULL,
    p_device_id TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_today DATE;
    v_used INTEGER;
    v_limit INTEGER;
    v_is_premium BOOLEAN := false;
BEGIN
    -- Set device_id session for RLS
    IF p_device_id IS NOT NULL THEN
        PERFORM set_config('request.device_id', p_device_id, true);
    END IF;

    -- Validate inputs
    IF p_user_id IS NULL AND p_device_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Either user_id or device_id required',
            'quota_used', 0,
            'quota_limit', 3,
            'quota_remaining', 0
        );
    END IF;

    v_today := CURRENT_DATE;

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

    -- Premium users get unlimited quota
    IF v_is_premium THEN
        RETURN jsonb_build_object(
            'success', true,
            'is_premium', true,
            'quota_used', 0,
            'quota_limit', 999999,
            'quota_remaining', 999999
        );
    END IF;

    -- Get or create daily quota record
    SELECT used, limit_value INTO v_used, v_limit
    FROM daily_quotas
    WHERE COALESCE(user_id::text, '') = COALESCE(p_user_id::text, '')
    AND COALESCE(device_id, '') = COALESCE(p_device_id, '')
    AND date = v_today;

    -- If no record exists, return default values
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', true,
            'is_premium', false,
            'quota_used', 0,
            'quota_limit', 3,
            'quota_remaining', 3
        );
    END IF;

    -- ✅ FIX: Use COALESCE consistently (updated from 5 to 3)
    RETURN jsonb_build_object(
        'success', true,
        'is_premium', false,
        'quota_used', COALESCE(v_used, 0),
        'quota_limit', COALESCE(v_limit, 3),
        'quota_remaining', GREATEST(COALESCE(v_limit, 3) - COALESCE(v_used, 0), 0)
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Database error: ' || SQLERRM,
            'quota_used', 0,
            'quota_limit', 3,
            'quota_remaining', 0
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Ensure proper ownership and permissions
ALTER FUNCTION get_quota(UUID, TEXT) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION get_quota(UUID, TEXT) TO anon, authenticated, service_role;

-- =====================================================
-- Migration Complete
-- =====================================================
-- ✅ Updated consume_quota: v_limit = 3 (was 5)
-- ✅ Updated get_quota: default quota_limit = 3 (was 5)
--
-- Impact:
--   - Free tier users now have 3 daily requests (down from 5)
--   - Premium users unaffected (still unlimited)
--   - Existing daily_quotas records will use stored limit_value
--   - New records will be created with limit=3
