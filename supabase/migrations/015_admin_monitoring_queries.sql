-- Migration: Admin Monitoring and Alert Queries
-- Author: AI Assistant
-- Date: 2025-01-20
-- Description: Automated monitoring queries for admin dashboard

-- =====================================================
-- 1. DAILY MONITORING QUERIES
-- =====================================================

-- Query 1: Daily System Check
-- Usage: Run this daily to monitor system health
CREATE OR REPLACE FUNCTION admin_daily_system_check()
RETURNS TABLE (
    check_name TEXT,
    status TEXT,
    value TEXT,
    details TEXT
) AS $$
BEGIN
    RETURN QUERY
    -- Check 1: Today's credit spending
    SELECT 
        'Daily Credit Spending' as check_name,
        CASE 
            WHEN daily_spend > 1000 THEN 'HIGH'
            WHEN daily_spend > 500 THEN 'MEDIUM'
            ELSE 'NORMAL'
        END as status,
        daily_spend::text as value,
        'Credits spent today' as details
    FROM (
        SELECT COALESCE(SUM(ABS(amount)), 0) as daily_spend
        FROM credit_transactions
        WHERE amount < 0 AND DATE(created_at) = CURRENT_DATE
    ) t
    
    UNION ALL
    
    -- Check 2: Active users today
    SELECT 
        'Active Users Today' as check_name,
        CASE 
            WHEN active_users > 100 THEN 'HIGH'
            WHEN active_users > 50 THEN 'MEDIUM'
            ELSE 'NORMAL'
        END as status,
        active_users::text as value,
        'Users with transactions today' as details
    FROM (
        SELECT COUNT(DISTINCT user_id) as active_users
        FROM credit_transactions
        WHERE DATE(created_at) = CURRENT_DATE
    ) t
    
    UNION ALL
    
    -- Check 3: Quota utilization
    SELECT 
        'Quota Utilization' as check_name,
        CASE 
            WHEN quota_util > 80 THEN 'HIGH'
            WHEN quota_util > 60 THEN 'MEDIUM'
            ELSE 'NORMAL'
        END as status,
        quota_util::text as value,
        'Percentage of daily quota used' as details
    FROM (
        SELECT ROUND(SUM(daily_quota_used) * 100.0 / SUM(daily_quota_limit), 2) as quota_util
        FROM user_credits
        WHERE DATE(last_quota_reset) = CURRENT_DATE
    ) t
    
    UNION ALL
    
    -- Check 4: Credit purchases today
    SELECT 
        'Credit Purchases Today' as check_name,
        CASE 
            WHEN purchases > 10 THEN 'HIGH'
            WHEN purchases > 5 THEN 'MEDIUM'
            ELSE 'NORMAL'
        END as status,
        purchases::text as value,
        'Number of credit purchases today' as details
    FROM (
        SELECT COUNT(*) as purchases
        FROM credit_transactions
        WHERE source = 'purchase' AND DATE(created_at) = CURRENT_DATE
    ) t;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 2. WEEKLY MONITORING QUERIES
-- =====================================================

