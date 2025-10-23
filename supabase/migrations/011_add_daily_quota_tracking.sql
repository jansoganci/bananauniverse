-- Migration: Add daily quota tracking to credit system
-- Author: AI Assistant
-- Date: 2025-01-27
-- Description: Adds daily quota tracking columns to user_credits and anonymous_credits tables

-- Add daily quota columns to user_credits table
ALTER TABLE user_credits 
ADD COLUMN IF NOT EXISTS daily_quota_used INTEGER DEFAULT 0 CHECK (daily_quota_used >= 0),
ADD COLUMN IF NOT EXISTS daily_quota_limit INTEGER DEFAULT 5 CHECK (daily_quota_limit > 0),
ADD COLUMN IF NOT EXISTS last_quota_reset TIMESTAMPTZ DEFAULT NOW();

-- Add daily quota columns to anonymous_credits table
ALTER TABLE anonymous_credits 
ADD COLUMN IF NOT EXISTS daily_quota_used INTEGER DEFAULT 0 CHECK (daily_quota_used >= 0),
ADD COLUMN IF NOT EXISTS daily_quota_limit INTEGER DEFAULT 5 CHECK (daily_quota_limit > 0),
ADD COLUMN IF NOT EXISTS last_quota_reset TIMESTAMPTZ DEFAULT NOW();

-- Create indexes for faster quota queries
CREATE INDEX IF NOT EXISTS idx_user_credits_quota_reset ON user_credits(last_quota_reset);
CREATE INDEX IF NOT EXISTS idx_anonymous_credits_quota_reset ON anonymous_credits(last_quota_reset);

-- Create composite indexes for quota validation queries
CREATE INDEX IF NOT EXISTS idx_user_credits_quota_validation ON user_credits(user_id, daily_quota_used, daily_quota_limit, last_quota_reset);
CREATE INDEX IF NOT EXISTS idx_anonymous_credits_quota_validation ON anonymous_credits(device_id, daily_quota_used, daily_quota_limit, last_quota_reset);

-- Add comments for documentation
COMMENT ON COLUMN user_credits.daily_quota_used IS 'Number of quota uses today for non-premium users';
COMMENT ON COLUMN user_credits.daily_quota_limit IS 'Daily quota limit for non-premium users';
COMMENT ON COLUMN user_credits.last_quota_reset IS 'Last time daily quota was reset (UTC)';

COMMENT ON COLUMN anonymous_credits.daily_quota_used IS 'Number of quota uses today for anonymous users';
COMMENT ON COLUMN anonymous_credits.daily_quota_limit IS 'Daily quota limit for anonymous users';
COMMENT ON COLUMN anonymous_credits.last_quota_reset IS 'Last time daily quota was reset (UTC)';

-- Update existing records to have proper default values
UPDATE user_credits 
SET 
    daily_quota_used = 0,
    daily_quota_limit = 5,
    last_quota_reset = NOW()
WHERE daily_quota_used IS NULL OR daily_quota_limit IS NULL OR last_quota_reset IS NULL;

UPDATE anonymous_credits 
SET 
    daily_quota_used = 0,
    daily_quota_limit = 5,
    last_quota_reset = NOW()
WHERE daily_quota_used IS NULL OR daily_quota_limit IS NULL OR last_quota_reset IS NULL;
