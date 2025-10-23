-- Migration: Add daily quota validation RPC functions
-- Author: AI Assistant
-- Date: 2025-01-27
-- Description: Creates RPC functions for daily quota validation and management

-- Function to validate daily quota for authenticated users
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
    
    -- If no record found, return error
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'valid', false,
            'error', 'User credits record not found',
            'credits', 0,
            'quota_used', 0,
            'quota_limit', 0,
            'quota_remaining', 0
        );
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
            'premium_bypass', true
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
            'quota_remaining', v_quota_limit - v_quota_used
        );
    END IF;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to validate daily quota for anonymous users
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
    
    -- If no record found, return error
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'valid', false,
            'error', 'Anonymous credits record not found',
            'credits', 0,
            'quota_used', 0,
            'quota_limit', 0,
            'quota_remaining', 0
        );
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
            'premium_bypass', true
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
            'quota_remaining', v_quota_limit - v_quota_used
        );
    END IF;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to consume credit and increment quota
CREATE OR REPLACE FUNCTION consume_credit_with_quota(
    p_user_id UUID DEFAULT NULL,
    p_device_id TEXT DEFAULT NULL,
    p_is_premium BOOLEAN DEFAULT FALSE
)
RETURNS JSONB AS $$
DECLARE
    v_credits INTEGER;
    v_quota_used INTEGER;
    v_quota_limit INTEGER;
    v_result JSONB;
BEGIN
    -- Validate quota first
    IF p_user_id IS NOT NULL THEN
        v_result := validate_user_daily_quota(p_user_id, p_is_premium);
    ELSIF p_device_id IS NOT NULL THEN
        v_result := validate_anonymous_daily_quota(p_device_id, p_is_premium);
    ELSE
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Either user_id or device_id must be provided'
        );
    END IF;
    
    -- Check if validation passed
    IF NOT (v_result->>'valid')::BOOLEAN THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', v_result->>'error',
            'credits', (v_result->>'credits')::INTEGER,
            'quota_used', (v_result->>'quota_used')::INTEGER,
            'quota_limit', (v_result->>'quota_limit')::INTEGER,
            'quota_remaining', (v_result->>'quota_remaining')::INTEGER
        );
    END IF;
    
    -- Consume credit and update quota
    IF p_user_id IS NOT NULL THEN
        -- Update user credits
        UPDATE user_credits 
        SET 
            credits = credits - 1,
            daily_quota_used = CASE 
                WHEN p_is_premium THEN daily_quota_used 
                ELSE daily_quota_used + 1 
            END,
            updated_at = NOW()
        WHERE user_id = p_user_id
        RETURNING credits, daily_quota_used INTO v_credits, v_quota_used;
    ELSE
        -- Update anonymous credits
        UPDATE anonymous_credits 
        SET 
            credits = credits - 1,
            daily_quota_used = CASE 
                WHEN p_is_premium THEN daily_quota_used 
                ELSE daily_quota_used + 1 
            END,
            updated_at = NOW()
        WHERE device_id = p_device_id
        RETURNING credits, daily_quota_used INTO v_credits, v_quota_used;
    END IF;
    
    -- Get quota limit for response
    IF p_user_id IS NOT NULL THEN
        SELECT daily_quota_limit INTO v_quota_limit FROM user_credits WHERE user_id = p_user_id;
    ELSE
        SELECT daily_quota_limit INTO v_quota_limit FROM anonymous_credits WHERE device_id = p_device_id;
    END IF;
    
    RETURN jsonb_build_object(
        'success', true,
        'error', NULL,
        'credits', v_credits,
        'quota_used', v_quota_used,
        'quota_limit', v_quota_limit,
        'quota_remaining', v_quota_limit - v_quota_used,
        'premium_bypass', p_is_premium
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION validate_user_daily_quota(UUID, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION validate_anonymous_daily_quota(TEXT, BOOLEAN) TO anon;
GRANT EXECUTE ON FUNCTION consume_credit_with_quota(UUID, TEXT, BOOLEAN) TO authenticated, anon;

-- Add comments for documentation
COMMENT ON FUNCTION validate_user_daily_quota IS 'Validates daily quota for authenticated users';
COMMENT ON FUNCTION validate_anonymous_daily_quota IS 'Validates daily quota for anonymous users';
COMMENT ON FUNCTION consume_credit_with_quota IS 'Consumes credit and increments quota usage';
