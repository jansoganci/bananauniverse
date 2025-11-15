-- ==========================================
-- MIGRATION: IAP Products & Transactions
-- Purpose: In-App Purchase management with products database
-- ==========================================

-- ==========================================
-- PRODUCTS TABLE (Dynamic product management)
-- ==========================================
CREATE TABLE products (
    product_id TEXT PRIMARY KEY, -- Matches App Store product ID

    -- Product info
    name TEXT NOT NULL,
    description TEXT,

    -- Credits
    credits INTEGER NOT NULL CHECK (credits > 0),
    bonus_credits INTEGER DEFAULT 0 CHECK (bonus_credits >= 0),

    -- Product type
    product_type TEXT CHECK (product_type IN (
        'consumable',
        'non_consumable',
        'auto_renewable_subscription',
        'non_renewing_subscription'
    )) DEFAULT 'consumable',

    -- Availability
    is_active BOOLEAN DEFAULT true,
    is_promotional BOOLEAN DEFAULT false,
    is_featured BOOLEAN DEFAULT false,

    -- Time-based availability (for promotions)
    valid_from TIMESTAMPTZ,
    valid_until TIMESTAMPTZ,

    -- UI
    display_order INTEGER DEFAULT 0,

    -- Metadata
    metadata JSONB DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),

    INDEX idx_products_active (is_active, display_order)
);

-- Seed some example products
INSERT INTO products (product_id, name, description, credits, bonus_credits, display_order) VALUES
    ('com.yourapp.credits.small', 'Starter Pack', '10 credits to get started', 10, 0, 1),
    ('com.yourapp.credits.medium', 'Popular Pack', '50 credits + 5 bonus', 50, 5, 2),
    ('com.yourapp.credits.large', 'Best Value', '100 credits + 20 bonus', 100, 20, 3);

-- ==========================================
-- IAP TRANSACTIONS (Apple purchases)
-- ==========================================
CREATE TABLE iap_transactions (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES users(id) NOT NULL,

    -- Apple transaction IDs
    transaction_id TEXT NOT NULL,
    original_transaction_id TEXT NOT NULL, -- Never changes, used for deduplication

    -- Product
    product_id TEXT REFERENCES products(product_id) NOT NULL,

    -- Credits
    credits_granted INTEGER NOT NULL,

    -- Status
    status TEXT CHECK (status IN ('pending', 'completed', 'failed', 'refunded')) DEFAULT 'pending',

    -- Verification
    verified_at TIMESTAMPTZ,
    verification_data JSONB, -- Raw response from Apple

    -- Refund tracking
    refunded_at TIMESTAMPTZ,
    refund_reason TEXT,

    created_at TIMESTAMPTZ DEFAULT now(),

    INDEX idx_iap_user (user_id, created_at DESC),
    INDEX idx_iap_original_tx (original_transaction_id),
    UNIQUE (original_transaction_id) -- Prevent duplicate purchases
);

-- ==========================================
-- SUBSCRIPTIONS (Auto-renewable)
-- ==========================================
CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) NOT NULL,

    -- Apple subscription IDs
    original_transaction_id TEXT UNIQUE NOT NULL,
    latest_transaction_id TEXT NOT NULL,

    -- Product
    product_id TEXT REFERENCES products(product_id),

    -- Status
    status TEXT CHECK (status IN (
        'active',
        'expired',
        'grace_period',
        'billing_retry',
        'cancelled',
        'refunded'
    )) NOT NULL DEFAULT 'active',

    -- Renewal
    will_auto_renew BOOLEAN DEFAULT true,
    auto_renew_enabled BOOLEAN DEFAULT true,

    -- Dates
    purchase_date TIMESTAMPTZ NOT NULL,
    expires_date TIMESTAMPTZ NOT NULL,
    grace_period_expires_date TIMESTAMPTZ,
    billing_retry_date TIMESTAMPTZ,

    -- Credits
    credits_per_period INTEGER NOT NULL,
    total_renewals INTEGER DEFAULT 0,

    -- Metadata
    metadata JSONB DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),

    INDEX idx_subscriptions_user (user_id, status),
    INDEX idx_subscriptions_expires (expires_date)
);

-- ==========================================
-- REFUND LOG (Track refunds)
-- ==========================================
CREATE TABLE refund_log (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES users(id) NOT NULL,

    -- Transaction
    transaction_id TEXT NOT NULL,
    original_purchase_amount INTEGER NOT NULL,
    credits_deducted INTEGER NOT NULL,

    -- Refund details
    refund_reason TEXT, -- From Apple: 'fraud', 'customer_support', 'other'

    -- User impact
    balance_before INTEGER,
    balance_after INTEGER,
    went_negative BOOLEAN DEFAULT false,

    -- Actions taken
    user_banned BOOLEAN DEFAULT false,

    processed_at TIMESTAMPTZ DEFAULT now(),

    INDEX idx_refund_log_user (user_id, processed_at DESC)
);

