-- Migration 028: Comprehensive RLS and Security Fix
-- This migration implements the advanced RLS security approach with proper role handling,
-- JWT token analysis, and comprehensive policy cleanup.

-- =====================================================
-- STEP 1: Role Security (Supabase Managed)
-- =====================================================

-- Note: In Supabase managed environment, postgres and service_role roles
-- already have BYPASSRLS privileges. We cannot alter these roles directly.
-- The SECURITY DEFINER functions will work correctly with existing role permissions.

-- =====================================================
-- STEP 2: Drop ALL existing conflicting RLS policies
-- =====================================================

-- Drop all policies on daily_quotas
DROP POLICY IF EXISTS "users_select_own_quota" ON daily_quotas;
DROP POLICY IF EXISTS "users_insert_own_quota" ON daily_quotas;
DROP POLICY IF EXISTS "users_update_own_quota" ON daily_quotas;
DROP POLICY IF EXISTS "anon_select_device_quota" ON daily_quotas;
DROP POLICY IF EXISTS "anon_insert_device_quota" ON daily_quotas;
DROP POLICY IF EXISTS "anon_update_device_quota" ON daily_quotas;
DROP POLICY IF EXISTS "admin_select_all_quota" ON daily_quotas;
DROP POLICY IF EXISTS "Allow quota inserts for anon/auth" ON daily_quotas;
DROP POLICY IF EXISTS "Allow quota updates for anon/auth" ON daily_quotas;
DROP POLICY IF EXISTS "Full access for service role" ON daily_quotas;
DROP POLICY IF EXISTS "daily_quotas_select_policy" ON daily_quotas;
DROP POLICY IF EXISTS "daily_quotas_insert_policy" ON daily_quotas;
DROP POLICY IF EXISTS "daily_quotas_update_policy" ON daily_quotas;
DROP POLICY IF EXISTS "service_role_full_access" ON daily_quotas;
DROP POLICY IF EXISTS "authenticated_read_own" ON daily_quotas;
DROP POLICY IF EXISTS "anonymous_read_device" ON daily_quotas;

-- Drop all policies on quota_consumption_log
DROP POLICY IF EXISTS "Allow quota logs for anon/auth" ON quota_consumption_log;
DROP POLICY IF EXISTS "Full access for service role (log)" ON quota_consumption_log;
DROP POLICY IF EXISTS "quota_log_select_policy" ON quota_consumption_log;
DROP POLICY IF EXISTS "quota_log_insert_policy" ON quota_consumption_log;
DROP POLICY IF EXISTS "quota_log_update_policy" ON quota_consumption_log;
DROP POLICY IF EXISTS "service_role_full_access_log" ON quota_consumption_log;
DROP POLICY IF EXISTS "authenticated_read_own_log" ON quota_consumption_log;
DROP POLICY IF EXISTS "anonymous_read_device_log" ON quota_consumption_log;

-- =====================================================
-- STEP 3: Create MINIMAL and SECURE RLS policies
-- =====================================================

-- DAILY_QUOTAS TABLE
-- -----------------

-- 1. Service role bypass (for SECURITY DEFINER functions)
DROP POLICY IF EXISTS "service_role_bypass" ON daily_quotas;
CREATE POLICY "service_role_bypass" ON daily_quotas
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- 2. Authenticated users: read own quota only
DROP POLICY IF EXISTS "auth_read_own_quota" ON daily_quotas;
CREATE POLICY "auth_read_own_quota" ON daily_quotas
    FOR SELECT
    TO authenticated
    USING (
        user_id IS NOT NULL 
        AND auth.uid() = user_id
        AND (auth.jwt() ->> 'is_anonymous')::boolean IS FALSE
    );

-- 3. Anonymous authenticated users: read own device quota only
DROP POLICY IF EXISTS "anon_auth_read_device_quota" ON daily_quotas;
CREATE POLICY "anon_auth_read_device_quota" ON daily_quotas
    FOR SELECT
    TO authenticated
    USING (
        device_id IS NOT NULL 
        AND (auth.jwt() ->> 'is_anonymous')::boolean IS TRUE
        AND device_id = current_setting('request.device_id', true)
    );

-- 4. Anon key users: read specific device quota only (with session variable)
DROP POLICY IF EXISTS "anon_read_device_quota" ON daily_quotas;
CREATE POLICY "anon_read_device_quota" ON daily_quotas
    FOR SELECT
    TO anon
    USING (
        device_id IS NOT NULL 
        AND device_id = current_setting('request.device_id', true)
    );

