-- =====================================================
-- Migration 036: Add Refund Tracking Columns
-- Purpose: Track quota refunds for failed AI processing
-- =====================================================

-- Add refund tracking columns to quota_consumption_log
ALTER TABLE quota_consumption_log
ADD COLUMN IF NOT EXISTS refunded BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS refunded_at TIMESTAMPTZ;

-- Create index for refund queries
CREATE INDEX IF NOT EXISTS idx_quota_log_refunded
ON quota_consumption_log(refunded, consumed_at DESC)
WHERE refunded = true;

-- Add comment for documentation
COMMENT ON COLUMN quota_consumption_log.refunded IS
'Tracks whether quota was refunded due to processing failure';

COMMENT ON COLUMN quota_consumption_log.refunded_at IS
'Timestamp when quota refund occurred';

-- =====================================================
-- Migration Complete
-- =====================================================
-- Next: Create refund_quota() function (migration 037)
