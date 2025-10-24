-- Migration 025: Migrate existing users to new quota system
-- This migration moves data from the old user_credits and anonymous_credits tables
-- to the new daily_quotas table, preserving current quota state

-- ============================================
-- STEP 1: MIGRATE AUTHENTICATED USERS
-- ============================================

-- Migrate authenticated users from user_credits to daily_quotas
-- Use INSERT with WHERE NOT EXISTS to avoid conflicts
INSERT INTO daily_quotas (user_id, device_id, date, used, limit_value)
SELECT 
    uc.user_id,
    NULL as device_id,
    CURRENT_DATE as date,
    COALESCE(uc.daily_quota_used, 0) as used,
    COALESCE(uc.daily_quota_limit, 5) as limit_value
FROM user_credits uc
WHERE (uc.daily_quota_used > 0 OR uc.daily_quota_limit > 0)
AND NOT EXISTS (
    SELECT 1 FROM daily_quotas dq 
    WHERE dq.user_id = uc.user_id 
    AND dq.device_id IS NULL 
    AND dq.date = CURRENT_DATE
);

-- Log migration results for authenticated users
DO $$
DECLARE
    migrated_users INTEGER;
BEGIN
    SELECT COUNT(*) INTO migrated_users
    FROM daily_quotas dq
    WHERE dq.user_id IS NOT NULL 
    AND dq.date = CURRENT_DATE
    AND EXISTS (
        SELECT 1 FROM user_credits uc 
        WHERE uc.user_id = dq.user_id
    );
    
    RAISE LOG '[QUOTA-MIGRATION] Migrated % authenticated users to new quota system', migrated_users;
END $$;

-- ============================================
-- STEP 2: MIGRATE ANONYMOUS USERS
-- ============================================

-- Migrate anonymous users from anonymous_credits to daily_quotas
-- Use INSERT with WHERE NOT EXISTS to avoid conflicts
INSERT INTO daily_quotas (user_id, device_id, date, used, limit_value)
SELECT 
    NULL as user_id,
    ac.device_id,
    CURRENT_DATE as date,
    COALESCE(ac.daily_quota_used, 0) as used,
    COALESCE(ac.daily_quota_limit, 5) as limit_value
FROM anonymous_credits ac
WHERE (ac.daily_quota_used > 0 OR ac.daily_quota_limit > 0)
AND NOT EXISTS (
    SELECT 1 FROM daily_quotas dq 
    WHERE dq.user_id IS NULL 
    AND dq.device_id = ac.device_id 
    AND dq.date = CURRENT_DATE
);

-- Log migration results for anonymous users
DO $$
DECLARE
    migrated_anonymous INTEGER;
BEGIN
    SELECT COUNT(*) INTO migrated_anonymous
    FROM daily_quotas dq
    WHERE dq.device_id IS NOT NULL 
    AND dq.date = CURRENT_DATE
    AND EXISTS (
        SELECT 1 FROM anonymous_credits ac 
        WHERE ac.device_id = dq.device_id
    );
    
    RAISE LOG '[QUOTA-MIGRATION] Migrated % anonymous users to new quota system', migrated_anonymous;
END $$;

-- ============================================
-- STEP 3: VERIFICATION QUERIES
-- ============================================

-- Create a temporary view to compare old vs new systems
CREATE OR REPLACE VIEW migration_verification AS
SELECT 
    'user_credits' as source_table,
    COUNT(*) as total_records,
    SUM(COALESCE(daily_quota_used, 0)) as total_quota_used,
    SUM(COALESCE(daily_quota_limit, 5)) as total_quota_limit
FROM user_credits
WHERE daily_quota_used > 0 OR daily_quota_limit > 0

UNION ALL

SELECT 
    'anonymous_credits' as source_table,
    COUNT(*) as total_records,
    SUM(COALESCE(daily_quota_used, 0)) as total_quota_used,
    SUM(COALESCE(daily_quota_limit, 5)) as total_quota_limit
FROM anonymous_credits
WHERE daily_quota_used > 0 OR daily_quota_limit > 0

UNION ALL

SELECT 
    'daily_quotas' as source_table,
    COUNT(*) as total_records,
    SUM(COALESCE(used, 0)) as total_quota_used,
    SUM(COALESCE(limit_value, 5)) as total_quota_limit
FROM daily_quotas
WHERE date = CURRENT_DATE;

-- Log verification results
DO $$
DECLARE
    old_system_users INTEGER;
    old_system_anonymous INTEGER;
    new_system_total INTEGER;
    old_system_total INTEGER;
BEGIN
    -- Count old system records
    SELECT COUNT(*) INTO old_system_users FROM user_credits WHERE daily_quota_used > 0 OR daily_quota_limit > 0;
    SELECT COUNT(*) INTO old_system_anonymous FROM anonymous_credits WHERE daily_quota_used > 0 OR daily_quota_limit > 0;
    SELECT COUNT(*) INTO new_system_total FROM daily_quotas WHERE date = CURRENT_DATE;
    
    old_system_total := old_system_users + old_system_anonymous;
    
    RAISE LOG '[QUOTA-MIGRATION] Migration Summary:';
    RAISE LOG '[QUOTA-MIGRATION] - Old system: % authenticated + % anonymous = % total', old_system_users, old_system_anonymous, old_system_total;
    RAISE LOG '[QUOTA-MIGRATION] - New system: % total records', new_system_total;
    
    IF new_system_total >= old_system_total THEN
        RAISE LOG '[QUOTA-MIGRATION] ✅ Migration successful - all users migrated';
    ELSE
        RAISE LOG '[QUOTA-MIGRATION] ⚠️ Migration incomplete - some users may not have been migrated';
    END IF;
END $$;

-- ============================================
-- STEP 4: CLEANUP AND FINALIZATION
-- ============================================

-- Drop the temporary verification view
DROP VIEW IF EXISTS migration_verification;

-- Log completion
INSERT INTO cleanup_logs (operation, details, created_at)
VALUES ('quota_migration_complete', 
        jsonb_build_object(
            'migration_date', CURRENT_DATE,
            'migration_timestamp', NOW()
        ), 
        NOW());

-- Final completion log
DO $$
BEGIN
    RAISE LOG '[QUOTA-MIGRATION] ✅ Data migration to new quota system completed successfully';
END $$;