-- QUOTA_CONSUMPTION_LOG TABLE
-- ---------------------------

-- 1. Service role bypass (for SECURITY DEFINER functions)
DROP POLICY IF EXISTS "service_role_bypass_log" ON quota_consumption_log;
CREATE POLICY "service_role_bypass_log" ON quota_consumption_log
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- 2. Authenticated users: read own logs only
DROP POLICY IF EXISTS "auth_read_own_log" ON quota_consumption_log;
CREATE POLICY "auth_read_own_log" ON quota_consumption_log
    FOR SELECT
    TO authenticated
    USING (
        user_id IS NOT NULL 
        AND auth.uid() = user_id
        AND (auth.jwt() ->> 'is_anonymous')::boolean IS FALSE
    );

-- 3. Anonymous authenticated users: read own device logs only
DROP POLICY IF EXISTS "anon_auth_read_device_log" ON quota_consumption_log;
CREATE POLICY "anon_auth_read_device_log" ON quota_consumption_log
    FOR SELECT
    TO authenticated
    USING (
        device_id IS NOT NULL 
        AND (auth.jwt() ->> 'is_anonymous')::boolean IS TRUE
        AND device_id = current_setting('request.device_id', true)
    );

-- 4. Anon key users: read specific device logs only
DROP POLICY IF EXISTS "anon_read_device_log" ON quota_consumption_log;
CREATE POLICY "anon_read_device_log" ON quota_consumption_log
    FOR SELECT
    TO anon
    USING (
        device_id IS NOT NULL 
        AND device_id = current_setting('request.device_id', true)
    );

-- =====================================================
-- STEP 4: Ensure RLS is enabled
-- =====================================================

ALTER TABLE daily_quotas ENABLE ROW LEVEL SECURITY;
ALTER TABLE quota_consumption_log ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- STEP 5: Add helper function for setting device_id
-- =====================================================

