-- =====================================================
-- Migration 044: Add Refund Limit (Max 2 Per Day)
-- Purpose: Prevent abuse by limiting refunds to 2 per day
-- Date: November 2, 2025
-- =====================================================

-- =====================================================
-- STEP 1: Add refund_count Column
-- =====================================================
-- Track how many times a request has been refunded
-- This helps prevent infinite refund loops

ALTER TABLE quota_consumption_log
ADD COLUMN IF NOT EXISTS refund_count INTEGER DEFAULT 0;

-- Verify column added
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'quota_consumption_log'
        AND column_name = 'refund_count'
    ) THEN
        RAISE NOTICE '[SCHEMA] Column refund_count added successfully';
    ELSE
        RAISE WARNING '[SCHEMA] Column addition may have failed';
    END IF;
END $$;

-- =====================================================
-- STEP 2: Update refund_quota() with Daily Limit
-- =====================================================
-- Add check for maximum 2 refunds per day per user
-- Skip limit for premium users

CREATE OR REPLACE FUNCTION refund_quota(
    p_user_id UUID DEFAULT NULL,
    p_device_id TEXT DEFAULT NULL,
    p_client_request_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_old_used INTEGER;
    v_new_used INTEGER;
    v_already_refunded BOOLEAN;
    v_refund_count INTEGER;
    v_today_refunds INTEGER;
    v_is_premium BOOLEAN := false;
BEGIN
    -- Validate inputs
    IF p_user_id IS NULL AND p_device_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Identifier required');
    END IF;

    -- ========================================
    -- CHECK PREMIUM STATUS (Skip limit for premium)
    -- ========================================
    SELECT EXISTS(
        SELECT 1 FROM subscriptions
        WHERE (
            (p_user_id IS NOT NULL AND user_id = p_user_id)
            OR (p_device_id IS NOT NULL AND device_id = p_device_id)
        )
        AND status = 'active'
        AND expires_at > NOW()
    ) INTO v_is_premium;

    RAISE LOG '[REFUND] Premium check: user_id=%, device_id=%, is_premium=%',
        p_user_id, p_device_id, v_is_premium;

    -- ========================================
    -- IDEMPOTENCY: Check if already refunded
    -- ========================================
    IF p_client_request_id IS NOT NULL THEN
        SELECT refunded, refund_count
        INTO v_already_refunded, v_refund_count
        FROM quota_consumption_log
        WHERE request_id = p_client_request_id;

        IF v_already_refunded THEN
            RAISE LOG '[REFUND] Already refunded: request_id=%', p_client_request_id;
            RETURN jsonb_build_object(
                'success', true,
                'message', 'Already refunded',
                'idempotent', true,
                'refund_count', v_refund_count
            );
        END IF;
    END IF;

    -- ========================================
    -- REFUND LIMIT: Max 2 refunds per day (free users only)
    -- ========================================
    IF NOT v_is_premium THEN
        -- Count today's refunds for this user
        SELECT COUNT(*)
        INTO v_today_refunds
        FROM quota_consumption_log
        WHERE (
            (p_user_id IS NOT NULL AND user_id = p_user_id)
            OR (p_device_id IS NOT NULL AND device_id = p_device_id)
        )
        AND refunded = true
        AND DATE(consumed_at) = CURRENT_DATE;

        RAISE LOG '[REFUND] Today refunds count: % (limit: 2)', v_today_refunds;

        -- Check limit
        IF v_today_refunds >= 2 THEN
            RAISE LOG '[REFUND] Max refunds exceeded: user_id=%, device_id=%',
                p_user_id, p_device_id;

            RETURN jsonb_build_object(
                'success', false,
                'error', 'Max refunds exceeded (2/day)',
                'refunds_today', v_today_refunds,
                'refunds_limit', 2
            );
        END IF;
    ELSE
        RAISE LOG '[REFUND] Premium user - skipping refund limit';
    END IF;

    -- ========================================
    -- REFUND: Decrement quota (min 0)
    -- ========================================
    UPDATE daily_quotas
    SET
        used = GREATEST(used - 1, 0),
        updated_at = NOW()
    WHERE COALESCE(user_id::text, '') = COALESCE(p_user_id::text, '')
    AND COALESCE(device_id, '') = COALESCE(p_device_id, '')
    AND date = CURRENT_DATE
    RETURNING used + 1, used INTO v_old_used, v_new_used;

    IF NOT FOUND THEN
        RAISE LOG '[REFUND] No quota record found';
        RETURN jsonb_build_object('success', false, 'error', 'No quota to refund');
    END IF;

    -- ========================================
    -- LOG REFUND EVENT (Increment refund_count)
    -- ========================================
    IF p_client_request_id IS NOT NULL THEN
        UPDATE quota_consumption_log
        SET
            refunded = true,
            refunded_at = NOW(),
            refund_count = refund_count + 1
        WHERE request_id = p_client_request_id
        RETURNING refund_count INTO v_refund_count;
    END IF;

    RAISE LOG '[REFUND] Success: %→% for user_id=%, device_id=%, refund_count=%',
        v_old_used, v_new_used, p_user_id, p_device_id, v_refund_count;

    RETURN jsonb_build_object(
        'success', true,
        'quota_refunded', 1,
        'quota_before', v_old_used,
        'quota_after', v_new_used,
        'refund_count', COALESCE(v_refund_count, 1)
    );

EXCEPTION
    WHEN OTHERS THEN
        RAISE LOG '[REFUND] ERROR: %', SQLERRM;
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Ensure proper ownership and permissions
ALTER FUNCTION refund_quota(UUID, TEXT, UUID) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION refund_quota(UUID, TEXT, UUID) TO anon, authenticated, service_role;

-- =====================================================
-- Migration Complete
-- =====================================================
-- ✅ FIX #1 COMPLETE: Refund limit added (max 2 per day)
-- ✅ refund_count column added to quota_consumption_log
-- ✅ refund_quota() updated with daily limit check
--
-- Changes:
--   1. Added refund_count INTEGER column
--   2. Count today's refunds before processing
--   3. Block refund if >= 2 refunds today (free users only)
--   4. Increment refund_count on each refund
--   5. Premium users bypass limit
--
-- Impact:
--   - Prevents abuse (infinite refund loops)
--   - Protects Fal.AI quota from malicious users
--   - Premium users unaffected
--
-- Testing Required:
--   1. Test refund #1: Should succeed ✅
--   2. Test refund #2: Should succeed ✅
--   3. Test refund #3: Should fail with "Max refunds exceeded" ❌
--   4. Test premium user: No limit ✅
--
-- Expected Behavior:
--   - Free users: Max 2 refunds per day
--   - Premium users: Unlimited refunds
--   - Refund count tracked per request
--   - Daily reset at midnight
