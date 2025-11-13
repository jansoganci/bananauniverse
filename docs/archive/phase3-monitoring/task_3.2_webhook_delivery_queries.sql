-- =====================================================
-- Task 3.2: Webhook Delivery Monitoring Queries
-- Purpose: Track webhook callback success rates and timing
-- Run these queries DAILY in Supabase SQL Editor
-- Duration: 30 minutes per day over 7 days
-- =====================================================

-- =====================================================
-- QUERY 1: Daily Webhook Success Rate (Last 24 Hours)
-- =====================================================
-- Shows how many jobs completed vs failed vs still pending
-- TARGET: >99% completion rate

SELECT
    COUNT(*) FILTER (WHERE status = 'completed') AS completed_jobs,
    COUNT(*) FILTER (WHERE status = 'failed') AS failed_jobs,
    COUNT(*) FILTER (WHERE status = 'pending' AND created_at < NOW() - INTERVAL '5 minutes') AS stuck_pending,
    COUNT(*) AS total_jobs,
    ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'completed') / NULLIF(COUNT(*), 0), 2) AS success_rate_percent,
    ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'failed') / NULLIF(COUNT(*), 0), 2) AS failure_rate_percent
FROM job_results
WHERE created_at > NOW() - INTERVAL '24 hours';

-- EXPECTED RESULT:
-- success_rate_percent: >99%
-- stuck_pending: 0
-- If success rate <99% or stuck_pending >0, investigate immediately

-- =====================================================
-- QUERY 2: Average Webhook Callback Time (Last 24 Hours)
-- =====================================================
-- Measures how long it takes for fal.ai to call webhook after job submission
-- TARGET: Average <20 seconds, Max <60 seconds

SELECT
    COUNT(*) AS completed_jobs,
    ROUND(AVG(EXTRACT(EPOCH FROM (completed_at - created_at)))::numeric, 2) AS avg_callback_time_seconds,
    ROUND(MIN(EXTRACT(EPOCH FROM (completed_at - created_at)))::numeric, 2) AS min_callback_time_seconds,
    ROUND(MAX(EXTRACT(EPOCH FROM (completed_at - created_at)))::numeric, 2) AS max_callback_time_seconds,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (completed_at - created_at)))::numeric, 2) AS median_callback_time_seconds,
    ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (completed_at - created_at)))::numeric, 2) AS p95_callback_time_seconds
FROM job_results
WHERE status = 'completed'
    AND created_at > NOW() - INTERVAL '24 hours'
    AND completed_at IS NOT NULL;

-- EXPECTED RESULT:
-- avg_callback_time_seconds: <20
-- max_callback_time_seconds: <60
-- p95_callback_time_seconds: <30
-- If avg >20s or max >60s, may need to adjust estimated_time in iOS

-- =====================================================
-- QUERY 3: Jobs By Hour (Last 24 Hours)
-- =====================================================
-- Shows traffic patterns and identifies peak hours
-- Useful for understanding usage patterns

SELECT
    DATE_TRUNC('hour', created_at) AS hour,
    COUNT(*) AS total_jobs,
    COUNT(*) FILTER (WHERE status = 'completed') AS completed,
    COUNT(*) FILTER (WHERE status = 'failed') AS failed,
    COUNT(*) FILTER (WHERE status = 'pending') AS pending,
    ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'completed') / NULLIF(COUNT(*), 0), 2) AS success_rate
FROM job_results
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY DATE_TRUNC('hour', created_at)
ORDER BY hour DESC;

-- EXPECTED RESULT:
-- Consistent success_rate across all hours
-- If specific hours have low success_rate, may indicate fal.ai downtime

-- =====================================================
-- QUERY 4: Webhook Rate Limiting Check (Last 24 Hours)
-- =====================================================
-- Checks if any IPs are hitting rate limits (100 req/min)
-- TARGET: No IPs approaching 100 req/min

SELECT
    ip_address,
    MAX(request_count) AS max_requests_per_minute,
    COUNT(*) AS total_windows,
    MAX(last_request) AS last_seen
FROM webhook_rate_limit
WHERE window_start > NOW() - INTERVAL '24 hours'
GROUP BY ip_address
HAVING MAX(request_count) > 50  -- Flag IPs using >50% of limit
ORDER BY max_requests_per_minute DESC
LIMIT 10;

-- EXPECTED RESULT:
-- Empty result or very few IPs
-- If any IP has max_requests_per_minute >80, investigate for abuse
-- Legitimate fal.ai traffic should be <10 req/min

-- =====================================================
-- QUERY 5: Recent Failed Jobs (Last 24 Hours)
-- =====================================================
-- Lists all failed jobs with error messages for debugging
-- TARGET: <1% failure rate

SELECT
    fal_job_id,
    created_at,
    completed_at,
    error,
    EXTRACT(EPOCH FROM (completed_at - created_at)) AS processing_time_seconds,
    user_id,
    device_id
FROM job_results
WHERE status = 'failed'
    AND created_at > NOW() - INTERVAL '24 hours'
ORDER BY created_at DESC
LIMIT 20;

-- EXPECTED RESULT:
-- Very few or zero failed jobs
-- Common errors to look for:
--   - "Image download failed" = fal.ai image URL issue
--   - "Storage upload failed" = Supabase storage quota issue
--   - "HEAD request failed" = fal.ai returned invalid URL

-- =====================================================
-- QUERY 6: Stuck Pending Jobs (>5 Minutes Old)
-- =====================================================
-- Identifies jobs that never received webhook callback
-- TARGET: 0 stuck jobs

SELECT
    fal_job_id,
    created_at,
    EXTRACT(EPOCH FROM (NOW() - created_at)) / 60 AS minutes_pending,
    user_id,
    device_id
FROM job_results
WHERE status = 'pending'
    AND created_at < NOW() - INTERVAL '5 minutes'
ORDER BY created_at ASC
LIMIT 20;

-- EXPECTED RESULT:
-- Empty result
-- If jobs stuck >5 minutes:
--   1. Check fal.ai status page
--   2. Check webhook-handler logs
--   3. Verify FAL_WEBHOOK_TOKEN is correct
--   4. Consider manual webhook retry or refund

-- =====================================================
-- DAILY MONITORING CHECKLIST
-- =====================================================
-- [ ] Run all 6 queries in Supabase SQL Editor
-- [ ] Record results in monitoring log (see task_3.2_monitoring_log.md)
-- [ ] Check if any alerts triggered (success rate <99%, stuck jobs, etc.)
-- [ ] If alerts triggered, investigate and document
-- [ ] Update monitoring spreadsheet (optional)

-- =====================================================
-- ALERT THRESHOLDS
-- =====================================================
-- 🚨 CRITICAL: success_rate <95% OR stuck_pending >10
-- ⚠️  WARNING: success_rate <99% OR avg_callback_time >20s
-- ✅ GOOD: success_rate >99% AND avg_callback_time <20s

-- =====================================================
-- NEXT STEPS IF ISSUES FOUND
-- =====================================================
-- 1. Check webhook-handler logs: supabase functions logs webhook-handler
-- 2. Check submit-job logs: supabase functions logs submit-job
-- 3. Check fal.ai status: https://status.fal.ai
-- 4. Verify FAL_WEBHOOK_TOKEN matches in both:
--    - Supabase Dashboard → Edge Functions → Secrets
--    - submit-job function (line 269)
-- 5. Check rate limiting not blocking legitimate traffic
-- 6. Consider rolling back to synchronous if critical issues
