-- =====================================================
-- Migration 048: Fix get_quota insert logic
-- Purpose: Ensure a new daily_quotas record is created if none exists
-- Date: November 4, 2025
-- =====================================================

DROP FUNCTION IF EXISTS get_quota(UUID, TEXT);

CREATE OR REPLACE FUNCTION get_quota(
    p_user_id UUID DEFAULT NULL,
    p_device_id TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_today DATE := CURRENT_DATE;
    v_used INTEGER := 0;
    v_limit INTEGER := 3;
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
            'quota_limit', v_limit,
            'quota_remaining', 0
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

    IF v_is_premium THEN
        RETURN jsonb_build_object(
            'success', true,
            'is_premium', true,
            'quota_used', 0,
            'quota_limit', 999999,
            'quota_remaining', 999999
        );
    END IF;

    -- Try to get today's record
    SELECT used, limit_value INTO v_used, v_limit
    FROM daily_quotas
    WHERE COALESCE(user_id::text, '') = COALESCE(p_user_id::text, '')
    AND COALESCE(device_id, '') = COALESCE(p_device_id, '')
    AND date = v_today;

    -- ✅ FIX: Create record if missing
    IF NOT FOUND THEN
        INSERT INTO daily_quotas (user_id, device_id, date, used, limit_value)
        VALUES (p_user_id, p_device_id, v_today, 0, v_limit)
        ON CONFLICT DO NOTHING;
        
        v_used := 0;
        v_limit := 3;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'is_premium', false,
        'quota_used', v_used,
        'quota_limit', v_limit,
        'quota_remaining', GREATEST(v_limit - v_used, 0)
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Database error: ' || SQLERRM,
            'quota_used', 0,
            'quota_limit', v_limit,
            'quota_remaining', 0
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

ALTER FUNCTION get_quota(UUID, TEXT) OWNER TO postgres;

GRANT EXECUTE ON FUNCTION get_quota(UUID, TEXT) TO anon, authenticated, service_role;

-- =====================================================
-- Migration Complete
-- =====================================================

