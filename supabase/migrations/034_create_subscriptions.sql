-- =====================================================
-- Migration 034: Create Subscriptions Table
-- Purpose: Server-side Premium Validation
-- Security Fix: Prevent client-controlled premium status
-- =====================================================

-- =====================================================
-- Subscriptions Table (Server-side Premium Validation)
-- =====================================================
CREATE TABLE IF NOT EXISTS subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id TEXT,  -- For anonymous premium users (gift codes, etc.)
    status TEXT NOT NULL CHECK (status IN ('active', 'expired', 'cancelled', 'grace_period')),
    product_id TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    original_transaction_id TEXT UNIQUE NOT NULL,  -- Apple StoreKit ID
    platform TEXT DEFAULT 'ios' CHECK (platform IN ('ios', 'android', 'web')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Either user_id OR device_id must be set
    CONSTRAINT subscription_identifier CHECK (
        (user_id IS NOT NULL) OR (device_id IS NOT NULL)
    )
);

-- Indexes for fast premium lookup
-- Note: Removed NOW() from WHERE clause as it's not IMMUTABLE
-- The query will still filter by expires_at, just not at index level
CREATE INDEX idx_subscriptions_active
ON subscriptions(user_id, status, expires_at)
WHERE status = 'active';

CREATE INDEX idx_subscriptions_device_active
ON subscriptions(device_id, status, expires_at)
WHERE device_id IS NOT NULL AND status = 'active';

CREATE INDEX idx_subscriptions_transaction
ON subscriptions(original_transaction_id);

-- RLS Policies
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own subscriptions"
ON subscriptions FOR SELECT
USING (
    auth.uid() = user_id
    OR device_id = current_setting('request.device_id', true)
);

-- Service role has full access (for webhooks)
CREATE POLICY "Service role full access"
ON subscriptions FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Updated timestamp trigger
CREATE TRIGGER update_subscriptions_updated_at
BEFORE UPDATE ON subscriptions
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- Migration Complete
-- =====================================================
-- Next Step: Update consume_quota() function to check this table
-- See: QUOTA_SYSTEM_IMPLEMENTATION_GUIDE.md FIX #2
