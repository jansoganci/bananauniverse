-- Migration: Add self-healing logic to quota validation functions
-- Author: AI Assistant
-- Date: 2025-10-22
-- Description: Updates quota validation functions to automatically create missing credit records

-- Function to validate daily quota for authenticated users (WITH SELF-HEALING)
CREATE OR REPLACE FUNCTION validate_user_daily_quota(
    p_user_id UUID,
    p_is_premium BOOLEAN DEFAULT FALSE
)
RETURNS JSONB AS $$
DECLARE
    v_credits INTEGER;
    v_quota_used INTEGER;
    v_quota_limit INTEGER;
    v_last_reset TIMESTAMPTZ;
    v_today DATE;
    v_result JSONB;
    v_record_created BOOLEAN := FALSE;
BEGIN
    -- Get current date in UTC
    v_today := CURRENT_DATE;
    
    -- Get user credits and quota info
    SELECT 
        credits,
        daily_quota_used,
        daily_quota_limit,
        last_quota_reset
    INTO 
        v_credits,
        v_quota_used,
        v_quota_limit,
        v_last_reset
    FROM user_credits
    WHERE user_id = p_user_id;
    
    -- SELF-HEALING: If no record found, create it automatically
    IF NOT FOUND THEN
        BEGIN
            INSERT INTO user_credits (
                user_id,
                credits,
                daily_quota_used,
                daily_quota_limit,
                last_quota_reset,
                created_at,
                updated_at
            ) VALUES (
                p_user_id,
                10, -- FREE_CREDITS default
                0,
                5,
                NOW(),
                NOW(),
                NOW()
            )
            ON CONFLICT (user_id) DO NOTHING;
            
            -- Fetch the newly created record
            SELECT 
                credits,
                daily_quota_used,
                daily_quota_limit,
                last_quota_reset
            INTO 
                v_credits,
                v_quota_used,
                v_quota_limit,
                v_last_reset
            FROM user_credits
            WHERE user_id = p_user_id;
            
            v_record_created := TRUE;
            
            RAISE LOG '[STEVE-JOBS] Self-healed missing user_credits record for user_id: %', p_user_id;
            
        EXCEPTION
            WHEN OTHERS THEN
                -- If insert fails (e.g., race condition), try to fetch again
                SELECT 
                    credits,
                    daily_quota_used,
                    daily_quota_limit,
                    last_quota_reset
                INTO 
                    v_credits,
                    v_quota_used,
                    v_quota_limit,
                    v_last_reset
                FROM user_credits
                WHERE user_id = p_user_id;
                
                IF NOT FOUND THEN
                    -- Still not found after retry - return error
                    RETURN jsonb_build_object(
                        'valid', false,
                        'error', 'Failed to create user credits record',
                        'credits', 0,
                        'quota_used', 0,
                        'quota_limit', 0,
                        'quota_remaining', 0
                    );
                END IF;
        END;
    END IF;
    
    -- Check if quota needs reset (different day)
    IF DATE(v_last_reset) < v_today THEN
        -- Reset quota for new day
        UPDATE user_credits 
        SET 
            daily_quota_used = 0,
            last_quota_reset = NOW()
        WHERE user_id = p_user_id;
        
        v_quota_used := 0;
    END IF;
    
    -- Check if user can process
    IF v_credits <= 0 THEN
        v_result := jsonb_build_object(
            'valid', false,
            'error', 'Insufficient credits',
            'credits', v_credits,
            'quota_used', v_quota_used,
            'quota_limit', v_quota_limit,
            'quota_remaining', v_quota_limit - v_quota_used
        );
    ELSIF p_is_premium THEN
        -- Premium users bypass quota
        v_result := jsonb_build_object(
            'valid', true,
            'error', NULL,
            'credits', v_credits,
            'quota_used', v_quota_used,
            'quota_limit', v_quota_limit,
            'quota_remaining', v_quota_limit - v_quota_used,
            'premium_bypass', true,
            'self_healed', v_record_created
        );
    ELSIF v_quota_used >= v_quota_limit THEN
        -- Quota exceeded
        v_result := jsonb_build_object(
            'valid', false,
            'error', 'Daily quota exceeded',
            'credits', v_credits,
            'quota_used', v_quota_used,
            'quota_limit', v_quota_limit,
            'quota_remaining', 0
        );
    ELSE
        -- Valid to process
        v_result := jsonb_build_object(
            'valid', true,
            'error', NULL,
            'credits', v_credits,
            'quota_used', v_quota_used,
            'quota_limit', v_quota_limit,
            'quota_remaining', v_quota_limit - v_quota_used,
            'self_healed', v_record_created
        );
    END IF;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to validate daily quota for anonymous users (WITH SELF-HEALING)
