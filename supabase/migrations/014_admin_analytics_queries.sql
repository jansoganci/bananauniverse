-- Migration: Admin Analytics Queries Collection
-- Author: AI Assistant
-- Date: 2025-01-20
-- Description: Comprehensive analytics queries for admin dashboard

-- =====================================================
-- 1. DAILY USAGE ANALYTICS
-- =====================================================

-- Query 1: Daily Credit Usage Summary (Last 30 Days)
-- Usage: Monitor daily credit consumption patterns
CREATE OR REPLACE VIEW admin_daily_usage_summary AS
SELECT 
    DATE(created_at) as usage_date,
    COUNT(*) as total_transactions,
    COUNT(DISTINCT user_id) as active_users,
    SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END) as credits_added,
    SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END) as credits_spent,
    SUM(CASE WHEN source = 'purchase' THEN amount ELSE 0 END) as purchase_credits,
    SUM(CASE WHEN source = 'spend' THEN ABS(amount) ELSE 0 END) as spend_credits,
    SUM(CASE WHEN source = 'migration' THEN amount ELSE 0 END) as migration_credits,
    ROUND(AVG(CASE WHEN amount < 0 THEN ABS(amount) ELSE NULL END), 2) as avg_spend_per_transaction
FROM credit_transactions
WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(created_at)
ORDER BY usage_date DESC;

-- Query 2: Weekly Usage Trends
-- Usage: Identify weekly patterns and growth trends
CREATE OR REPLACE VIEW admin_weekly_trends AS
SELECT 
    DATE_TRUNC('week', created_at) as week_start,
    COUNT(*) as total_transactions,
    COUNT(DISTINCT user_id) as unique_users,
    SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END) as credits_spent,
    COUNT(CASE WHEN source = 'purchase' THEN 1 END) as purchase_count,
    SUM(CASE WHEN source = 'purchase' THEN amount ELSE 0 END) as purchase_value
FROM credit_transactions
WHERE created_at >= CURRENT_DATE - INTERVAL '12 weeks'
GROUP BY DATE_TRUNC('week', created_at)
ORDER BY week_start DESC;

-- =====================================================
-- 2. USER BEHAVIOR ANALYTICS
-- =====================================================

-- Query 3: Top Credit Spenders
-- Usage: Identify your most active users
CREATE OR REPLACE VIEW admin_top_spenders AS
SELECT 
    uc.user_id,
    p.email,
    p.subscription_tier,
    uc.credits as current_balance,
    SUM(CASE WHEN ct.amount < 0 THEN ABS(ct.amount) ELSE 0 END) as total_spent,
    COUNT(CASE WHEN ct.amount < 0 THEN 1 END) as spend_transactions,
    MAX(ct.created_at) as last_activity,
    MIN(ct.created_at) as first_activity,
    EXTRACT(EPOCH FROM (MAX(ct.created_at) - MIN(ct.created_at)))/86400 as days_active
FROM user_credits uc
LEFT JOIN profiles p ON uc.user_id = p.id
LEFT JOIN credit_transactions ct ON uc.user_id = ct.user_id
GROUP BY uc.user_id, p.email, p.subscription_tier, uc.credits
HAVING SUM(CASE WHEN ct.amount < 0 THEN ABS(ct.amount) ELSE 0 END) > 0
ORDER BY total_spent DESC
LIMIT 50;

-- Query 4: User Retention Analysis
-- Usage: Track user engagement and retention
CREATE OR REPLACE VIEW admin_user_retention AS
SELECT 
    DATE_TRUNC('month', p.created_at) as signup_month,
    COUNT(*) as total_signups,
    COUNT(CASE WHEN ct.user_id IS NOT NULL THEN 1 END) as users_with_transactions,
    ROUND(
        COUNT(CASE WHEN ct.user_id IS NOT NULL THEN 1 END) * 100.0 / COUNT(*), 
        2
    ) as activation_rate,
    ROUND(AVG(user_activity_days), 2) as avg_days_active
