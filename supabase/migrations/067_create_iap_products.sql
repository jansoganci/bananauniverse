-- =====================================================
-- Migration 067: Create IAP Products Table
-- Purpose: Store credit package definitions for in-app purchases
-- Date: 2025-01-27
-- =====================================================

-- =====================================================
-- PRODUCTS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS products (
    product_id TEXT PRIMARY KEY,  -- Matches App Store product ID (credits_10, etc.)
    
    -- Product info
    name TEXT NOT NULL,
    description TEXT,
    
    -- Credits
    credits INTEGER NOT NULL CHECK (credits > 0),
    bonus_credits INTEGER DEFAULT 0 CHECK (bonus_credits >= 0),
    
    -- Product type
    product_type TEXT DEFAULT 'consumable' CHECK (product_type = 'consumable'),
    
    -- Availability
    is_active BOOLEAN DEFAULT true,
    is_featured BOOLEAN DEFAULT false,
    
    -- Time-based availability (for promotions)
    valid_from TIMESTAMPTZ,
    valid_until TIMESTAMPTZ,
    
    -- UI
    display_order INTEGER DEFAULT 0,
    
    -- Metadata
    metadata JSONB DEFAULT '{}'::jsonb,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_products_active ON products(is_active, display_order);

-- Seed initial products
INSERT INTO products (product_id, name, description, credits, bonus_credits, display_order) VALUES
    ('credits_10', '10 Credits', 'Small credit pack for quick tasks', 10, 0, 1),
    ('credits_25', '25 Credits', 'Standard credit pack', 25, 2, 2),
    ('credits_50', '50 Credits', 'Popular credit pack with bonus', 50, 5, 3),
    ('credits_100', '100 Credits', 'Best value pack with extra credits', 100, 15, 4)
ON CONFLICT (product_id) DO NOTHING;

-- RLS Policies
ALTER TABLE products ENABLE ROW LEVEL SECURITY;

-- Anyone can view active products
CREATE POLICY "Anyone can view active products"
    ON products FOR SELECT
    USING (is_active = true);

-- Service role can manage products
CREATE POLICY "Service role can manage products"
    ON products FOR ALL
    USING (auth.role() = 'service_role');

COMMENT ON TABLE products IS 'Credit package definitions for in-app purchases';
COMMENT ON COLUMN products.product_id IS 'Must match App Store Connect product ID exactly';
COMMENT ON COLUMN products.credits IS 'Base credits granted';
COMMENT ON COLUMN products.bonus_credits IS 'Extra credits (for promotions)';

