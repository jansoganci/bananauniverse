-- =====================================================
-- Migration: Create Smart Credit Recovery RPC
-- Purpose: Recover credits from old users or initialize new users
-- Date: 2025-11-30
-- =====================================================

CREATE OR REPLACE FUNCTION recover_or_init_user(p_device_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_current_user_id UUID;
    v_old_user_id UUID;
    v_recovered_credits INTEGER := 0;
    v_recovered_total INTEGER := 0;
    v_jobs_moved INTEGER := 0;
    v_transactions_moved INTEGER := 0;
    v_is_new_device BOOLEAN := FALSE;
BEGIN
    -- Get current authenticated user ID
    v_current_user_id := auth.uid();
    
    IF v_current_user_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false, 
            'error', 'Not authenticated'
        );
    END IF;

    -- Check if this device already exists in the mapping
    SELECT current_user_id INTO v_old_user_id
    FROM device_user_map
    WHERE device_id = p_device_id;

    IF v_old_user_id IS NULL THEN
        -- ========================================
        -- NEW DEVICE: Initialize with 10 credits
        -- ========================================
        v_is_new_device := TRUE;
        
        RAISE LOG '[RECOVERY] New device detected: %', p_device_id;
        
        -- Create initial credit record
        INSERT INTO user_credits (user_id, credits, credits_total)
        VALUES (v_current_user_id, 10, 10)
        ON CONFLICT (user_id) DO UPDATE
        SET credits = 10, credits_total = 10;
        
        -- Create mapping entry
        INSERT INTO device_user_map (device_id, current_user_id)
        VALUES (p_device_id, v_current_user_id);
        
        v_recovered_credits := 10;
        v_recovered_total := 10;
        
        RAISE LOG '[RECOVERY] Initialized new device with 10 credits';
        
    ELSIF v_old_user_id = v_current_user_id THEN
        -- ========================================
        -- SAME USER: Just return current credits
        -- ========================================
        RAISE LOG '[RECOVERY] Same user detected, no transfer needed';
        
        SELECT COALESCE(credits, 0), COALESCE(credits_total, 0)
        INTO v_recovered_credits, v_recovered_total
        FROM user_credits
        WHERE user_id = v_current_user_id;
        
    ELSE
        -- ========================================
        -- EXISTING DEVICE, NEW USER: Transfer everything
        -- ========================================
        RAISE LOG '[RECOVERY] Transferring from old user % to new user %', v_old_user_id, v_current_user_id;
        
        -- 1. Get credits from old user
        SELECT COALESCE(credits, 0), COALESCE(credits_total, 0)
        INTO v_recovered_credits, v_recovered_total
        FROM user_credits
        WHERE user_id = v_old_user_id;
        
        -- 2. Transfer credits to new user
        INSERT INTO user_credits (user_id, credits, credits_total)
        VALUES (v_current_user_id, v_recovered_credits, v_recovered_total)
        ON CONFLICT (user_id) DO UPDATE
        SET credits = v_recovered_credits,
            credits_total = v_recovered_total;
        
        -- 3. Transfer job history
        UPDATE job_results
        SET user_id = v_current_user_id
        WHERE user_id = v_old_user_id;
        
        GET DIAGNOSTICS v_jobs_moved = ROW_COUNT;
        
        -- 4. Transfer credit transactions
        UPDATE credit_transactions
        SET user_id = v_current_user_id
        WHERE user_id = v_old_user_id;
        
        GET DIAGNOSTICS v_transactions_moved = ROW_COUNT;
        
        -- 5. Update device mapping (add old user to history)
        UPDATE device_user_map
        SET current_user_id = v_current_user_id,
            previous_user_ids = array_append(previous_user_ids, v_old_user_id),
            updated_at = NOW()
        WHERE device_id = p_device_id;
        
        -- 6. Delete old user (cascade will clean up remaining records)
        DELETE FROM auth.users WHERE id = v_old_user_id;
        
        RAISE LOG '[RECOVERY] Transfer complete: % credits, % jobs, % transactions', 
            v_recovered_credits, v_jobs_moved, v_transactions_moved;
    END IF;

    -- Return success with recovered credits
    RETURN jsonb_build_object(
        'success', true,
        'is_new_device', v_is_new_device,
        'credits_remaining', v_recovered_credits,
        'credits_total', v_recovered_total,
        'jobs_moved', v_jobs_moved,
        'transactions_moved', v_transactions_moved,
        'old_user_id', v_old_user_id,
        'current_user_id', v_current_user_id
    );

EXCEPTION WHEN OTHERS THEN
    RAISE LOG '[RECOVERY] ERROR: %', SQLERRM;
    RETURN jsonb_build_object(
        'success', false, 
        'error', SQLERRM
    );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION recover_or_init_user(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION recover_or_init_user(TEXT) TO anon;

-- Log completion
DO $$
BEGIN
    RAISE NOTICE '✅ Created recover_or_init_user RPC for StableID-based credit recovery';
END $$;