-- Query 2: Weekly Growth Analysis
-- Usage: Run this weekly to track growth trends
CREATE OR REPLACE FUNCTION admin_weekly_growth_analysis()
RETURNS TABLE (
    metric TEXT,
    this_week TEXT,
    last_week TEXT,
    change_percent TEXT,
    trend TEXT
) AS $$
BEGIN
    RETURN QUERY
    WITH weekly_data AS (
        SELECT 
            DATE_TRUNC('week', created_at) as week,
            COUNT(DISTINCT user_id) as users,
            SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END) as spent,
            COUNT(*) as transactions
        FROM credit_transactions
        WHERE created_at >= CURRENT_DATE - INTERVAL '2 weeks'
        GROUP BY DATE_TRUNC('week', created_at)
        ORDER BY week DESC
    ),
    current_week AS (
        SELECT users, spent, transactions FROM weekly_data LIMIT 1
    ),
    previous_week AS (
        SELECT users, spent, transactions FROM weekly_data OFFSET 1 LIMIT 1
    )
    SELECT 
        'Active Users' as metric,
        cw.users::text as this_week,
        pw.users::text as last_week,
        CASE 
            WHEN pw.users > 0 THEN ROUND((cw.users - pw.users) * 100.0 / pw.users, 2)::text
            ELSE 'N/A'
        END as change_percent,
        CASE 
            WHEN cw.users > pw.users THEN 'UP'
            WHEN cw.users < pw.users THEN 'DOWN'
            ELSE 'STABLE'
        END as trend
    FROM current_week cw, previous_week pw
    
    UNION ALL
    
    SELECT 
        'Credits Spent' as metric,
        cw.spent::text as this_week,
        pw.spent::text as last_week,
        CASE 
            WHEN pw.spent > 0 THEN ROUND((cw.spent - pw.spent) * 100.0 / pw.spent, 2)::text
            ELSE 'N/A'
        END as change_percent,
        CASE 
            WHEN cw.spent > pw.spent THEN 'UP'
            WHEN cw.spent < pw.spent THEN 'DOWN'
            ELSE 'STABLE'
        END as trend
    FROM current_week cw, previous_week pw
    
    UNION ALL
    
    SELECT 
        'Total Transactions' as metric,
        cw.transactions::text as this_week,
        pw.transactions::text as last_week,
        CASE 
            WHEN pw.transactions > 0 THEN ROUND((cw.transactions - pw.transactions) * 100.0 / pw.transactions, 2)::text
            ELSE 'N/A'
        END as change_percent,
        CASE 
            WHEN cw.transactions > pw.transactions THEN 'UP'
            WHEN cw.transactions < pw.transactions THEN 'DOWN'
            ELSE 'STABLE'
        END as trend
    FROM current_week cw, previous_week pw;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 3. ALERT QUERIES
-- =====================================================

