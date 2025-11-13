-- =====================================================
-- Task 3.5: User Experience Monitoring Queries
-- Purpose: Track user-facing metrics and identify UX issues
-- Run these queries DAILY in Supabase SQL Editor
-- Duration: 30 minutes per day over 7 days
-- =====================================================

-- =====================================================
-- QUERY 1: Jobs Exceeding Estimated Time (Last 24 Hours)
-- =====================================================
-- Shows how many jobs took longer than the 15-second estimate shown to users
-- TARGET: <5% of jobs exceed estimated time

SELECT
    COUNT(*) AS total_completed_jobs,
    COUNT(*) FILTER (
        WHERE EXTRACT(EPOCH FROM (completed_at - created_at)) > 15
    ) AS jobs_exceeding_estimate,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE EXTRACT(EPOCH FROM (completed_at - created_at)) > 15
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS percentage_exceeding_estimate,
    ROUND(
        AVG(EXTRACT(EPOCH FROM (completed_at - created_at)))::numeric,
        2
    ) AS avg_actual_time_seconds,
    ROUND(
        PERCENTILE_CONT(0.95) WITHIN GROUP (
            ORDER BY EXTRACT(EPOCH FROM (completed_at - created_at))
        )::numeric,
        2
    ) AS p95_actual_time_seconds
FROM job_results
WHERE status = 'completed'
    AND created_at > NOW() - INTERVAL '24 hours';

-- EXPECTED RESULT:
-- percentage_exceeding_estimate: <5%
-- If >5%, consider increasing estimated_time in iOS from 15s to 20s
-- p95_actual_time_seconds should guide the new estimate

-- =====================================================
-- QUERY 2: User Retry Behavior Analysis
-- =====================================================
-- Identifies users who submitted multiple jobs rapidly (may indicate frustration)
-- Helps spot users experiencing "stuck pending" issues

WITH user_job_intervals AS (
    SELECT
        COALESCE(user_id::text, device_id) AS user_identifier,
        created_at,
        LAG(created_at) OVER (
            PARTITION BY COALESCE(user_id::text, device_id)
            ORDER BY created_at
        ) AS prev_created_at
    FROM job_results
    WHERE created_at > NOW() - INTERVAL '24 hours'
)
SELECT
    user_identifier,
    COUNT(*) AS total_jobs,
    COUNT(*) FILTER (
        WHERE EXTRACT(EPOCH FROM (created_at - prev_created_at)) < 30
    ) AS rapid_retries,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE EXTRACT(EPOCH FROM (created_at - prev_created_at)) < 30
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS retry_rate_percent
FROM user_job_intervals
GROUP BY user_identifier
HAVING COUNT(*) FILTER (
    WHERE EXTRACT(EPOCH FROM (created_at - prev_created_at)) < 30
) > 2
ORDER BY rapid_retries DESC
LIMIT 20;

-- EXPECTED RESULT:
-- Few or no users with high retry rates
-- High retry rate may indicate:
--   - User thinks job is stuck (UX issue with loading indicator)
--   - Actual stuck jobs (backend issue)
--   - User impatience (need better UX feedback)

-- =====================================================
-- QUERY 3: Daily Active Users (DAU) Trend
-- =====================================================
-- Tracks unique users per day to monitor user retention
-- Helps identify if webhook migration affected user engagement

SELECT
    DATE(created_at) AS date,
    COUNT(DISTINCT COALESCE(user_id, device_id)) AS daily_active_users,
    COUNT(*) AS total_jobs,
    ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT COALESCE(user_id, device_id)), 2) AS avg_jobs_per_user
FROM job_results
WHERE created_at > NOW() - INTERVAL '7 days'
GROUP BY DATE(created_at)
ORDER BY date DESC;

-- EXPECTED RESULT:
-- Stable or increasing DAU
-- If DAU drops after webhook migration, investigate user complaints
-- avg_jobs_per_user should remain consistent (2-5 jobs/user typical)

-- =====================================================
-- QUERY 4: User Session Success Rate
-- =====================================================
-- Shows what percentage of users had all jobs succeed vs some failures
-- Helps identify user satisfaction

