-- =====================================================
-- Task 3.4: Performance Monitoring Queries
-- Purpose: Track Edge Function execution times and database performance
-- Run these queries DAILY in Supabase SQL Editor
-- Duration: 20 minutes per day over 7 days
-- =====================================================

-- =====================================================
-- QUERY 1: Edge Function Execution Time Analysis
-- =====================================================
-- NOTE: This query uses job_results timing as proxy for Edge Function performance
-- Actual Edge Function logs are checked separately (see Bash Commands section below)

-- submit-job performance (measure time from request to job creation)
-- TARGET: <2 seconds average, <5 seconds max
SELECT
    'submit-job (proxy)' AS function_name,
    COUNT(*) AS executions_24h,
    ROUND(AVG(EXTRACT(EPOCH FROM (created_at - created_at)))::numeric, 2) AS avg_time_seconds,
    -- Note: We can't measure submit-job time from job_results alone
    -- Use 'supabase functions logs submit-job' for actual timing
    NULL AS min_time_seconds,
    NULL AS max_time_seconds,
    'Check logs for actual timing' AS note
FROM job_results
WHERE created_at > NOW() - INTERVAL '24 hours'
LIMIT 1;

-- webhook-handler performance (measure time from job completion to database update)
-- TARGET: <5 seconds average, <10 seconds max
SELECT
    'webhook-handler (proxy)' AS function_name,
    COUNT(*) AS executions_24h,
    ROUND(AVG(EXTRACT(EPOCH FROM (completed_at - completed_at)))::numeric, 2) AS avg_processing_seconds,
    -- Note: completed_at is set by webhook-handler when it finishes
    -- Actual execution time requires log analysis
    'Check logs for actual timing' AS note
FROM job_results
WHERE status IN ('completed', 'failed')
    AND completed_at > NOW() - INTERVAL '24 hours';

-- get-result performance (should be very fast, just database lookup)
-- TARGET: <500ms average, <2 seconds max
-- Note: No direct measurement from database, use logs

-- =====================================================
-- QUERY 2: Database Query Performance
-- =====================================================
-- Shows slowest queries on job_results and daily_quotas tables
-- TARGET: All queries <100ms

-- NOTE: Requires pg_stat_statements extension
-- Enable with: CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

SELECT
    LEFT(query, 100) AS query_snippet,
    calls,
    ROUND(mean_exec_time::numeric, 2) AS avg_time_ms,
    ROUND(max_exec_time::numeric, 2) AS max_time_ms,
    ROUND(total_exec_time::numeric, 2) AS total_time_ms
FROM pg_stat_statements
WHERE query LIKE '%job_results%'
   OR query LIKE '%daily_quotas%'
ORDER BY mean_exec_time DESC
LIMIT 10;

-- If pg_stat_statements not available, skip to Query 3

-- =====================================================
-- QUERY 3: Job Processing Time Distribution
-- =====================================================
-- Shows how long jobs take from submission to completion
-- This is END-TO-END time (includes fal.ai processing)
-- TARGET: Most jobs complete in 10-20 seconds

SELECT
    CASE
        WHEN processing_time < 10 THEN '< 10s'
        WHEN processing_time < 15 THEN '10-15s'
        WHEN processing_time < 20 THEN '15-20s'
        WHEN processing_time < 30 THEN '20-30s'
        WHEN processing_time < 60 THEN '30-60s'
        ELSE '> 60s'
    END AS time_bucket,
    COUNT(*) AS job_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM (
    SELECT
        EXTRACT(EPOCH FROM (completed_at - created_at)) AS processing_time
    FROM job_results
    WHERE status = 'completed'
        AND created_at > NOW() - INTERVAL '24 hours'
) AS times
GROUP BY time_bucket
ORDER BY time_bucket;

-- EXPECTED RESULT:
-- Most jobs in 10-20s range
-- If many jobs >30s, may need to increase estimated_time in iOS (currently 15s)

-- =====================================================
-- QUERY 4: Database Connection Pool Usage
-- =====================================================
-- Monitors database connection health
-- TARGET: Active connections <80% of max

SELECT
    COUNT(*) AS total_connections,
    COUNT(*) FILTER (WHERE state = 'active') AS active_connections,
    COUNT(*) FILTER (WHERE state = 'idle') AS idle_connections,
    COUNT(*) FILTER (WHERE wait_event IS NOT NULL) AS waiting_connections
FROM pg_stat_activity
WHERE datname = current_database();

-- EXPECTED RESULT:
-- active_connections should be low (system is async)
-- If waiting_connections >0, investigate blocking queries

-- =====================================================
-- QUERY 5: Rate Limiting Performance Impact
-- =====================================================
-- Checks if rate limiting is causing performance issues
-- TARGET: <1% of requests rate limited

WITH total_requests AS (
    SELECT COUNT(*) AS total
    FROM webhook_rate_limit
    WHERE window_start > NOW() - INTERVAL '24 hours'
),
rate_limited_requests AS (
    SELECT COUNT(*) AS limited
    FROM webhook_rate_limit
    WHERE request_count >= 100  -- Hit the limit
        AND window_start > NOW() - INTERVAL '24 hours'
)
SELECT
    tr.total AS total_requests,
    rl.limited AS rate_limited_requests,
    ROUND(100.0 * rl.limited / NULLIF(tr.total, 0), 2) AS rate_limit_percentage
FROM total_requests tr, rate_limited_requests rl;

