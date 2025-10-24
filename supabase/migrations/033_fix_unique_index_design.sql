-- Migration 033: Fix Unique Index Design for NULL-Safe Comparisons
-- The unique index must use COALESCE on BOTH user_id and device_id for consistent NULL handling

-- Drop the old broken index
DROP INDEX IF EXISTS daily_quotas_unique_user_device_date;

-- STEP 1: Clean up duplicate records created by failed UPDATE attempts
-- Keep only the record with the highest 'used' value for each (user_id, device_id, date) combination
DELETE FROM daily_quotas
WHERE id NOT IN (
    SELECT DISTINCT ON (COALESCE(user_id::text, ''), COALESCE(device_id, ''), date) id
    FROM daily_quotas
    ORDER BY COALESCE(user_id::text, ''), COALESCE(device_id, ''), date, used DESC, created_at DESC
);

-- STEP 2: Create new NULL-safe index with COALESCE on BOTH columns
-- This ensures that NULL values are treated consistently in both INSERT and UPDATE operations
CREATE UNIQUE INDEX daily_quotas_unique_user_device_date
ON daily_quotas (
    COALESCE(user_id::text, ''),
    COALESCE(device_id, ''),  -- ← ADDED COALESCE for NULL-safe comparison
    date
);

-- Now the WHERE clause in consume_quota function will work correctly:
-- INSERT: COALESCE(NULL, '') = ''
-- UPDATE WHERE: COALESCE(NULL, '') = ''
-- They match! ✅

-- The existing consume_quota function already uses the correct WHERE clause:
-- WHERE COALESCE(user_id::text, '') = COALESCE(p_user_id::text, '')
-- AND COALESCE(device_id, '') = COALESCE(p_device_id, '')
-- This matches the new index structure perfectly!

-- Comments
COMMENT ON INDEX daily_quotas_unique_user_device_date IS 'Unique index with COALESCE on both user_id and device_id for NULL-safe comparisons';

