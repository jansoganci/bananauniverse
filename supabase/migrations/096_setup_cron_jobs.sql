-- =====================================================
-- Migration: Setup Cron Jobs for Cleanup
-- Purpose: Automatically clean up old images and anonymous users
-- Date: 2025-11-30
-- =====================================================

-- Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;

-- 1. Cleanup Images (Every 6 hours)
-- REPLACE [YOUR_SECRET_KEY] with your actual CLEANUP_API_KEY or SERVICE_ROLE_KEY
SELECT cron.schedule(
    'cleanup-old-images',
    '0 */6 * * *',
    $$
    SELECT
        net.http_post(
            url := 'https://jiorfutbmahpfgplkats.supabase.co/functions/v1/auto-cleanup-images',
            headers := '{"Content-Type": "application/json", "x-api-key": "[YOUR_SECRET_KEY]"}'::jsonb
        ) as request_id;
    $$
);

-- 2. Cleanup Anonymous Users (Every 24 hours)
-- Deletes anonymous users older than 30 days
SELECT cron.schedule(
    'cleanup-anonymous-users',
    '0 0 * * *', -- Every day at midnight
    $$
    DELETE FROM auth.users
    WHERE is_anonymous is true 
    AND created_at < now() - interval '30 days';
    $$
);

-- Log completion
DO $$
BEGIN
    RAISE NOTICE '✅ Scheduled cron jobs for image and user cleanup';
END $$;

