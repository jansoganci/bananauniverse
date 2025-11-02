-- =====================================================
-- Migration 035: Update consume_quota Function
-- Purpose: Remove client-controlled premium flag
-- Security Fix: Check subscriptions table server-side
-- =====================================================

-- =====================================================
-- Consume Quota with Server-Side Premium Validation
-- =====================================================
-- CRITICAL CHANGE: Removed p_is_premium parameter
-- Now checks subscriptions table instead of trusting client
CREATE OR REPLACE FUNCTION consume_quota(
    p_user_id UUID DEFAULT NULL,
    p_device_id TEXT DEFAULT NULL,
    p_client_request_id UUID DEFAULT NULL
    -- ⚠️ REMOVED: p_is_premium BOOLEAN DEFAULT FALSE
)
RETURNS JSONB AS $$
DECLARE
    v_today DATE;
    v_used INTEGER;
    v_limit INTEGER := 5;  -- Free tier limit (hard-coded)
    v_is_premium BOOLEAN := false;
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
    -- STEP 1: IDEMPOTENCY CHECK
    -- ========================================
    IF p_client_request_id IS NOT NULL THEN
        SELECT
            jsonb_build_object(
                'success', success,
                'idempotent', true,
                'quota_used', quota_used,
                'quota_limit', quota_limit,
                'quota_remaining', quota_limit - quota_used
            )
        INTO v_existing_response
        FROM quota_consumption_log
        WHERE request_id = p_client_request_id;

        IF FOUND THEN
            RAISE LOG '[QUOTA] Returning cached response for request_id=%', p_client_request_id;
            RETURN v_existing_response;
        END IF;
    END IF;

    -- ========================================
    -- STEP 2: SERVER-SIDE PREMIUM CHECK 🔒
    -- ========================================
    -- CRITICAL: Check subscriptions table, NOT client flag!
    SELECT EXISTS(
        SELECT 1 FROM subscriptions
        WHERE (
            (p_user_id IS NOT NULL AND user_id = p_user_id)
            OR (p_device_id IS NOT NULL AND device_id = p_device_id)
        )
        AND status = 'active'
        AND expires_at > NOW()
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
            FOR UPDATE;  -- ← CRITICAL: Row lock prevents race conditions

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

-- =====================================================
-- Migration Complete
-- =====================================================
-- ✅ FIX #2 COMPLETE: consume_quota() now checks subscriptions table
-- ⚠️ BREAKING CHANGE: Clients must STOP sending p_is_premium
--
-- Next Step: Update Edge Function (FIX #3)
-- See: QUOTA_SYSTEM_IMPLEMENTATION_GUIDE.md