CREATE OR REPLACE FUNCTION validate_anonymous_daily_quota(
    p_device_id TEXT,
    p_is_premium BOOLEAN DEFAULT FALSE
)
RETURNS JSONB AS $$
DECLARE
    v_credits INTEGER;
    v_quota_used INTEGER;
    v_quota_limit INTEGER;
    v_last_reset TIMESTAMPTZ;
    v_today DATE;
    v_result JSONB;
    v_record_created BOOLEAN := FALSE;
BEGIN
    -- Get current date in UTC
    v_today := CURRENT_DATE;
    
    -- Get anonymous credits and quota info
    SELECT 
        credits,
        daily_quota_used,
        daily_quota_limit,
        last_quota_reset
    INTO 
        v_credits,
        v_quota_used,
        v_quota_limit,
        v_last_reset
    FROM anonymous_credits
    WHERE device_id = p_device_id;
    
    -- SELF-HEALING: If no record found, create it automatically
    IF NOT FOUND THEN
        BEGIN
            INSERT INTO anonymous_credits (
                device_id,
                credits,
                daily_quota_used,
                daily_quota_limit,
                last_quota_reset,
                created_at,
                updated_at
            ) VALUES (
                p_device_id,
                10, -- FREE_CREDITS default
                0,
                5,
                NOW(),
                NOW(),
                NOW()
            )
            ON CONFLICT (device_id) DO NOTHING;
            
            -- Fetch the newly created record
            SELECT 
                credits,
                daily_quota_used,
                daily_quota_limit,
                last_quota_reset
            INTO 
                v_credits,
                v_quota_used,
                v_quota_limit,
                v_last_reset
            FROM anonymous_credits
            WHERE device_id = p_device_id;
            
            v_record_created := TRUE;
            
            RAISE LOG '[STEVE-JOBS] Self-healed missing anonymous_credits record for device_id: %', p_device_id;
            
        EXCEPTION
            WHEN OTHERS THEN
                -- If insert fails (e.g., race condition), try to fetch again
                SELECT 
                    credits,
                    daily_quota_used,
                    daily_quota_limit,
                    last_quota_reset
                INTO 
                    v_credits,
                    v_quota_used,
                    v_quota_limit,
                    v_last_reset
                FROM anonymous_credits
                WHERE device_id = p_device_id;
                
                IF NOT FOUND THEN
                    -- Still not found after retry - return error
                    RETURN jsonb_build_object(
                        'valid', false,
                        'error', 'Failed to create anonymous credits record',
                        'credits', 0,
                        'quota_used', 0,
                        'quota_limit', 0,
                        'quota_remaining', 0
                    );
                END IF;
        END;
    END IF;
    
    -- Check if quota needs reset (different day)
    IF DATE(v_last_reset) < v_today THEN
        -- Reset quota for new day
        UPDATE anonymous_credits 
        SET 
            daily_quota_used = 0,
            last_quota_reset = NOW()
        WHERE device_id = p_device_id;
        
        v_quota_used := 0;
    END IF;
    
    -- Check if user can process
    IF v_credits <= 0 THEN
        v_result := jsonb_build_object(
            'valid', false,
            'error', 'Insufficient credits',
            'credits', v_credits,
            'quota_used', v_quota_used,
            'quota_limit', v_quota_limit,
            'quota_remaining', v_quota_limit - v_quota_used
        );
    ELSIF p_is_premium THEN
        -- Premium users bypass quota
        v_result := jsonb_build_object(
            'valid', true,
            'error', NULL,
            'credits', v_credits,
            'quota_used', v_quota_used,
            'quota_limit', v_quota_limit,
            'quota_remaining', v_quota_limit - v_quota_used,
            'premium_bypass', true,
            'self_healed', v_record_created
        );
    ELSIF v_quota_used >= v_quota_limit THEN
        -- Quota exceeded
        v_result := jsonb_build_object(
            'valid', false,
            'error', 'Daily quota exceeded',
            'credits', v_credits,
            'quota_used', v_quota_used,
            'quota_limit', v_quota_limit,
            'quota_remaining', 0
        );
    ELSE
        -- Valid to process
        v_result := jsonb_build_object(
            'valid', true,
            'error', NULL,
            'credits', v_credits,
            'quota_used', v_quota_used,
            'quota_limit', v_quota_limit,
            'quota_remaining', v_quota_limit - v_quota_used,
            'self_healed', v_record_created
        );
    END IF;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Re-grant execute permissions (just to be safe)
GRANT EXECUTE ON FUNCTION validate_user_daily_quota(UUID, BOOLEAN) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION validate_anonymous_daily_quota(TEXT, BOOLEAN) TO authenticated, anon;

-- Add comments for documentation
COMMENT ON FUNCTION validate_user_daily_quota IS 'Validates daily quota for authenticated users with self-healing for missing records';
COMMENT ON FUNCTION validate_anonymous_daily_quota IS 'Validates daily quota for anonymous users with self-healing for missing records';

