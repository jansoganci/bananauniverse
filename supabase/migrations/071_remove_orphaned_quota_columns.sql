-- =====================================================
-- Migration 071: Remove Orphaned Quota Columns
-- Purpose: Remove unused daily_quota_limit, daily_quota_used, and last_quota_reset columns
-- Date: 2025-11-14
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE 'Removing orphaned quota columns from credit tables...';
END $$;

-- =====================================================
-- STEP 1: Drop views that depend on quota columns
-- =====================================================

-- Drop admin views that reference quota columns
DROP VIEW IF EXISTS admin_user_credit_summary CASCADE;
DROP VIEW IF EXISTS admin_anonymous_credit_summary CASCADE;
DROP VIEW IF EXISTS admin_quota_usage_analysis CASCADE;
DROP VIEW IF EXISTS admin_user_type_comparison CASCADE;
DROP VIEW IF EXISTS admin_system_health CASCADE;

-- =====================================================
-- STEP 2: Drop indexes that reference quota columns
-- =====================================================

-- Drop quota-related indexes from user_credits
DROP INDEX IF EXISTS idx_user_credits_quota_reset;
DROP INDEX IF EXISTS idx_user_credits_quota_validation;

-- Drop quota-related indexes from anonymous_credits
DROP INDEX IF EXISTS idx_anonymous_credits_quota_reset;
DROP INDEX IF EXISTS idx_anonymous_credits_quota_validation;

-- =====================================================
-- STEP 3: Remove quota columns from user_credits table
-- =====================================================

ALTER TABLE user_credits 
DROP COLUMN IF EXISTS daily_quota_used,
DROP COLUMN IF EXISTS daily_quota_limit,
DROP COLUMN IF EXISTS last_quota_reset;

-- =====================================================
-- STEP 4: Remove quota columns from anonymous_credits table
-- =====================================================

ALTER TABLE anonymous_credits 
DROP COLUMN IF EXISTS daily_quota_used,
DROP COLUMN IF EXISTS daily_quota_limit,
DROP COLUMN IF EXISTS last_quota_reset;

-- =====================================================
-- STEP 5: Recreate views without quota columns
-- =====================================================

-- Recreate admin_user_credit_summary without quota columns
CREATE VIEW admin_user_credit_summary AS
SELECT 
    uc.user_id,
    p.email,
    p.subscription_tier,
    uc.credits as current_credits,
    uc.created_at as credits_created_at,
    uc.updated_at as credits_updated_at,
    COUNT(ct.id) as total_transactions,
    SUM(CASE WHEN ct.amount > 0 THEN ct.amount ELSE 0 END) as lifetime_credits_added,
    SUM(CASE WHEN ct.amount < 0 THEN ABS(ct.amount) ELSE 0 END) as lifetime_credits_spent
FROM user_credits uc
LEFT JOIN profiles p ON uc.user_id = p.id
LEFT JOIN credit_transactions ct ON uc.user_id = ct.user_id
GROUP BY uc.user_id, p.email, p.subscription_tier, uc.credits, uc.created_at, uc.updated_at
ORDER BY uc.created_at DESC;

GRANT SELECT ON admin_user_credit_summary TO authenticated;
COMMENT ON VIEW admin_user_credit_summary IS 'User credit summary for admin analytics (quota columns removed)';

-- Recreate admin_anonymous_credit_summary without quota columns
CREATE VIEW admin_anonymous_credit_summary AS
SELECT 
    device_id,
    credits as current_credits,
    created_at,
    updated_at,
    EXTRACT(EPOCH FROM (NOW() - created_at))/86400 as days_since_created
FROM anonymous_credits
ORDER BY created_at DESC;

GRANT SELECT ON admin_anonymous_credit_summary TO authenticated;
COMMENT ON VIEW admin_anonymous_credit_summary IS 'Anonymous credits summary for admin analytics (quota columns removed)';

-- Recreate admin_user_type_comparison without quota columns
CREATE OR REPLACE VIEW admin_user_type_comparison AS
SELECT 
    'authenticated' as user_type,
    COUNT(*) as user_count,
    SUM(credits) as total_credits,
    ROUND(AVG(credits), 2) as avg_credits_per_user
FROM user_credits
UNION ALL
SELECT 
    'anonymous' as user_type,
    COUNT(*) as user_count,
    SUM(credits) as total_credits,
    ROUND(AVG(credits), 2) as avg_credits_per_user
FROM anonymous_credits;

GRANT SELECT ON admin_user_type_comparison TO authenticated;
COMMENT ON VIEW admin_user_type_comparison IS 'Comparison between authenticated and anonymous users (quota columns removed)';

-- Recreate admin_system_health without quota utilization metric
CREATE OR REPLACE VIEW admin_system_health AS
SELECT 
    'Total Users' as metric,
    COUNT(*)::text as value,
    'users' as unit
FROM profiles
UNION ALL
SELECT 
    'Active Users (Last 7 Days)' as metric,
    COUNT(DISTINCT user_id)::text as value,
    'users' as unit
FROM credit_transactions
WHERE created_at >= CURRENT_DATE - INTERVAL '7 days'
UNION ALL
SELECT 
    'Total Credits in Circulation' as metric,
    (SUM(uc.credits) + SUM(ac.credits))::text as value,
    'credits' as unit
FROM user_credits uc, anonymous_credits ac
UNION ALL
SELECT 
    'Pro Users' as metric,
    COUNT(*)::text as value,
    'users' as unit
FROM profiles
WHERE subscription_tier = 'pro';

GRANT SELECT ON admin_system_health TO authenticated;
COMMENT ON VIEW admin_system_health IS 'Overall system health metrics (quota utilization removed)';

-- Note: admin_quota_usage_analysis view is dropped permanently as it was entirely quota-based

-- =====================================================
-- STEP 6: Verification
-- =====================================================

DO $$
DECLARE
    user_credits_has_quota BOOLEAN;
    anonymous_credits_has_quota BOOLEAN;
BEGIN
    -- Check if columns still exist in user_credits
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_credits' 
        AND column_name IN ('daily_quota_used', 'daily_quota_limit', 'last_quota_reset')
    ) INTO user_credits_has_quota;
    
    -- Check if columns still exist in anonymous_credits
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'anonymous_credits' 
        AND column_name IN ('daily_quota_used', 'daily_quota_limit', 'last_quota_reset')
    ) INTO anonymous_credits_has_quota;
    
    IF user_credits_has_quota OR anonymous_credits_has_quota THEN
        RAISE EXCEPTION 'ERROR: Quota columns still exist! user_credits: %, anonymous_credits: %', 
            user_credits_has_quota, anonymous_credits_has_quota;
    ELSE
        RAISE NOTICE '✅ Quota columns removed successfully';
    END IF;
END $$;

-- =====================================================
-- Migration Complete
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Orphaned quota columns removed from user_credits and anonymous_credits tables';
END $$;