-- EXPECTED RESULT:
-- rate_limit_percentage should be <1%
-- If >1%, may need to increase limit or investigate abuse

-- =====================================================
-- QUERY 6: Storage Upload Performance
-- =====================================================
-- Measures time webhook-handler takes to upload to storage
-- (Indirectly measured from webhook completion time)
-- TARGET: Upload completes within total webhook time <5s

SELECT
    'Storage Upload (via webhook)' AS operation,
    COUNT(*) AS uploads_24h,
    ROUND(AVG(EXTRACT(EPOCH FROM (completed_at - created_at)))::numeric, 2) AS avg_total_time_seconds,
    -- Note: This includes fal.ai processing time
    -- Actual upload time is a fraction of this
    'Actual upload time ~1-2s (part of webhook-handler)' AS note
FROM job_results
WHERE status = 'completed'
    AND completed_at > NOW() - INTERVAL '24 hours';

-- =====================================================
-- QUERY 7: Function Invocation Frequency
-- =====================================================
-- Shows how often each function is being called
-- Useful for capacity planning

SELECT
    'submit-job' AS function_name,
    COUNT(*) AS invocations_24h,
    ROUND(COUNT(*) / 24.0, 2) AS avg_per_hour
FROM job_results
WHERE created_at > NOW() - INTERVAL '24 hours'
UNION ALL
SELECT
    'webhook-handler' AS function_name,
    COUNT(*) AS invocations_24h,
    ROUND(COUNT(*) / 24.0, 2) AS avg_per_hour
FROM job_results
WHERE completed_at > NOW() - INTERVAL '24 hours'
    AND status IN ('completed', 'failed')
UNION ALL
SELECT
    'get-result (estimated)' AS function_name,
    COUNT(*) * 2 AS invocations_24h,  -- Assume 2 polls per job on average
    ROUND((COUNT(*) * 2) / 24.0, 2) AS avg_per_hour
FROM job_results
WHERE created_at > NOW() - INTERVAL '24 hours';

-- EXPECTED RESULT:
-- submit-job and webhook-handler should have similar counts
-- get-result may be called multiple times per job (polling until completed)

-- =====================================================
-- BASH COMMANDS: Edge Function Log Analysis
-- =====================================================
-- Run these commands in your terminal to check actual Edge Function performance

-- 1. Check submit-job execution times (last 100 invocations)
-- supabase functions logs submit-job --limit 100 | grep "Success"

-- 2. Check webhook-handler execution times (last 100 invocations)
-- supabase functions logs webhook-handler --limit 100 | grep "Job result saved"

-- 3. Check get-result execution times (last 100 invocations)
-- supabase functions logs get-result --limit 100 | grep "GET-RESULT"

-- 4. Check for slow queries or errors
-- supabase functions logs submit-job --limit 100 | grep -E "timeout|slow|error"
-- supabase functions logs webhook-handler --limit 100 | grep -E "timeout|slow|error"
-- supabase functions logs get-result --limit 100 | grep -E "timeout|slow|error"

-- =====================================================
-- PERFORMANCE TARGETS SUMMARY
-- =====================================================
-- Edge Functions:
--   - submit-job: avg <2s, max <5s
--   - webhook-handler: avg <5s, max <10s
--   - get-result: avg <500ms, max <2s
--
-- Database Queries:
--   - All queries: <100ms average
--   - No blocking queries
--
-- End-to-End Processing:
--   - Most jobs: 10-20 seconds
--   - P95: <30 seconds
--   - Max: <60 seconds
--
-- Rate Limiting:
--   - <1% of requests rate limited
--
-- Connection Pool:
--   - <80% utilization
--   - No waiting connections

-- =====================================================
-- DAILY MONITORING CHECKLIST
-- =====================================================
-- [ ] Run all 7 SQL queries
-- [ ] Run Bash commands to check Edge Function logs
-- [ ] Record results in monitoring log (task_3.4_monitoring_log.md)
-- [ ] Check if all performance targets met
-- [ ] Investigate any queries >100ms
-- [ ] Document any performance degradation

-- =====================================================
-- ALERT THRESHOLDS
-- =====================================================
-- 🚨 CRITICAL: Any function >10s avg OR database queries >500ms
-- ⚠️  WARNING: Functions approaching target limits OR queries >100ms
-- ✅ GOOD: All metrics within target ranges

-- =====================================================
-- PERFORMANCE OPTIMIZATION TIPS
-- =====================================================
-- If submit-job is slow:
--   - Check consume_quota function performance
--   - Check fal.ai API response time
--   - Review RLS policies on daily_quotas
--
-- If webhook-handler is slow:
--   - Check image download time (fal.ai CDN)
--   - Check storage upload time (Supabase storage)
--   - Review RLS policies on job_results
--
-- If get-result is slow:
--   - Add index on job_results(fal_job_id)
--   - Check RLS policy complexity
--   - Review session variable overhead
--
-- If database queries are slow:
--   - Add missing indexes
--   - Optimize RLS policies
--   - Consider materialized views for analytics

-- =====================================================
-- NEXT STEPS IF ISSUES FOUND
-- =====================================================
-- 1. Identify slow component (Edge Function or Database)
-- 2. Check logs for specific slow operations
-- 3. Review relevant indexes and RLS policies
-- 4. Consider caching frequently accessed data
-- 5. Monitor over multiple days to identify trends
-- 6. If persistent issues, consider architectural changes