-- ==========================================
-- STORED PROCEDURE: Process IAP Purchase
-- ==========================================
CREATE OR REPLACE FUNCTION process_iap_purchase(
    p_user_id UUID,
    p_transaction_id TEXT,
    p_original_transaction_id TEXT,
    p_product_id TEXT
) RETURNS JSONB AS $$
DECLARE
    product RECORD;
    total_credits INTEGER;
BEGIN
    -- Check for duplicate purchase (idempotency)
    PERFORM 1 FROM iap_transactions
    WHERE original_transaction_id = p_original_transaction_id;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Transaction already processed'
        );
    END IF;

    -- Get product details
    SELECT * INTO product
    FROM products
    WHERE product_id = p_product_id AND is_active = true;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Product not found or inactive'
        );
    END IF;

    -- Check promotional validity
    IF product.is_promotional THEN
        IF product.valid_from IS NOT NULL AND now() < product.valid_from THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'Promotion not yet started'
            );
        END IF;
        IF product.valid_until IS NOT NULL AND now() > product.valid_until THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'Promotion expired'
            );
        END IF;
    END IF;

    -- Calculate total credits (base + bonus)
    total_credits := product.credits + product.bonus_credits;

    -- Add credits
    PERFORM add_credits(
        p_user_id,
        total_credits,
        'iap_purchase',
        p_original_transaction_id,
        jsonb_build_object(
            'product_id', p_product_id,
            'product_name', product.name,
            'base_credits', product.credits,
            'bonus_credits', product.bonus_credits,
            'transaction_id', p_transaction_id
        )
    );

    -- Record IAP transaction
    INSERT INTO iap_transactions (
        user_id,
        transaction_id,
        original_transaction_id,
        product_id,
        credits_granted,
        status,
        verified_at
    ) VALUES (
        p_user_id,
        p_transaction_id,
        p_original_transaction_id,
        p_product_id,
        total_credits,
        'completed',
        now()
    );

    RETURN jsonb_build_object(
        'success', true,
        'credits_granted', total_credits,
        'product_name', product.name
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==========================================
-- STORED PROCEDURE: Process Refund
-- ==========================================
CREATE OR REPLACE FUNCTION process_refund(
    p_transaction_id TEXT,
    p_refund_reason TEXT
) RETURNS JSONB AS $$
DECLARE
    transaction RECORD;
    user_balance INTEGER;
BEGIN
    -- Find original purchase
    SELECT * INTO transaction
    FROM iap_transactions
    WHERE original_transaction_id = p_transaction_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Transaction not found'
        );
    END IF;

    -- Check if already refunded
    IF transaction.status = 'refunded' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Already refunded'
        );
    END IF;

    -- Get current balance
    SELECT credits_remaining INTO user_balance
    FROM users WHERE id = transaction.user_id;

    -- Try to deduct credits
    IF user_balance >= transaction.credits_granted THEN
        -- Sufficient balance, deduct normally
        PERFORM deduct_credits(
            transaction.user_id,
            transaction.credits_granted,
            'iap_refund',
            jsonb_build_object('transaction_id', p_transaction_id)
        );
    ELSE
        -- Insufficient balance, zero out
        UPDATE users
        SET credits_remaining = 0
        WHERE id = transaction.user_id;
    END IF;

    -- Mark transaction as refunded
    UPDATE iap_transactions
    SET status = 'refunded',
        refunded_at = now(),
        refund_reason = p_refund_reason
    WHERE id = transaction.id;

    -- Log refund
    INSERT INTO refund_log (
        user_id,
        transaction_id,
        original_purchase_amount,
        credits_deducted,
        refund_reason,
        balance_before,
        balance_after,
        went_negative
    ) VALUES (
        transaction.user_id,
        p_transaction_id,
        transaction.credits_granted,
        LEAST(user_balance, transaction.credits_granted),
        p_refund_reason,
        user_balance,
        GREATEST(0, user_balance - transaction.credits_granted),
        user_balance < transaction.credits_granted
    );

    RETURN jsonb_build_object(
        'success', true,
        'credits_deducted', LEAST(user_balance, transaction.credits_granted)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==========================================
-- ROW LEVEL SECURITY (RLS)
-- ==========================================
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE iap_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

-- Products are publicly readable
CREATE POLICY "Products are publicly readable" ON products
    FOR SELECT USING (is_active = true);

-- Users can only see their own transactions
CREATE POLICY "Users can view own IAP transactions" ON iap_transactions
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can view own subscriptions" ON subscriptions
    FOR SELECT USING (auth.uid() = user_id);