-- This function should be called from Edge Functions before calling consume_quota
CREATE OR REPLACE FUNCTION set_device_id_session(p_device_id TEXT)
RETURNS void AS $$
BEGIN
    PERFORM set_config('request.device_id', p_device_id, true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION set_device_id_session(TEXT) TO anon, authenticated, service_role;

-- =====================================================
-- STEP 6: Update consume_quota to ensure role bypass
-- =====================================================

-- Recreate the function to ensure it runs with proper privileges
CREATE OR REPLACE FUNCTION consume_quota(
    p_user_id UUID DEFAULT NULL,
    p_device_id TEXT DEFAULT NULL,
    p_is_premium BOOLEAN DEFAULT FALSE,
    p_client_request_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_today DATE;
    v_used INTEGER;
    v_limit INTEGER;
    v_success BOOLEAN;
    v_error_message TEXT;
    v_record_id UUID;
BEGIN
    -- Set session variable for RLS if device_id provided
    IF p_device_id IS NOT NULL THEN
        PERFORM set_config('request.device_id', p_device_id, true);
    END IF;

    -- LOG: Function called
    RAISE LOG '[QUOTA] consume_quota() called: user_id=%, device_id=%, request_id=%, is_premium=%', 
        p_user_id, p_device_id, p_client_request_id, p_is_premium;
    
    -- Validate inputs
    IF p_user_id IS NULL AND p_device_id IS NULL THEN
        RAISE LOG '[QUOTA] ERROR: Missing user_id and device_id';
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Either user_id or device_id must be provided',
            'quota_used', 0,
            'quota_limit', 5,
            'quota_remaining', 0
        );
    END IF;
    
    v_today := CURRENT_DATE;
    
    -- IDEMPOTENCY CHECK
    IF p_client_request_id IS NOT NULL THEN
        SELECT COUNT(*) INTO v_used
        FROM quota_consumption_log
        WHERE request_id = p_client_request_id;
        
        IF v_used > 0 THEN
            RAISE LOG '[QUOTA] Idempotent request: request_id=% already processed', p_client_request_id;
            
            SELECT quota_used, quota_limit INTO v_used, v_limit
            FROM quota_consumption_log
            WHERE request_id = p_client_request_id
            LIMIT 1;
            
            RETURN jsonb_build_object(
                'success', true,
                'idempotent', true,
                'quota_used', v_used,
                'quota_limit', v_limit,
                'quota_remaining', v_limit - v_used
            );
        END IF;
    END IF;
    
    -- PREMIUM BYPASS
    IF p_is_premium THEN
        RAISE LOG '[QUOTA] Premium user detected - bypassing quota';
        
        IF p_client_request_id IS NOT NULL THEN
            INSERT INTO quota_consumption_log (
                request_id, user_id, device_id, consumed_at, 
                quota_used, quota_limit, success, error_message
            ) VALUES (
                p_client_request_id, p_user_id, p_device_id, NOW(),
                0, 999999, true, 'Premium bypass'
            );
        END IF;
        
        RETURN jsonb_build_object(
            'success', true,
            'quota_used', 0,
            'quota_limit', 999999,
            'quota_remaining', 999999,
            'premium_bypass', true
        );
    END IF;
    
    -- UPSERT with corrected WHERE clause
    BEGIN
        INSERT INTO daily_quotas (user_id, device_id, date, used, limit_value)
        VALUES (p_user_id, p_device_id, v_today, 1, 5)
        RETURNING used, limit_value, id INTO v_used, v_limit, v_record_id;
        
        RAISE LOG '[QUOTA] INSERTED new record: used=%, limit=%', v_used, v_limit;
        
    EXCEPTION
        WHEN unique_violation THEN
            RAISE LOG '[QUOTA] Record exists, updating...';
            
            -- FIXED: Proper WHERE clause matching unique index
            UPDATE daily_quotas
            SET 
                used = used + 1,
                updated_at = NOW()
            WHERE COALESCE(user_id::text, '') = COALESCE(p_user_id::text, '')
            AND COALESCE(device_id, '') = COALESCE(p_device_id, '')
            AND date = v_today
            AND used < limit_value
            RETURNING used, limit_value, id INTO v_used, v_limit, v_record_id;
            
            IF NOT FOUND THEN
                SELECT used, limit_value, id INTO v_used, v_limit, v_record_id
                FROM daily_quotas
                WHERE COALESCE(user_id::text, '') = COALESCE(p_user_id::text, '')
                AND COALESCE(device_id, '') = COALESCE(p_device_id, '')
                AND date = v_today;
            END IF;
            
            RAISE LOG '[QUOTA] UPDATED existing record: used=%, limit=%', v_used, v_limit;
    END;
    
    -- Check quota
    IF v_used > v_limit THEN
        v_success := false;
        v_error_message := 'Daily quota exceeded';
        RAISE LOG '[QUOTA] ERROR: Quota exceeded';
    ELSE
        v_success := true;
        v_error_message := NULL;
        RAISE LOG '[QUOTA] SUCCESS: Quota consumed';
    END IF;
    
    -- Log consumption
    IF p_client_request_id IS NOT NULL THEN
        INSERT INTO quota_consumption_log (
            request_id, user_id, device_id, consumed_at, 
            quota_used, quota_limit, success, error_message
        ) VALUES (
            p_client_request_id, p_user_id, p_device_id, NOW(),
            v_used, v_limit, v_success, v_error_message
        );
        
        RAISE LOG '[QUOTA] Logged consumption';
    END IF;
    
    RETURN jsonb_build_object(
        'success', v_success,
        'error', v_error_message,
        'quota_used', v_used,
        'quota_limit', v_limit,
        'quota_remaining', GREATEST(0, v_limit - v_used)
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE LOG '[QUOTA] EXCEPTION: %', SQLERRM;
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Database error: ' || SQLERRM,
            'quota_used', 0,
            'quota_limit', 5,
            'quota_remaining', 0
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Ensure proper role ownership
ALTER FUNCTION consume_quota(UUID, TEXT, BOOLEAN, UUID) OWNER TO postgres;

GRANT EXECUTE ON FUNCTION consume_quota(UUID, TEXT, BOOLEAN, UUID) TO anon, authenticated, service_role;

-- =====================================================
-- COMMENTS
-- =====================================================

COMMENT ON POLICY "auth_read_own_quota" ON daily_quotas IS 
'Permanent authenticated users can only read their own quota records';

COMMENT ON POLICY "anon_auth_read_device_quota" ON daily_quotas IS 
'Anonymous authenticated users can only read their device quota when request.device_id is set';

COMMENT ON POLICY "anon_read_device_quota" ON daily_quotas IS 
'Anon key users can only read specific device quota when request.device_id session variable matches';

COMMENT ON FUNCTION set_device_id_session(TEXT) IS 
'Helper function to set request.device_id session variable for RLS policies. Call this from Edge Functions before consume_quota.';
