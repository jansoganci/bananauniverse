-- =====================================================
-- Task 3.3: Error Rate Monitoring Queries
-- Purpose: Track error rates and credit refund system
-- Run these queries DAILY in Supabase SQL Editor
-- Duration: 30 minutes per day over 7 days
-- =====================================================

-- =====================================================
-- QUERY 1: Overall Error Rate (Last 24 Hours)
-- =====================================================
-- Shows breakdown of job statuses and error rate
-- TARGET: <1% error rate (<0.5% ideal)

SELECT
    COUNT(*) FILTER (WHERE status = 'completed') AS completed,
    COUNT(*) FILTER (WHERE status = 'failed') AS failed,
    COUNT(*) FILTER (WHERE status = 'pending') AS pending,
    COUNT(*) AS total,
    ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'failed') / NULLIF(COUNT(*), 0), 2) AS error_rate_percent,
    ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'completed') / NULLIF(COUNT(*), 0), 2) AS success_rate_percent
FROM job_results
WHERE created_at > NOW() - INTERVAL '24 hours';

-- EXPECTED RESULT:
-- error_rate_percent: <1%
-- If error_rate >1%, investigate error causes in Query 2

-- =====================================================
-- QUERY 2: Error Breakdown by Type (Last 24 Hours)
-- =====================================================
-- Groups errors by error message to identify patterns
-- Helps prioritize fixes

SELECT
    CASE
        WHEN error LIKE '%Image download failed%' THEN 'Image Download Error'
        WHEN error LIKE '%Storage upload failed%' THEN 'Storage Upload Error'
        WHEN error LIKE '%HEAD request failed%' THEN 'HEAD Request Error'
        WHEN error LIKE '%Image too large%' THEN 'Image Size Error'
        WHEN error LIKE '%Invalid content type%' THEN 'Content Type Error'
        WHEN error LIKE '%magic bytes%' THEN 'Invalid Image Format'
        WHEN error IS NULL THEN 'Unknown Error'
        ELSE 'Other Error'
    END AS error_type,
    COUNT(*) AS occurrences,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percentage,
    array_agg(DISTINCT error) AS sample_errors
FROM job_results
WHERE status = 'failed'
    AND created_at > NOW() - INTERVAL '24 hours'
GROUP BY error_type
ORDER BY occurrences DESC;

-- EXPECTED RESULT:
-- Most common errors should be transient (Image Download Error)
-- If seeing "Storage Upload Error" repeatedly, check Supabase storage quota
-- If seeing "Image Size Error", users uploading too-large images

-- =====================================================
-- QUERY 3: Failed Jobs with Details (Last 24 Hours)
-- =====================================================
-- Shows all failed jobs with full context for debugging
-- Review top 20 failures

SELECT
    fal_job_id,
    created_at,
    completed_at,
    EXTRACT(EPOCH FROM (completed_at - created_at)) AS processing_time_seconds,
    error,
    COALESCE(user_id::text, device_id) AS user_identifier,
    CASE
        WHEN user_id IS NOT NULL THEN 'authenticated'
        ELSE 'anonymous'
    END AS user_type
FROM job_results
WHERE status = 'failed'
    AND created_at > NOW() - INTERVAL '24 hours'
ORDER BY created_at DESC
LIMIT 20;

-- EXPECTED RESULT:
-- Review error messages for patterns
-- Check if specific users hitting errors repeatedly
-- Note processing times (may indicate timeout issues)

-- =====================================================
-- QUERY 4: Credit Refund Verification (Last 24 Hours)
-- =====================================================
-- Verifies that failed jobs received credit refunds
-- TARGET: All failed jobs should have refund entry

WITH failed_jobs AS (
    SELECT
        fal_job_id,
        created_at,
        COALESCE(user_id::text, device_id) AS identifier,
        error
    FROM job_results
    WHERE status = 'failed'
        AND created_at > NOW() - INTERVAL '24 hours'
),
refunds AS (
    SELECT
        idempotency_key,
        COALESCE(user_id::text, device_id) AS identifier,
        created_at,
        response_body->>'credits' AS refunded_credits
    FROM idempotency_keys
    WHERE idempotency_key LIKE 'refund-%'
        AND created_at > NOW() - INTERVAL '24 hours'
)
SELECT
    fj.fal_job_id,
    fj.created_at AS failed_at,
    fj.identifier,
    fj.error,
    CASE
        WHEN r.idempotency_key IS NOT NULL THEN 'Yes'
        ELSE 'NO - ISSUE!'
    END AS refunded,
    r.refunded_credits
FROM failed_jobs fj
LEFT JOIN refunds r ON r.idempotency_key = 'refund-' || fj.fal_job_id
ORDER BY fj.created_at DESC;

-- EXPECTED RESULT:
-- All failed jobs should have refunded = 'Yes'
-- If any show 'NO - ISSUE!', credit refund system has a bug

-- =====================================================
-- QUERY 5: Quota Tracking Integrity Check (Last 24 Hours)
-- =====================================================
-- Verifies quota increments match job submissions
-- Ensures no "ghost" charges or missing refunds

