-- =====================================================
-- Migration 068: Create IAP Transactions Table
-- Purpose: Audit trail for all in-app purchases
-- Date: 2025-01-27
-- =====================================================

CREATE TABLE IF NOT EXISTS iap_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- User identification
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id TEXT,
    
    -- Product
    product_id TEXT NOT NULL REFERENCES products(product_id),
    
    -- Apple transaction IDs
    transaction_id TEXT NOT NULL,
    original_transaction_id TEXT NOT NULL,  -- For idempotency
    
    -- Credits
    credits_granted INTEGER NOT NULL,
    
    -- Status
    status TEXT NOT NULL CHECK (status IN ('pending', 'completed', 'refunded', 'failed')) DEFAULT 'pending',
    
    -- Verification
    verified_at TIMESTAMPTZ,
    receipt_data JSONB,  -- Store truncated receipt for debugging
    
    -- Refund tracking
    refunded_at TIMESTAMPTZ,
    refund_reason TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT iap_transactions_identifier CHECK (
        (user_id IS NOT NULL) OR (device_id IS NOT NULL)
    )
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_iap_transactions_user ON iap_transactions(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_iap_transactions_device ON iap_transactions(device_id) WHERE device_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_iap_transactions_transaction_id ON iap_transactions(transaction_id);
CREATE INDEX IF NOT EXISTS idx_iap_transactions_original_id ON iap_transactions(original_transaction_id);
CREATE INDEX IF NOT EXISTS idx_iap_transactions_status ON iap_transactions(status);
CREATE INDEX IF NOT EXISTS idx_iap_transactions_created ON iap_transactions(created_at DESC);

-- Unique constraint on original_transaction_id (prevents duplicates)
CREATE UNIQUE INDEX IF NOT EXISTS idx_iap_transactions_original_unique ON iap_transactions(original_transaction_id);

-- RLS Policies
ALTER TABLE iap_transactions ENABLE ROW LEVEL SECURITY;

-- Users can view their own transactions
CREATE POLICY "Users can view own transactions"
    ON iap_transactions FOR SELECT
    USING (
        (auth.uid() = user_id) OR
        (auth.role() = 'service_role')
    );

-- Service role can manage all transactions
CREATE POLICY "Service role can manage transactions"
    ON iap_transactions FOR ALL
    USING (auth.role() = 'service_role');

COMMENT ON TABLE iap_transactions IS 'Audit trail for all in-app purchase transactions';
COMMENT ON COLUMN iap_transactions.original_transaction_id IS 'Apple original transaction ID - used for idempotency';

