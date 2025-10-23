-- =====================================================
-- ROLLBACK Script for noname_banana AI Processing
-- =====================================================
--
-- ⚠️  WARNING: This will DELETE ALL DATA!
-- Only run this if you need to completely reset the database
-- during development/testing.
--
-- DO NOT RUN IN PRODUCTION without backing up data first!
--
-- =====================================================

-- 1. Drop views
DROP VIEW IF EXISTS job_stats;

-- 2. Drop triggers
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS update_profiles_updated_at ON profiles;
DROP TRIGGER IF EXISTS update_jobs_updated_at ON jobs;

-- 3. Drop functions
DROP FUNCTION IF EXISTS public.handle_new_user();
DROP FUNCTION IF EXISTS public.reset_daily_counters();
DROP FUNCTION IF EXISTS public.update_updated_at_column();

-- 4. Drop policies
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Users can view own jobs" ON jobs;
DROP POLICY IF EXISTS "Users can create own jobs" ON jobs;

-- 5. Drop indexes
DROP INDEX IF EXISTS idx_jobs_user_id;
DROP INDEX IF EXISTS idx_jobs_status;
DROP INDEX IF EXISTS idx_jobs_created_at;
DROP INDEX IF EXISTS idx_profiles_subscription_tier;

-- 6. Drop tables (CASCADE will also drop dependent objects)
DROP TABLE IF EXISTS jobs CASCADE;
DROP TABLE IF EXISTS profiles CASCADE;

-- Done! Database schema has been rolled back.
-- You can now run 001_create_database_schema.sql again for a clean setup.