WITH user_sessions AS (
    SELECT
        COALESCE(user_id::text, device_id) AS user_identifier,
        COUNT(*) AS total_jobs,
        COUNT(*) FILTER (WHERE status = 'completed') AS successful_jobs,
        COUNT(*) FILTER (WHERE status = 'failed') AS failed_jobs
    FROM job_results
    WHERE created_at > NOW() - INTERVAL '24 hours'
    GROUP BY user_identifier
)
SELECT
    COUNT(*) AS total_users,
    COUNT(*) FILTER (WHERE failed_jobs = 0) AS users_all_success,
    COUNT(*) FILTER (WHERE failed_jobs > 0) AS users_with_failures,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE failed_jobs = 0) / NULLIF(COUNT(*), 0),
        2
    ) AS perfect_session_rate_percent,
    AVG(total_jobs) AS avg_jobs_per_user,
    AVG(CASE WHEN failed_jobs > 0 THEN failed_jobs ELSE NULL END) AS avg_failures_for_affected_users
FROM user_sessions;

-- EXPECTED RESULT:
-- perfect_session_rate_percent: >95%
-- Most users should have zero failures
-- If <95%, investigate common error causes (Task 3.3)

-- =====================================================
-- QUERY 5: Time-to-First-Success Analysis
-- =====================================================
-- Measures how long it takes new users to get their first successful result
-- Important for onboarding experience

WITH first_jobs AS (
    SELECT
        COALESCE(user_id::text, device_id) AS user_identifier,
        MIN(created_at) AS first_job_time,
        MIN(created_at) FILTER (WHERE status = 'completed') AS first_success_time,
        COUNT(*) FILTER (WHERE created_at = MIN(created_at) AND status = 'failed') AS first_job_failed
    FROM job_results
    WHERE created_at > NOW() - INTERVAL '7 days'
    GROUP BY user_identifier
)
SELECT
    COUNT(*) AS new_users,
    COUNT(*) FILTER (WHERE first_success_time IS NOT NULL) AS users_with_success,
    COUNT(*) FILTER (WHERE first_job_failed > 0) AS first_job_failures,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE first_job_failed > 0) / NULLIF(COUNT(*), 0),
        2
    ) AS first_job_failure_rate,
    ROUND(
        AVG(EXTRACT(EPOCH FROM (first_success_time - first_job_time)))::numeric,
        2
    ) AS avg_time_to_first_success_seconds
FROM first_jobs;

-- EXPECTED RESULT:
-- first_job_failure_rate: <5%
-- First impressions matter - high failure rate on first job is bad UX
-- avg_time_to_first_success_seconds should be <30s

-- =====================================================
-- QUERY 6: User Churn Analysis (Users Who Stopped Using)
-- =====================================================
-- Identifies users who were active but haven't returned
-- Helps spot if webhook migration caused churn

WITH user_activity AS (
    SELECT
        COALESCE(user_id::text, device_id) AS user_identifier,
        MAX(created_at) AS last_activity,
        COUNT(*) AS total_jobs
    FROM job_results
    WHERE created_at > NOW() - INTERVAL '14 days'
    GROUP BY user_identifier
)
SELECT
    COUNT(*) FILTER (
        WHERE last_activity BETWEEN NOW() - INTERVAL '14 days' AND NOW() - INTERVAL '7 days'
    ) AS users_active_7_14_days_ago,
    COUNT(*) FILTER (
        WHERE last_activity > NOW() - INTERVAL '7 days'
    ) AS users_active_last_7_days,
    COUNT(*) FILTER (
        WHERE last_activity BETWEEN NOW() - INTERVAL '14 days' AND NOW() - INTERVAL '7 days'
        AND total_jobs >= 3
    ) AS potential_churned_users
FROM user_activity;

-- EXPECTED RESULT:
-- potential_churned_users should be small
-- If many users churned after webhook launch, investigate:
--   - Did they experience errors?
--   - Did processing times increase?
--   - Did quota system have issues?

-- =====================================================
-- QUERY 7: Power User Behavior (Top 20 Active Users)
-- =====================================================
-- Analyzes most active users to understand their experience
-- Power users often have highest expectations

SELECT
    COALESCE(user_id::text, device_id) AS user_identifier,
    CASE
        WHEN user_id IS NOT NULL THEN 'authenticated'
        ELSE 'anonymous'
    END AS user_type,
    COUNT(*) AS total_jobs,
    COUNT(*) FILTER (WHERE status = 'completed') AS successful,
    COUNT(*) FILTER (WHERE status = 'failed') AS failed,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE status = 'completed') / NULLIF(COUNT(*), 0),
        2
    ) AS success_rate,
    MIN(created_at) AS first_job,
    MAX(created_at) AS last_job,
    ROUND(
        AVG(EXTRACT(EPOCH FROM (completed_at - created_at)))::numeric,
        2
    ) AS avg_processing_time
FROM job_results
WHERE created_at > NOW() - INTERVAL '7 days'
GROUP BY user_identifier, user_type
ORDER BY total_jobs DESC
LIMIT 20;

