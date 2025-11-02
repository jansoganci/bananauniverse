-- =====================================================
-- Migration 037: Create refund_quota Function
-- Purpose: Refund quota when AI processing fails
-- Security: Idempotent (won't refund twice)
-- =====================================================

-- =====================================================
-- Refund Quota (Called on AI Processing Failures)
-- =====================================================
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
BEGIN
    -- Validate inputs
    IF p_user_id IS NULL AND p_device_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Identifier required');
    END IF;

    -- ========================================
    -- IDEMPOTENCY: Check if already refunded
    -- ========================================
    IF p_client_request_id IS NOT NULL THEN
        SELECT refunded INTO v_already_refunded
        FROM quota_consumption_log
        WHERE request_id = p_client_request_id;

        IF v_already_refunded THEN
            RAISE LOG '[REFUND] Already refunded: request_id=%', p_client_request_id;
            RETURN jsonb_build_object(
                'success', true,
                'message', 'Already refunded',
                'idempotent', true
            );
        END IF;
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
    -- LOG REFUND EVENT
    -- ========================================
    IF p_client_request_id IS NOT NULL THEN
        UPDATE quota_consumption_log
        SET
            refunded = true,
            refunded_at = NOW()
        WHERE request_id = p_client_request_id;
    END IF;

    RAISE LOG '[REFUND] Success: %→% for user_id=%, device_id=%',
        v_old_used, v_new_used, p_user_id, p_device_id;

    RETURN jsonb_build_object(
        'success', true,
        'quota_refunded', 1,
        'quota_before', v_old_used,
        'quota_after', v_new_used
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
-- ✅ refund_quota() function created
-- Features:
--   - Idempotent (won't refund twice for same request_id)
--   - Decrements quota (min 0)
--   - Logs refund events
--   - Proper error handling
--
-- Next: Update Edge Function to call refund on Fal.AI errors
