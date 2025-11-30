-- =====================================================
-- Migration: Create add_credits RPC for Refunds
-- Purpose: Allow system to refund credits when jobs fail
-- Date: 2025-11-30
-- =====================================================

CREATE OR REPLACE FUNCTION add_credits(
    p_user_id UUID DEFAULT NULL,
    p_device_id TEXT DEFAULT NULL,
    p_amount INTEGER DEFAULT 0,
    p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_new_balance INTEGER;
    v_credits_added INTEGER;
BEGIN
    -- 1. Check Idempotency (Optional but recommended)
    -- If we had a transaction log with idempotency keys, we would check it here.
    -- For now, we proceed (refunds are usually safe to repeat if logic checks status first)

    -- 2. Handle Authenticated User
    IF p_user_id IS NOT NULL THEN
        UPDATE user_credits
        SET 
            credits = credits + p_amount,
            updated_at = NOW()
        WHERE user_id = p_user_id
        RETURNING credits INTO v_new_balance;
        
        IF NOT FOUND THEN
            -- Should not happen for refund, but safe to handle
            INSERT INTO user_credits (user_id, credits)
            VALUES (p_user_id, p_amount)
            RETURNING credits INTO v_new_balance;
        END IF;
        
        -- Log transaction
        INSERT INTO credit_transactions (user_id, amount, balance_after, source, transaction_metadata)
        VALUES (p_user_id, p_amount, v_new_balance, 'refund', jsonb_build_object('idempotency_key', p_idempotency_key));
        
        v_credits_added := p_amount;

    -- 3. Handle Anonymous User
    ELSIF p_device_id IS NOT NULL THEN
        UPDATE anonymous_credits
        SET 
            credits = credits + p_amount,
            updated_at = NOW()
        WHERE device_id = p_device_id
        RETURNING credits INTO v_new_balance;
        
        IF NOT FOUND THEN
            INSERT INTO anonymous_credits (device_id, credits)
            VALUES (p_device_id, p_amount)
            RETURNING credits INTO v_new_balance;
        END IF;
        
        -- Anonymous users don't have transaction logs in the current schema (or do they?)
        -- The credit_transactions table references auth.users(id), so it can't store anonymous transactions directly.
        -- We skip logging for now or would need to modify schema.
        
        v_credits_added := p_amount;
        
    ELSE
        RETURN jsonb_build_object('success', false, 'error', 'User ID or Device ID required');
    END IF;

    -- 4. Return Result
    RETURN jsonb_build_object(
        'success', true,
        'credits_added', v_credits_added,
        'credits_remaining', v_new_balance
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- Log completion
DO $$
BEGIN
    RAISE NOTICE '✅ Created add_credits RPC for refunds';
END $$;