-- EXPECTED RESULT:
-- Power users should have high success rates (>95%)
-- If power users have low success rates, prioritize fixing their issues
-- Check if they're hitting quota limits or experiencing errors

-- =====================================================
-- QUERY 8: User Feedback Proxy (Completion Rate)
-- =====================================================
-- Measures what percentage of started jobs actually complete
-- Low completion rate may indicate users giving up

WITH job_lifecycle AS (
    SELECT
        DATE(created_at) AS date,
        COUNT(*) AS jobs_started,
        COUNT(*) FILTER (WHERE status IN ('completed', 'failed')) AS jobs_finished,
        COUNT(*) FILTER (WHERE status = 'completed') AS jobs_successful
    FROM job_results
    WHERE created_at > NOW() - INTERVAL '7 days'
    GROUP BY DATE(created_at)
)
SELECT
    date,
    jobs_started,
    jobs_finished,
    jobs_successful,
    ROUND(100.0 * jobs_finished / NULLIF(jobs_started, 0), 2) AS completion_rate_percent,
    ROUND(100.0 * jobs_successful / NULLIF(jobs_started, 0), 2) AS success_rate_percent
FROM job_lifecycle
ORDER BY date DESC;

-- EXPECTED RESULT:
-- completion_rate_percent: ~100% (all jobs should eventually finish)
-- If completion_rate <100%, jobs are stuck pending (webhook not received)
-- success_rate_percent: >99%

-- =====================================================
-- DAILY MONITORING CHECKLIST
-- =====================================================
-- [ ] Run all 8 queries in Supabase SQL Editor
-- [ ] Record results in monitoring log (task_3.5_monitoring_log.md)
-- [ ] Check if <5% of jobs exceed estimated time
-- [ ] Identify users with high retry rates (potential frustration)
-- [ ] Monitor DAU trend (should be stable or growing)
-- [ ] Check perfect session rate >95%
-- [ ] Review power user experience (top 20 users)
-- [ ] Check for user churn patterns

-- =====================================================
-- ALERT THRESHOLDS
-- =====================================================
-- 🚨 CRITICAL: >10% jobs exceed estimate OR DAU drops >20% OR completion rate <95%
-- ⚠️  WARNING: >5% jobs exceed estimate OR DAU drops >10% OR high retry rates
-- ✅ GOOD: <5% exceed estimate, stable DAU, >95% perfect sessions

-- =====================================================
-- USER EXPERIENCE RED FLAGS
-- =====================================================
-- 1. High retry rate (>10% of users):
--    → Users think jobs are stuck
--    → Need better loading indicators or progress feedback
--
-- 2. Many jobs exceeding estimate (>10%):
--    → Increase estimated_time in iOS
--    → Or optimize fal.ai processing speed
--
-- 3. Low perfect session rate (<90%):
--    → Too many users experiencing failures
--    → Focus on error rate reduction (Task 3.3)
--
-- 4. High first-job failure rate (>5%):
--    → Bad onboarding experience
--    → Review quota system and error handling
--
-- 5. User churn spike:
--    → Users abandoning after webhook migration
--    → Check for performance degradation or errors
--
-- 6. Power users with low success rates:
--    → Your most engaged users are frustrated
--    → Prioritize fixing their specific issues

-- =====================================================
-- NEXT STEPS IF ISSUES FOUND
-- =====================================================
-- 1. If jobs exceed estimate:
--    - Update estimated_time in Config.swift
--    - Add retry logic with longer wait
--
-- 2. If high retry rates:
--    - Improve loading indicators
--    - Add progress percentage (if possible)
--    - Show estimated time remaining
--
-- 3. If DAU drops:
--    - Check for error rate spike (Task 3.3)
--    - Review App Store reviews
--    - Reach out to churned users for feedback
--
-- 4. If low perfect session rate:
--    - Focus on reducing error rate
--    - Improve error messages shown to users
--    - Add better retry mechanisms
--
-- 5. If power users unhappy:
--    - Personally reach out for feedback
--    - Prioritize their issues
--    - Consider giving them premium access

-- =====================================================
-- SUPPLEMENTAL DATA SOURCES
-- =====================================================
-- Beyond SQL queries, also monitor:
-- 1. App Store reviews (iOS App Store Connect)
-- 2. Support tickets (email, Discord, etc.)
-- 3. Social media mentions
-- 4. User surveys (if available)
-- 5. Crash reports (Xcode Organizer)
--
-- These qualitative sources complement quantitative SQL data