FROM profiles p
LEFT JOIN (
    SELECT 
        user_id,
        EXTRACT(EPOCH FROM (MAX(created_at) - MIN(created_at)))/86400 as user_activity_days
    FROM credit_transactions
    GROUP BY user_id
) ct ON p.id = ct.user_id
WHERE p.created_at >= CURRENT_DATE - INTERVAL '12 months'
GROUP BY DATE_TRUNC('month', p.created_at)
ORDER BY signup_month DESC;

-- =====================================================
-- 3. CREDIT SPENDING PATTERNS
-- =====================================================

-- Query 5: Credit Source Analysis
-- Usage: Understand how users acquire credits
CREATE OR REPLACE VIEW admin_credit_sources AS
SELECT 
    source,
    COUNT(*) as transaction_count,
    SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END) as total_credits_added,
    COUNT(DISTINCT user_id) as unique_users,
    ROUND(AVG(CASE WHEN amount > 0 THEN amount ELSE NULL END), 2) as avg_amount_per_transaction,
    MIN(created_at) as first_transaction,
    MAX(created_at) as last_transaction
FROM credit_transactions
WHERE amount > 0  -- Only credit additions
GROUP BY source
ORDER BY total_credits_added DESC;

-- Query 6: Spending Patterns by User Type
-- Usage: Compare spending between free and pro users
CREATE OR REPLACE VIEW admin_spending_by_tier AS
SELECT 
    p.subscription_tier,
    COUNT(DISTINCT ct.user_id) as user_count,
    SUM(CASE WHEN ct.amount < 0 THEN ABS(ct.amount) ELSE 0 END) as total_spent,
    ROUND(AVG(CASE WHEN ct.amount < 0 THEN ABS(ct.amount) ELSE NULL END), 2) as avg_spend_per_transaction,
    ROUND(SUM(CASE WHEN ct.amount < 0 THEN ABS(ct.amount) ELSE 0 END) / COUNT(DISTINCT ct.user_id), 2) as avg_spend_per_user,
    COUNT(CASE WHEN ct.amount < 0 THEN 1 END) as total_spend_transactions
FROM credit_transactions ct
JOIN profiles p ON ct.user_id = p.id
WHERE ct.amount < 0  -- Only spending transactions
GROUP BY p.subscription_tier
ORDER BY total_spent DESC;

-- =====================================================
-- 4. QUOTA USAGE ANALYTICS
-- =====================================================

-- Query 7: Daily Quota Usage Analysis
-- Usage: Monitor quota consumption patterns
CREATE OR REPLACE VIEW admin_quota_usage_analysis AS
SELECT 
    DATE(last_quota_reset) as quota_date,
    COUNT(*) as total_users,
    SUM(daily_quota_used) as total_quota_used,
    SUM(daily_quota_limit) as total_quota_limit,
    ROUND(SUM(daily_quota_used) * 100.0 / SUM(daily_quota_limit), 2) as quota_utilization_percent,
    COUNT(CASE WHEN daily_quota_used >= daily_quota_limit THEN 1 END) as users_at_limit,
    COUNT(CASE WHEN daily_quota_used = 0 THEN 1 END) as inactive_users,
    ROUND(AVG(daily_quota_used), 2) as avg_quota_per_user
FROM user_credits
WHERE last_quota_reset >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(last_quota_reset)
ORDER BY quota_date DESC;

-- Query 8: Anonymous vs Authenticated Usage
-- Usage: Compare usage patterns between user types
CREATE OR REPLACE VIEW admin_user_type_comparison AS
SELECT 
    'authenticated' as user_type,
    COUNT(*) as user_count,
    SUM(credits) as total_credits,
    SUM(daily_quota_used) as total_quota_used,
    SUM(daily_quota_limit) as total_quota_limit,
    ROUND(AVG(credits), 2) as avg_credits_per_user,
    ROUND(AVG(daily_quota_used), 2) as avg_quota_used_per_user
FROM user_credits
UNION ALL
SELECT 
    'anonymous' as user_type,
    COUNT(*) as user_count,
    SUM(credits) as total_credits,
    SUM(daily_quota_used) as total_quota_used,
    SUM(daily_quota_limit) as total_quota_limit,
    ROUND(AVG(credits), 2) as avg_credits_per_user,
    ROUND(AVG(daily_quota_used), 2) as avg_quota_used_per_user
FROM anonymous_credits;

