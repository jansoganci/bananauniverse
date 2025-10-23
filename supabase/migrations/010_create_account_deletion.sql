-- =====================================================
-- Account Deletion Function
-- =====================================================
-- Migration: Create comprehensive account deletion RPC function
-- Author: AI Assistant
-- Date: 2025-01-XX
-- Description: Handles complete user account deletion with security and audit

-- Create comprehensive account deletion function
CREATE OR REPLACE FUNCTION public.delete_user_account(user_id UUID)
RETURNS JSONB AS $$
DECLARE
    current_user_id UUID;
    user_storage_paths TEXT[];
    deleted_files_count INTEGER := 0;
    result JSONB;
BEGIN
    -- Security: Verify the calling user matches the user_id parameter
    current_user_id := auth.uid();
    
    IF current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;
    
    IF current_user_id != user_id THEN
        RAISE EXCEPTION 'Unauthorized: Can only delete your own account';
    END IF;
    
    -- Verify the user exists
    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = user_id) THEN
        RAISE EXCEPTION 'User not found';
    END IF;
    
    -- Get all storage paths for this user's images
    SELECT ARRAY_AGG(output_url) INTO user_storage_paths
    FROM jobs 
    WHERE user_id = delete_user_account.user_id 
    AND output_url IS NOT NULL
    AND output_url != '';
    
    -- Delete user's images from storage
    IF user_storage_paths IS NOT NULL THEN
        FOR i IN 1..array_length(user_storage_paths, 1) LOOP
            BEGIN
                PERFORM storage.delete_object('processed-images', user_storage_paths[i]);
                deleted_files_count := deleted_files_count + 1;
            EXCEPTION WHEN OTHERS THEN
                -- Log error but continue with deletion
                RAISE WARNING 'Failed to delete storage file: %', user_storage_paths[i];
            END;
        END LOOP;
    END IF;
    
    -- Clean up non-cascaded tables manually
    DELETE FROM daily_request_counts WHERE user_id = user_id;
    DELETE FROM cleanup_logs WHERE details->>'user_id' = user_id::TEXT;
    
    -- Delete auth user (CASCADE will handle: profiles, user_credits, credit_transactions, jobs)
    DELETE FROM auth.users WHERE id = user_id;
    
    -- Log the deletion for audit purposes
    INSERT INTO cleanup_logs (operation, details, created_at)
    VALUES (
        'account_deletion', 
        json_build_object(
            'user_id', user_id,
            'deleted_by', current_user_id,
            'files_deleted', deleted_files_count,
            'timestamp', NOW()
        ), 
        NOW()
    );
    
    -- Return success result
    result := json_build_object(
        'success', true,
        'user_id', user_id,
        'files_deleted', deleted_files_count,
        'timestamp', NOW()
    );
    
    RETURN result;
    
EXCEPTION WHEN OTHERS THEN
    -- Log error and re-raise
    INSERT INTO cleanup_logs (operation, details, created_at)
    VALUES (
        'account_deletion_error', 
        json_build_object(
            'user_id', user_id,
            'error', SQLERRM,
            'timestamp', NOW()
        ), 
        NOW()
    );
    
    RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.delete_user_account(UUID) TO authenticated;

-- Add comment for documentation
COMMENT ON FUNCTION public.delete_user_account(UUID) IS 'Safely deletes user account and all associated data including storage files';
