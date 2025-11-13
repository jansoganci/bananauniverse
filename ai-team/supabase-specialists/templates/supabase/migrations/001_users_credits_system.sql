-- ==========================================
-- MIGRATION: Users + Credits System
-- Purpose: Core user table with credit-based quota system
-- ==========================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==========================================
-- USERS TABLE
-- ==========================================
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Auth (if using custom auth, otherwise Supabase Auth handles this)
    email TEXT UNIQUE,
    device_id TEXT UNIQUE, -- For guest users (iOS DeviceCheck)

    -- Credits
    credits_remaining INTEGER DEFAULT 0 CHECK (credits_remaining >= 0),

    -- Account type
    is_guest BOOLEAN DEFAULT true,

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    deleted_at TIMESTAMPTZ, -- Soft delete

    INDEX idx_users_email (email),
    INDEX idx_users_device_id (device_id)
);

-- ==========================================
-- QUOTA LOG (Credit transactions)
-- ==========================================
CREATE TABLE quota_log (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES users(id) NOT NULL,

    -- Transaction details
    change INTEGER NOT NULL, -- Positive for add, negative for deduct
    reason TEXT NOT NULL, -- 'iap_purchase', 'video_generation', 'refund', etc.

    -- Balance tracking
    balance_before INTEGER NOT NULL,
    balance_after INTEGER NOT NULL,

    -- Idempotency
    transaction_id TEXT, -- External transaction ID (e.g., Apple IAP)

    -- Metadata
    metadata JSONB DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ DEFAULT now(),

    INDEX idx_quota_log_user (user_id, created_at DESC),
    INDEX idx_quota_log_transaction (transaction_id)
);

-- ==========================================
-- IDEMPOTENCY LOG (Prevent duplicate operations)
-- ==========================================
CREATE TABLE idempotency_log (
    id BIGSERIAL PRIMARY KEY,
    idempotency_key TEXT UNIQUE NOT NULL,

    -- Request info
    user_id UUID REFERENCES users(id),
    operation_type TEXT NOT NULL, -- 'video_generation', 'iap_purchase', etc.

    -- Response
    status_code INTEGER,
    response_data JSONB,

    -- Expiration
    expires_at TIMESTAMPTZ DEFAULT (now() + interval '24 hours'),

    created_at TIMESTAMPTZ DEFAULT now(),

    INDEX idx_idempotency_key (idempotency_key),
    INDEX idx_idempotency_expires (expires_at)
);

-- ==========================================
-- STORED PROCEDURE: Add Credits
-- ==========================================
CREATE OR REPLACE FUNCTION add_credits(
    p_user_id UUID,
    p_amount INTEGER,
    p_reason TEXT DEFAULT 'manual',
    p_transaction_id TEXT DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'::jsonb
) RETURNS JSONB AS $$
DECLARE
    current_balance INTEGER;
    new_balance INTEGER;
BEGIN
    -- Check for duplicate transaction (idempotency)
    IF p_transaction_id IS NOT NULL THEN
        PERFORM 1 FROM quota_log
        WHERE transaction_id = p_transaction_id;

        IF FOUND THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'Duplicate transaction'
            );
        END IF;
    END IF;

    -- Lock row and get current balance
    SELECT credits_remaining INTO current_balance
    FROM users WHERE id = p_user_id FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'User not found'
        );
    END IF;

    -- Calculate new balance
    new_balance := current_balance + p_amount;

    -- Update user balance
    UPDATE users
    SET credits_remaining = new_balance,
        updated_at = now()
    WHERE id = p_user_id;

    -- Log transaction
    INSERT INTO quota_log (
        user_id,
        change,
        reason,
        balance_before,
        balance_after,
        transaction_id,
        metadata
    ) VALUES (
        p_user_id,
        p_amount,
        p_reason,
        current_balance,
        new_balance,
        p_transaction_id,
        p_metadata
    );

    RETURN jsonb_build_object(
        'success', true,
        'credits_remaining', new_balance,
        'credits_added', p_amount
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==========================================
-- STORED PROCEDURE: Deduct Credits
-- ==========================================
CREATE OR REPLACE FUNCTION deduct_credits(
    p_user_id UUID,
    p_amount INTEGER,
    p_reason TEXT DEFAULT 'usage',
    p_metadata JSONB DEFAULT '{}'::jsonb
) RETURNS JSONB AS $$
DECLARE
    current_balance INTEGER;
    new_balance INTEGER;
BEGIN
    -- Lock row and get current balance
    SELECT credits_remaining INTO current_balance
    FROM users WHERE id = p_user_id FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'User not found'
        );
    END IF;

    -- Check sufficient balance
    IF current_balance < p_amount THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Insufficient credits',
            'required', p_amount,
            'available', current_balance
        );
    END IF;

    -- Calculate new balance
    new_balance := current_balance - p_amount;

    -- Update user balance
    UPDATE users
    SET credits_remaining = new_balance,
        updated_at = now()
    WHERE id = p_user_id;

    -- Log transaction
    INSERT INTO quota_log (
        user_id,
        change,
        reason,
        balance_before,
        balance_after,
        metadata
    ) VALUES (
        p_user_id,
        -p_amount,
        p_reason,
        current_balance,
        new_balance,
        p_metadata
    );

    RETURN jsonb_build_object(
        'success', true,
        'credits_remaining', new_balance,
        'credits_deducted', p_amount
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==========================================
-- STORED PROCEDURE: Merge Guest Account
-- ==========================================
CREATE OR REPLACE FUNCTION merge_guest_account(
    p_guest_id UUID,
    p_authenticated_id UUID
) RETURNS JSONB AS $$
DECLARE
    guest_credits INTEGER;
BEGIN
    -- Lock both accounts
    SELECT credits_remaining INTO guest_credits
    FROM users WHERE id = p_guest_id FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Guest account not found'
        );
    END IF;

    -- Transfer quota log
    UPDATE quota_log
    SET user_id = p_authenticated_id
    WHERE user_id = p_guest_id;

    -- Add guest credits to authenticated account
    UPDATE users
    SET credits_remaining = credits_remaining + guest_credits,
        updated_at = now()
    WHERE id = p_authenticated_id;

    -- Soft delete guest account
    UPDATE users
    SET deleted_at = now()
    WHERE id = p_guest_id;

    RETURN jsonb_build_object(
        'success', true,
        'credits_transferred', guest_credits
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==========================================
-- ROW LEVEL SECURITY (RLS)
-- ==========================================
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE quota_log ENABLE ROW LEVEL SECURITY;

-- Users can only see their own data
CREATE POLICY "Users can view own data" ON users
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own data" ON users
    FOR UPDATE USING (auth.uid() = id);

-- Users can only see their own transactions
CREATE POLICY "Users can view own transactions" ON quota_log
    FOR SELECT USING (auth.uid() = user_id);

-- ==========================================
-- CLEANUP: Auto-delete expired idempotency logs
-- ==========================================
CREATE OR REPLACE FUNCTION cleanup_expired_idempotency_logs()
RETURNS void AS $$
BEGIN
    DELETE FROM idempotency_log
    WHERE expires_at < now();
END;
$$ LANGUAGE plpgsql;

-- Run cleanup daily (requires pg_cron extension)
-- SELECT cron.schedule('cleanup-idempotency', '0 2 * * *', 'SELECT cleanup_expired_idempotency_logs()');