-- =====================================================
-- 5. BUSINESS METRICS
-- =====================================================

-- Query 9: Revenue Analytics (Credit Purchases)
-- Usage: Track credit purchase patterns and revenue
CREATE OR REPLACE VIEW admin_revenue_analytics AS
SELECT 
    DATE_TRUNC('month', created_at) as month,
    COUNT(*) as purchase_transactions,
    COUNT(DISTINCT user_id) as unique_buyers,
    SUM(amount) as total_credits_sold,
    ROUND(AVG(amount), 2) as avg_purchase_size,
    ROUND(SUM(amount) / COUNT(DISTINCT user_id), 2) as avg_credits_per_buyer,
    COUNT(CASE WHEN amount >= 100 THEN 1 END) as large_purchases,
    COUNT(CASE WHEN amount < 50 THEN 1 END) as small_purchases
FROM credit_transactions
WHERE source = 'purchase' AND amount > 0
GROUP BY DATE_TRUNC('month', created_at)
ORDER BY month DESC;

-- Query 10: System Health Metrics
-- Usage: Overall system health and performance indicators
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
    'Daily Quota Utilization' as metric,
    ROUND(SUM(uc.daily_quota_used) * 100.0 / SUM(uc.daily_quota_limit), 2)::text as value,
    'percent' as unit
FROM user_credits uc
UNION ALL
SELECT 
    'Pro Users' as metric,
    COUNT(*)::text as value,
    'users' as unit
FROM profiles
WHERE subscription_tier = 'pro';

-- =====================================================
-- 6. GRANT PERMISSIONS
-- =====================================================

-- Grant access to all analytics views to authenticated users
GRANT SELECT ON admin_daily_usage_summary TO authenticated;
GRANT SELECT ON admin_weekly_trends TO authenticated;
GRANT SELECT ON admin_top_spenders TO authenticated;
GRANT SELECT ON admin_user_retention TO authenticated;
GRANT SELECT ON admin_credit_sources TO authenticated;
GRANT SELECT ON admin_spending_by_tier TO authenticated;
GRANT SELECT ON admin_quota_usage_analysis TO authenticated;
GRANT SELECT ON admin_user_type_comparison TO authenticated;
GRANT SELECT ON admin_revenue_analytics TO authenticated;
GRANT SELECT ON admin_system_health TO authenticated;

-- =====================================================
-- 7. USAGE EXAMPLES
-- =====================================================

-- Example queries you can run:

-- 1. Get today's usage summary:
-- SELECT * FROM admin_daily_usage_summary WHERE usage_date = CURRENT_DATE;

-- 2. Find your top 10 most active users:
-- SELECT * FROM admin_top_spenders LIMIT 10;

-- 3. Check system health:
-- SELECT * FROM admin_system_health;

-- 4. Monitor quota usage:
-- SELECT * FROM admin_quota_usage_analysis WHERE quota_date >= CURRENT_DATE - INTERVAL '7 days';

-- 5. Track revenue trends:
-- SELECT * FROM admin_revenue_analytics WHERE month >= CURRENT_DATE - INTERVAL '6 months';

-- =====================================================
-- 8. COMMENTS FOR DOCUMENTATION
-- =====================================================

COMMENT ON VIEW admin_daily_usage_summary IS 'Daily credit usage analytics for the last 30 days';
COMMENT ON VIEW admin_weekly_trends IS 'Weekly usage trends and growth patterns';
COMMENT ON VIEW admin_top_spenders IS 'Top users by credit spending activity';
COMMENT ON VIEW admin_user_retention IS 'User activation and retention analysis';
COMMENT ON VIEW admin_credit_sources IS 'Analysis of how users acquire credits';
COMMENT ON VIEW admin_spending_by_tier IS 'Spending patterns by subscription tier';
COMMENT ON VIEW admin_quota_usage_analysis IS 'Daily quota consumption analysis';
COMMENT ON VIEW admin_user_type_comparison IS 'Comparison between authenticated and anonymous users';
COMMENT ON VIEW admin_revenue_analytics IS 'Credit purchase and revenue analytics';
COMMENT ON VIEW admin_system_health IS 'Overall system health metrics';
