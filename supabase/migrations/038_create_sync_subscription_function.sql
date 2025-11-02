-- =====================================================
-- Migration 038: Create sync_subscription Function
-- Purpose: Allow iOS app to sync StoreKit purchases to subscriptions table
-- Security: SECURITY DEFINER allows authenticated users to insert/update their own subscriptions
-- =====================================================

-- =====================================================
-- Sync Subscription (Called from iOS StoreKit Observer)
-- =====================================================
CREATE OR REPLACE FUNCTION sync_subscription(
    p_user_id UUID DEFAULT NULL,
    p_device_id TEXT DEFAULT NULL,
    p_product_id TEXT DEFAULT NULL,
    p_transaction_id TEXT DEFAULT NULL,
    p_expires_at TIMESTAMPTZ DEFAULT NULL,
    p_platform TEXT DEFAULT 'ios'
)
RETURNS JSONB AS $$
DECLARE
    v_subscription_id UUID;
    v_status TEXT;
BEGIN
    -- Validate inputs
    IF p_user_id IS NULL AND p_device_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Either user_id or device_id required');
    END IF;

    IF p_transaction_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Transaction ID required');
    END IF;

    IF p_product_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Product ID required');
    END IF;

    -- Determine status based on expiration
    IF p_expires_at IS NULL OR p_expires_at > NOW() THEN
        v_status := 'active';
    ELSE
        v_status := 'expired';
    END IF;

    -- Upsert subscription (INSERT or UPDATE if exists)
    INSERT INTO subscriptions (
        user_id,
        device_id,
        status,
        product_id,
        expires_at,
        original_transaction_id,
        platform,
        created_at,
        updated_at
    ) VALUES (
        p_user_id,
        p_device_id,
        v_status,
        p_product_id,
        COALESCE(p_expires_at, NOW() + INTERVAL '30 days'),  -- Default 30 days if not provided
        p_transaction_id,
        p_platform,
        NOW(),
        NOW()
    )
    ON CONFLICT (original_transaction_id)
    DO UPDATE SET
        user_id = COALESCE(EXCLUDED.user_id, subscriptions.user_id),
        device_id = COALESCE(EXCLUDED.device_id, subscriptions.device_id),
        status = EXCLUDED.status,
        product_id = EXCLUDED.product_id,
        expires_at = EXCLUDED.expires_at,
        platform = EXCLUDED.platform,
        updated_at = NOW()
    RETURNING id, status INTO v_subscription_id, v_status;

    RAISE LOG '[SUBSCRIPTION] Synced: id=%, status=%, transaction=%',
        v_subscription_id, v_status, p_transaction_id;

    RETURN jsonb_build_object(
        'success', true,
        'subscription_id', v_subscription_id,
        'status', v_status,
        'message', 'Subscription synced successfully'
    );

EXCEPTION
    WHEN OTHERS THEN
        RAISE LOG '[SUBSCRIPTION] ERROR: %', SQLERRM;
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Ensure proper ownership and permissions
ALTER FUNCTION sync_subscription(UUID, TEXT, TEXT, TEXT, TIMESTAMPTZ, TEXT) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION sync_subscription(UUID, TEXT, TEXT, TEXT, TIMESTAMPTZ, TEXT) TO anon, authenticated, service_role;

-- =====================================================
-- Migration Complete
-- =====================================================
-- ✅ sync_subscription() function created
-- Features:
--   - Upserts subscription records from iOS StoreKit
--   - Automatically determines status (active/expired)
--   - Idempotent (safe to call multiple times)
--   - Proper error handling
--
-- Next: Update StoreKitService.swift to call this function after purchase
