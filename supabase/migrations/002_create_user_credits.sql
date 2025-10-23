-- Migration: Create hybrid credit management system
-- Author: AI Assistant
-- Date: 2025-10-14
-- Description: Supports both authenticated and anonymous user credit tracking

-- Create user_credits table (for authenticated users)
CREATE TABLE IF NOT EXISTS user_credits (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    credits INTEGER NOT NULL DEFAULT 0 CHECK (credits >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Ensure one record per user
    UNIQUE(user_id)
);

-- Create anonymous_credits table (for anonymous users)
CREATE TABLE IF NOT EXISTS anonymous_credits (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id TEXT NOT NULL UNIQUE,
    credits INTEGER NOT NULL DEFAULT 0 CHECK (credits >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_user_credits_user_id ON user_credits(user_id);
CREATE INDEX IF NOT EXISTS idx_anonymous_credits_device_id ON anonymous_credits(device_id);

-- Enable Row Level Security for user_credits
ALTER TABLE user_credits ENABLE ROW LEVEL SECURITY;

-- Policy: Users can read their own credits
DROP POLICY IF EXISTS "Users can view their own credits" ON user_credits;
CREATE POLICY "Users can view their own credits"
    ON user_credits
    FOR SELECT
    USING (auth.uid() = user_id);

-- Policy: Users can update their own credits
DROP POLICY IF EXISTS "Users can update their own credits" ON user_credits;
CREATE POLICY "Users can update their own credits"
    ON user_credits
    FOR UPDATE
    USING (auth.uid() = user_id);

-- Policy: Users can insert their own credits record
DROP POLICY IF EXISTS "Users can insert their own credits" ON user_credits;
CREATE POLICY "Users can insert their own credits"
    ON user_credits
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Anonymous credits: No RLS (publicly accessible for anonymous users)
-- This allows anonymous users to manage their credits without authentication

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_user_credits_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update updated_at on credit changes
DROP TRIGGER IF EXISTS trigger_update_user_credits_updated_at ON user_credits;
CREATE TRIGGER trigger_update_user_credits_updated_at
    BEFORE UPDATE ON user_credits
    FOR EACH ROW
    EXECUTE FUNCTION update_user_credits_updated_at();

-- Create credit_transactions table for audit trail (optional but recommended)
CREATE TABLE IF NOT EXISTS credit_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    amount INTEGER NOT NULL, -- Positive for additions, negative for spending
    balance_after INTEGER NOT NULL,
    source VARCHAR(50) NOT NULL, -- 'purchase', 'migration', 'spend', 'refund'
    transaction_metadata JSONB, -- Store additional data like product_id, etc.
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for transaction history queries
CREATE INDEX IF NOT EXISTS idx_credit_transactions_user_id ON credit_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_credit_transactions_created_at ON credit_transactions(created_at DESC);

-- Enable RLS on transactions
ALTER TABLE credit_transactions ENABLE ROW LEVEL SECURITY;

-- Policy: Users can read their own transactions
DROP POLICY IF EXISTS "Users can view their own transactions" ON credit_transactions;
CREATE POLICY "Users can view their own transactions"
    ON credit_transactions
    FOR SELECT
    USING (auth.uid() = user_id);

-- Function to create credit transaction record
CREATE OR REPLACE FUNCTION log_credit_transaction(
    p_user_id UUID,
    p_amount INTEGER,
    p_source VARCHAR(50),
    p_metadata JSONB DEFAULT '{}'::JSONB
)
RETURNS UUID AS $$
DECLARE
    v_balance_after INTEGER;
    v_transaction_id UUID;
BEGIN
    -- Get current balance
    SELECT credits INTO v_balance_after
    FROM user_credits
    WHERE user_id = p_user_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'User credits record not found for user %', p_user_id;
    END IF;
    
    -- Insert transaction record
    INSERT INTO credit_transactions (user_id, amount, balance_after, source, transaction_metadata)
    VALUES (p_user_id, p_amount, v_balance_after, p_source, p_metadata)
    RETURNING id INTO v_transaction_id;
    
    RETURN v_transaction_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Comments for documentation
COMMENT ON TABLE user_credits IS 'Stores credit balance for each user';
COMMENT ON TABLE credit_transactions IS 'Audit log of all credit additions and spending';
COMMENT ON COLUMN user_credits.credits IS 'Current credit balance (non-negative)';
COMMENT ON COLUMN credit_transactions.amount IS 'Credit change amount (positive = add, negative = spend)';
COMMENT ON COLUMN credit_transactions.source IS 'Source of transaction: purchase, migration, spend, refund';