SELECT
    COALESCE(user_id::text, device_id) AS identifier,
    COUNT(*) FILTER (WHERE status = 'completed') AS completed_jobs,
    COUNT(*) FILTER (WHERE status = 'failed') AS failed_jobs,
    COUNT(*) AS total_jobs_submitted,
    -- Expected net quota usage: completed jobs only (failed should be refunded)
    COUNT(*) FILTER (WHERE status = 'completed') AS expected_net_quota
FROM job_results
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY identifier
ORDER BY total_jobs_submitted DESC
LIMIT 20;

-- CROSS-REFERENCE WITH:
SELECT
    COALESCE(user_id::text, device_id) AS identifier,
    date,
    used AS quota_used,
    limit_value
FROM daily_quotas
WHERE date = CURRENT_DATE
ORDER BY used DESC
LIMIT 20;

-- EXPECTED RESULT:
-- quota_used should match expected_net_quota (completed jobs)
-- If quota_used > completed_jobs, refunds not working
-- If quota_used < completed_jobs, consuming quota incorrectly

-- =====================================================
-- QUERY 6: Error Rate Trend (Last 7 Days)
-- =====================================================
-- Shows daily error rates to identify trends
-- Helps spot degrading performance over time

SELECT
    DATE(created_at) AS date,
    COUNT(*) AS total_jobs,
    COUNT(*) FILTER (WHERE status = 'completed') AS completed,
    COUNT(*) FILTER (WHERE status = 'failed') AS failed,
    ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'failed') / NULLIF(COUNT(*), 0), 2) AS error_rate_percent
FROM job_results
WHERE created_at > NOW() - INTERVAL '7 days'
GROUP BY DATE(created_at)
ORDER BY date DESC;

-- EXPECTED RESULT:
-- Error rate should be consistent <1% across all days
-- If error rate increasing over time, investigate root cause
-- Sudden spike may indicate fal.ai outage or config change

-- =====================================================
-- QUERY 7: User Impact Analysis (Last 24 Hours)
-- =====================================================
-- Shows which users experienced errors
-- Helps prioritize user support/outreach

SELECT
    COALESCE(user_id::text, device_id) AS identifier,
    CASE
        WHEN user_id IS NOT NULL THEN 'authenticated'
        ELSE 'anonymous'
    END AS user_type,
    COUNT(*) AS total_jobs,
    COUNT(*) FILTER (WHERE status = 'failed') AS failed_jobs,
    COUNT(*) FILTER (WHERE status = 'completed') AS completed_jobs,
    ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'failed') / NULLIF(COUNT(*), 0), 2) AS user_error_rate
FROM job_results
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY identifier, user_type
HAVING COUNT(*) FILTER (WHERE status = 'failed') > 0
ORDER BY failed_jobs DESC, total_jobs DESC
LIMIT 20;

-- EXPECTED RESULT:
-- Most users should have low error rates
-- If specific users have high error rates, may need support outreach
-- Check if anonymous users have higher error rate (may indicate abuse)

-- =====================================================
-- DAILY MONITORING CHECKLIST
-- =====================================================
-- [ ] Run all 7 queries in Supabase SQL Editor
-- [ ] Record results in monitoring log (see task_3.3_monitoring_log.md)
-- [ ] Check if error rate <1%
-- [ ] Verify all failed jobs got refunds (Query 4)
-- [ ] Check quota integrity (Query 5)
-- [ ] If error rate >1%, investigate error breakdown (Query 2)
-- [ ] Document any issues and actions taken

-- =====================================================
-- ALERT THRESHOLDS
-- =====================================================
-- 🚨 CRITICAL: error_rate >2% OR refunds missing >5 jobs
-- ⚠️  WARNING: error_rate >1% OR refunds missing 1-5 jobs
-- ✅ GOOD: error_rate <1% AND all refunds working

-- =====================================================
-- COMMON ERRORS AND FIXES
-- =====================================================
-- "Image download failed: 404"
--   → fal.ai returned invalid URL, usually transient
--   → If persistent, check fal.ai status page
--
-- "Storage upload failed: quota exceeded"
--   → Supabase storage quota full
--   → Increase quota or clean up old images
--
-- "Image too large"
--   → User uploaded >50MB image
--   → Consider lowering client-side limit or increasing server limit
--
-- "Invalid content type"
--   → fal.ai returned non-image file
--   → Check webhook payload validation
--
-- "magic bytes verification failed"
--   → File not actually an image despite content-type header
--   → Could indicate fal.ai issue or attack attempt

-- =====================================================
-- NEXT STEPS IF ISSUES FOUND
-- =====================================================
-- 1. Check webhook-handler logs: supabase functions logs webhook-handler
-- 2. Check submit-job logs: supabase functions logs submit-job
-- 3. Review fal.ai API status: https://status.fal.ai
-- 4. Check Supabase storage quota: Dashboard → Storage
-- 5. If refunds failing, check add_credits function (migration 061)
-- 6. If quota tracking wrong, check consume_quota function (migration 060)
-- 7. Consider reaching out to affected users for feedback