-- Query 3: System Alerts
-- Usage: Run this to check for potential issues
CREATE OR REPLACE FUNCTION admin_system_alerts()
RETURNS TABLE (
    alert_type TEXT,
    severity TEXT,
    message TEXT,
    recommendation TEXT
) AS $$
BEGIN
    RETURN QUERY
    -- Alert 1: High quota utilization
    SELECT 
        'High Quota Usage' as alert_type,
        'WARNING' as severity,
        'Daily quota utilization is above 80%' as message,
        'Consider increasing quota limits or optimizing usage' as recommendation
    WHERE EXISTS (
        SELECT 1 FROM user_credits
        WHERE DATE(last_quota_reset) = CURRENT_DATE
        AND daily_quota_used * 100.0 / daily_quota_limit > 80
    )
    
    UNION ALL
    
    -- Alert 2: Unusual spending spike
    SELECT 
        'Spending Spike' as alert_type,
        'INFO' as severity,
        'Today''s credit spending is significantly higher than average' as message,
        'Monitor for potential abuse or increased user activity' as recommendation
    WHERE EXISTS (
        SELECT 1 FROM (
            SELECT 
                SUM(ABS(amount)) as today_spend,
                AVG(daily_avg) as avg_spend
            FROM credit_transactions ct,
            (
                SELECT AVG(daily_spend) as daily_avg
                FROM (
                    SELECT DATE(created_at), SUM(ABS(amount)) as daily_spend
                    FROM credit_transactions
                    WHERE amount < 0 AND created_at >= CURRENT_DATE - INTERVAL '30 days'
                    GROUP BY DATE(created_at)
                ) daily_totals
            ) avg_calc
            WHERE ct.amount < 0 AND DATE(ct.created_at) = CURRENT_DATE
        ) spending_check
        WHERE today_spend > avg_spend * 2
    )
    
    UNION ALL
    
    -- Alert 3: Low user activity
    SELECT 
        'Low Activity' as alert_type,
        'INFO' as severity,
        'User activity is below normal levels' as message,
        'Consider promotional campaigns or feature announcements' as recommendation
    WHERE EXISTS (
        SELECT 1 FROM (
            SELECT COUNT(DISTINCT user_id) as today_users
            FROM credit_transactions
            WHERE DATE(created_at) = CURRENT_DATE
        ) activity_check
        WHERE today_users < 10  -- Adjust threshold as needed
    )
    
    UNION ALL
    
    -- Alert 4: Credit balance issues
    SELECT 
        'Credit Balance Alert' as alert_type,
        'WARNING' as severity,
        'Some users have unusually high credit balances' as message,
        'Review credit distribution and spending patterns' as recommendation
    WHERE EXISTS (
        SELECT 1 FROM user_credits
        WHERE credits > 1000  -- Adjust threshold as needed
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 4. PERFORMANCE MONITORING
-- =====================================================

-- Query 4: Database Performance Metrics
-- Usage: Monitor database performance and query efficiency
CREATE OR REPLACE FUNCTION admin_performance_metrics()
RETURNS TABLE (
    metric_name TEXT,
    metric_value TEXT,
    unit TEXT,
    description TEXT
) AS $$
BEGIN
    RETURN QUERY
    -- Table sizes
    SELECT 
        'user_credits_table_size' as metric_name,
        pg_size_pretty(pg_total_relation_size('user_credits')) as metric_value,
        'bytes' as unit,
        'Size of user_credits table' as description
    
    UNION ALL
    
    SELECT 
        'credit_transactions_table_size' as metric_name,
        pg_size_pretty(pg_total_relation_size('credit_transactions')) as metric_value,
        'bytes' as unit,
        'Size of credit_transactions table' as description
    
    UNION ALL
    
    SELECT 
        'anonymous_credits_table_size' as metric_name,
        pg_size_pretty(pg_total_relation_size('anonymous_credits')) as metric_value,
        'bytes' as unit,
        'Size of anonymous_credits table' as description
    
    UNION ALL
    
    -- Row counts
    SELECT 
        'total_user_credits_records' as metric_name,
        COUNT(*)::text as metric_value,
        'records' as unit,
        'Total user credit records' as description
    FROM user_credits
    
    UNION ALL
    
    SELECT 
        'total_transaction_records' as metric_name,
        COUNT(*)::text as metric_value,
        'records' as unit,
        'Total transaction records' as description
    FROM credit_transactions
    
    UNION ALL
    
    SELECT 
        'total_anonymous_records' as metric_name,
        COUNT(*)::text as metric_value,
        'records' as unit,
        'Total anonymous credit records' as description
    FROM anonymous_credits;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 5. GRANT PERMISSIONS
-- =====================================================

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION admin_daily_system_check() TO authenticated;
GRANT EXECUTE ON FUNCTION admin_weekly_growth_analysis() TO authenticated;
GRANT EXECUTE ON FUNCTION admin_system_alerts() TO authenticated;
GRANT EXECUTE ON FUNCTION admin_performance_metrics() TO authenticated;

-- =====================================================
-- 6. USAGE EXAMPLES
-- =====================================================

-- Example usage:

-- 1. Daily system check:
-- SELECT * FROM admin_daily_system_check();

-- 2. Weekly growth analysis:
-- SELECT * FROM admin_weekly_growth_analysis();

-- 3. Check for alerts:
-- SELECT * FROM admin_system_alerts();

-- 4. Performance metrics:
-- SELECT * FROM admin_performance_metrics();

-- =====================================================
-- 7. COMMENTS FOR DOCUMENTATION
-- =====================================================

COMMENT ON FUNCTION admin_daily_system_check() IS 'Daily system health check with status indicators';
COMMENT ON FUNCTION admin_weekly_growth_analysis() IS 'Weekly growth trend analysis with change percentages';
COMMENT ON FUNCTION admin_system_alerts() IS 'System alerts and recommendations for potential issues';
COMMENT ON FUNCTION admin_performance_metrics() IS 'Database performance and size metrics';
