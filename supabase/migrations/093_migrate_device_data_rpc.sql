-- =====================================================
-- Migration: Create device data migration RPC
-- Purpose: Move data from device_id to auth.uid() when switching to Anonymous Auth
-- Date: 2025-11-30
-- =====================================================

CREATE OR REPLACE FUNCTION migrate_device_data(p_device_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_credits_moved INTEGER := 0;
    v_jobs_moved INTEGER := 0;
    v_transactions_moved INTEGER := 0;
BEGIN
    -- Get current authenticated user ID
    v_user_id := auth.uid();
    
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
    END IF;

    -- 1. Migrate Credits
    -- Check if target user already has credits
    IF EXISTS (SELECT 1 FROM user_credits WHERE user_id = v_user_id) THEN
        -- Merge logic: Add device credits to existing user credits
        UPDATE user_credits
        SET credits = credits + (
            SELECT COALESCE(credits, 0) 
            FROM user_credits 
            WHERE device_id = p_device_id
        ),
        credits_total = credits_total + (
            SELECT COALESCE(credits_total, 0) 
            FROM user_credits 
            WHERE device_id = p_device_id
        )
        WHERE user_id = v_user_id;
        
        -- Delete old device record
        DELETE FROM user_credits WHERE device_id = p_device_id;
        v_credits_moved := 1; -- Log logical move
    ELSE
        -- Simple move: Assign user_id to device record
        UPDATE user_credits
        SET user_id = v_user_id,
            device_id = NULL -- Clear device_id to avoid future conflicts
        WHERE device_id = p_device_id;
        
        GET DIAGNOSTICS v_credits_moved = ROW_COUNT;
    END IF;

    -- 2. Migrate Job History
    UPDATE job_results
    SET user_id = v_user_id,
        device_id = NULL
    WHERE device_id = p_device_id
      AND user_id IS NULL; -- Only migrate if not already assigned
      
    GET DIAGNOSTICS v_jobs_moved = ROW_COUNT;

    -- 3. Migrate Credit Transactions
    UPDATE credit_transactions
    SET user_id = v_user_id,
        device_id = NULL
    WHERE device_id = p_device_id
      AND user_id IS NULL;
      
    GET DIAGNOSTICS v_transactions_moved = ROW_COUNT;

    RETURN jsonb_build_object(
        'success', true,
        'credits_moved', v_credits_moved,
        'jobs_moved', v_jobs_moved,
        'transactions_moved', v_transactions_moved
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

