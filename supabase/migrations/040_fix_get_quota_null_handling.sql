-- =====================================================
-- Migration 040: Fix get_quota Null Handling
-- Purpose: Return proper defaults when no daily_quotas row exists
-- Fix: Handle null quota_limit for new users/devices
-- =====================================================

-- =====================================================
-- Fix get_quota Function
-- =====================================================
-- ISSUE: get_quota returns null quota_limit when no record exists
-- FIX: Always return valid defaults (0/5) for new users/devices
CREATE OR REPLACE FUNCTION get_quota(
    p_user_id UUID DEFAULT NULL,
    p_device_id TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_used INTEGER;
    v_limit INTEGER := 5;  -- Default free tier limit
    v_record_exists BOOLEAN := false;
BEGIN
    -- ✅ FIX: Handle case when no record exists
    -- Returns default values for users who haven't used quota today
    SELECT 
        COALESCE(used, 0) AS used,
        COALESCE(limit_value, 5) AS limit_value,
        TRUE AS exists
    INTO v_used, v_limit, v_record_exists
    FROM daily_quotas
    WHERE (user_id = p_user_id OR (user_id IS NULL AND p_user_id IS NULL))
    AND (device_id = p_device_id OR (device_id IS NULL AND p_device_id IS NULL))
    AND date = CURRENT_DATE
    LIMIT 1;
    
    -- ✅ FIX: Return proper defaults if no record found
    -- This is the expected state for users who haven't used quota today
    RETURN jsonb_build_object(
        'quota_used', COALESCE(v_used, 0),
        'quota_limit', COALESCE(v_limit, 5),
        'quota_remaining', 5 - COALESCE(v_used, 0),
        'is_premium', false  -- Note: get_quota doesn't check premium status (by design)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Ensure proper ownership and permissions
ALTER FUNCTION get_quota(UUID, TEXT) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION get_quota(UUID, TEXT) TO anon, authenticated, service_role;

-- =====================================================
-- Migration Complete
-- =====================================================
-- ✅ FIX #2 COMPLETE: get_quota() now returns valid defaults
-- Design: Always returns 0/5 for new users, actual values for existing
-- Testing: Call get_quota on fresh device → should return 0/5
-- Impact: Non-breaking, fixes null returns

