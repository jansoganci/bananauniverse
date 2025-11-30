-- =====================================================
-- Migration: Create StableID to UserID Mapping Table
-- Purpose: Track which device (StableID) belongs to which user
-- Date: 2025-11-30
-- =====================================================

-- Create the mapping table
CREATE TABLE IF NOT EXISTS device_user_map (
    device_id TEXT PRIMARY KEY,
    current_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    previous_user_ids UUID[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for faster lookups by user_id
CREATE INDEX IF NOT EXISTS idx_device_user_map_user_id ON device_user_map(current_user_id);

-- Add comment for documentation
COMMENT ON TABLE device_user_map IS 'Maps StableID (device_id) to current and previous Supabase user IDs for credit recovery';
COMMENT ON COLUMN device_user_map.device_id IS 'StableID from iOS device (persistent across app reinstalls)';
COMMENT ON COLUMN device_user_map.current_user_id IS 'Current Supabase anonymous user ID for this device';
COMMENT ON COLUMN device_user_map.previous_user_ids IS 'Array of old user IDs that were replaced (audit trail)';

-- Log completion
DO $$
BEGIN
    RAISE NOTICE '✅ Created device_user_map table for StableID tracking';
END $$;

