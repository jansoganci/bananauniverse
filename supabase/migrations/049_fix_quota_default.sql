-- =====================================================
-- Migration 049: Fix Daily Quota Default from 5 to 3
-- Purpose: Ensure new and existing quota records use limit_value = 3
-- =====================================================

-- Update default value for future records
ALTER TABLE daily_quotas 
ALTER COLUMN limit_value SET DEFAULT 3;

-- Update existing records that still have old value
UPDATE daily_quotas 
SET limit_value = 3 
WHERE limit_value = 5;

-- =====================================================
-- End of Migration 049
-- =====================================================

