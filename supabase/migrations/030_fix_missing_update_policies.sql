-- Migration 030: Fix Missing UPDATE Policies for daily_quotas
-- The consume_quota function can INSERT but cannot UPDATE due to missing RLS policies

-- Add UPDATE policies for daily_quotas table
-- 1. Service role can update (for SECURITY DEFINER functions)
DROP POLICY IF EXISTS "service_role_update_quota" ON daily_quotas;
CREATE POLICY "service_role_update_quota" ON daily_quotas
    FOR UPDATE
    TO service_role
    USING (true)
    WITH CHECK (true);

-- 2. Authenticated users can update their own quota
DROP POLICY IF EXISTS "auth_update_own_quota" ON daily_quotas;
CREATE POLICY "auth_update_own_quota" ON daily_quotas
    FOR UPDATE
    TO authenticated
    USING (
        user_id IS NOT NULL 
        AND auth.uid() = user_id
        AND (auth.jwt() ->> 'is_anonymous')::boolean IS FALSE
    )
    WITH CHECK (
        user_id IS NOT NULL 
        AND auth.uid() = user_id
        AND (auth.jwt() ->> 'is_anonymous')::boolean IS FALSE
    );

-- 3. Anonymous authenticated users can update their device quota
DROP POLICY IF EXISTS "anon_auth_update_device_quota" ON daily_quotas;
CREATE POLICY "anon_auth_update_device_quota" ON daily_quotas
    FOR UPDATE
    TO authenticated
    USING (
        device_id IS NOT NULL 
        AND (auth.jwt() ->> 'is_anonymous')::boolean IS TRUE
        AND device_id = current_setting('request.device_id', true)
    )
    WITH CHECK (
        device_id IS NOT NULL 
        AND (auth.jwt() ->> 'is_anonymous')::boolean IS TRUE
        AND device_id = current_setting('request.device_id', true)
    );

-- 4. Anon key users can update their device quota
DROP POLICY IF EXISTS "anon_update_device_quota" ON daily_quotas;
CREATE POLICY "anon_update_device_quota" ON daily_quotas
    FOR UPDATE
    TO anon
    USING (
        device_id IS NOT NULL 
        AND device_id = current_setting('request.device_id', true)
    )
    WITH CHECK (
        device_id IS NOT NULL 
        AND device_id = current_setting('request.device_id', true)
    );

-- Add INSERT policies for daily_quotas table (if missing)
-- 1. Service role can insert (for SECURITY DEFINER functions)
DROP POLICY IF EXISTS "service_role_insert_quota" ON daily_quotas;
CREATE POLICY "service_role_insert_quota" ON daily_quotas
    FOR INSERT
    TO service_role
    WITH CHECK (true);

-- 2. Authenticated users can insert their own quota
DROP POLICY IF EXISTS "auth_insert_own_quota" ON daily_quotas;
CREATE POLICY "auth_insert_own_quota" ON daily_quotas
    FOR INSERT
    TO authenticated
    WITH CHECK (
        user_id IS NOT NULL 
        AND auth.uid() = user_id
        AND (auth.jwt() ->> 'is_anonymous')::boolean IS FALSE
    );

-- 3. Anonymous authenticated users can insert their device quota
DROP POLICY IF EXISTS "anon_auth_insert_device_quota" ON daily_quotas;
CREATE POLICY "anon_auth_insert_device_quota" ON daily_quotas
    FOR INSERT
    TO authenticated
    WITH CHECK (
        device_id IS NOT NULL 
        AND (auth.jwt() ->> 'is_anonymous')::boolean IS TRUE
        AND device_id = current_setting('request.device_id', true)
    );

-- 4. Anon key users can insert their device quota
DROP POLICY IF EXISTS "anon_insert_device_quota" ON daily_quotas;
CREATE POLICY "anon_insert_device_quota" ON daily_quotas
    FOR INSERT
    TO anon
    WITH CHECK (
        device_id IS NOT NULL 
        AND device_id = current_setting('request.device_id', true)
    );

-- Add similar policies for quota_consumption_log table
-- 1. Service role can insert/update logs
DROP POLICY IF EXISTS "service_role_insert_log" ON quota_consumption_log;
CREATE POLICY "service_role_insert_log" ON quota_consumption_log
    FOR INSERT
    TO service_role
    WITH CHECK (true);

DROP POLICY IF EXISTS "service_role_update_log" ON quota_consumption_log;
CREATE POLICY "service_role_update_log" ON quota_consumption_log
    FOR UPDATE
    TO service_role
    USING (true)
    WITH CHECK (true);

-- 2. Authenticated users can insert their own logs
DROP POLICY IF EXISTS "auth_insert_own_log" ON quota_consumption_log;
CREATE POLICY "auth_insert_own_log" ON quota_consumption_log
    FOR INSERT
    TO authenticated
    WITH CHECK (
        user_id IS NOT NULL 
        AND auth.uid() = user_id
        AND (auth.jwt() ->> 'is_anonymous')::boolean IS FALSE
    );

-- 3. Anonymous authenticated users can insert their device logs
DROP POLICY IF EXISTS "anon_auth_insert_device_log" ON quota_consumption_log;
CREATE POLICY "anon_auth_insert_device_log" ON quota_consumption_log
    FOR INSERT
    TO authenticated
    WITH CHECK (
        device_id IS NOT NULL 
        AND (auth.jwt() ->> 'is_anonymous')::boolean IS TRUE
        AND device_id = current_setting('request.device_id', true)
    );

-- 4. Anon key users can insert their device logs
DROP POLICY IF EXISTS "anon_insert_device_log" ON quota_consumption_log;
CREATE POLICY "anon_insert_device_log" ON quota_consumption_log
    FOR INSERT
    TO anon
    WITH CHECK (
        device_id IS NOT NULL 
        AND device_id = current_setting('request.device_id', true)
    );

-- Comments
COMMENT ON POLICY "service_role_update_quota" ON daily_quotas IS 'Service role can update any quota record (for SECURITY DEFINER functions)';
COMMENT ON POLICY "auth_update_own_quota" ON daily_quotas IS 'Authenticated users can update their own quota records';
COMMENT ON POLICY "anon_auth_update_device_quota" ON daily_quotas IS 'Anonymous authenticated users can update their device quota when request.device_id is set';
COMMENT ON POLICY "anon_update_device_quota" ON daily_quotas IS 'Anon key users can update specific device quota when request.device_id session variable matches';
COMMENT ON POLICY "service_role_insert_quota" ON daily_quotas IS 'Service role can insert any quota record (for SECURITY DEFINER functions)';
COMMENT ON POLICY "auth_insert_own_quota" ON daily_quotas IS 'Authenticated users can insert their own quota records';
COMMENT ON POLICY "anon_auth_insert_device_quota" ON daily_quotas IS 'Anonymous authenticated users can insert their device quota when request.device_id is set';
COMMENT ON POLICY "anon_insert_device_quota" ON daily_quotas IS 'Anon key users can insert specific device quota when request.device_id session variable matches';
