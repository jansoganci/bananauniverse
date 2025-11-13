-- =====================================================
-- Migration 062: Activate Credit System
-- Purpose: Enable persistent credit balance system
-- Date: 2025-11-13
-- =====================================================

-- =====================================================
-- STEP 1: Set Default Credits for New Users
-- =====================================================

-- Set default credits to 10 for new authenticated users
ALTER TABLE user_credits ALTER COLUMN credits SET DEFAULT 10;

-- Set default credits to 10 for new anonymous users
ALTER TABLE anonymous_credits ALTER COLUMN credits SET DEFAULT 10;

-- =====================================================
-- STEP 2: Initialize Credits for Existing Users
-- =====================================================

-- Give all existing users 10 credits (one-time migration)
-- This ensures no user starts with 0 credits
DO $$
BEGIN
    INSERT INTO user_credits (user_id, credits)
    SELECT id, 10
    FROM auth.users
    WHERE id NOT IN (SELECT user_id FROM user_credits)
    ON CONFLICT (user_id) DO NOTHING;

    RAISE NOTICE 'Initialized credits for existing users';
END $$;

-- =====================================================
-- STEP 3: Create Trigger to Auto-Initialize Credits
-- =====================================================

-- Function to initialize credits when new user signs up
CREATE OR REPLACE FUNCTION initialize_user_credits()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO user_credits (user_id, credits)
    VALUES (NEW.id, 10)
    ON CONFLICT (user_id) DO NOTHING;

    RAISE LOG '[CREDITS] Initialized 10 credits for new user: %', NEW.id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if exists
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Create trigger on user signup
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION initialize_user_credits();

DO $$
BEGIN
    RAISE NOTICE 'Created trigger to auto-initialize credits on signup';
END $$;

-- =====================================================
-- STEP 4: Update RLS Policies for Credits
-- =====================================================

-- Enable RLS on anonymous_credits (currently not enabled)
ALTER TABLE anonymous_credits ENABLE ROW LEVEL SECURITY;

-- Policy: Anonymous users can read their own credits using device_id
DROP POLICY IF EXISTS "anon_select_own_credits" ON anonymous_credits;
CREATE POLICY "anon_select_own_credits"
    ON anonymous_credits
    FOR SELECT
    USING (
        device_id IS NOT NULL
        AND device_id = current_setting('request.device_id', true)
    );

-- Policy: Anonymous users can update their own credits
DROP POLICY IF EXISTS "anon_update_own_credits" ON anonymous_credits;
CREATE POLICY "anon_update_own_credits"
    ON anonymous_credits
    FOR UPDATE
    USING (
        device_id IS NOT NULL
        AND device_id = current_setting('request.device_id', true)
    );

-- Policy: Anonymous users can insert their own credits record
DROP POLICY IF EXISTS "anon_insert_own_credits" ON anonymous_credits;
CREATE POLICY "anon_insert_own_credits"
    ON anonymous_credits
    FOR INSERT
    WITH CHECK (device_id IS NOT NULL);

-- Service role can do anything (for Edge Functions)
DROP POLICY IF EXISTS "service_role_all_credits" ON user_credits;
CREATE POLICY "service_role_all_credits"
    ON user_credits
    FOR ALL
    USING (auth.role() = 'service_role');

DROP POLICY IF EXISTS "service_role_all_anon_credits" ON anonymous_credits;
CREATE POLICY "service_role_all_anon_credits"
    ON anonymous_credits
    FOR ALL
    USING (auth.role() = 'service_role');

DO $$
BEGIN
    RAISE NOTICE 'Updated RLS policies for credit tables';
END $$;

-- =====================================================
-- STEP 5: Add Indexes for Performance
-- =====================================================

-- Already created in migration 002, but ensure they exist
CREATE INDEX IF NOT EXISTS idx_user_credits_user_id ON user_credits(user_id);
CREATE INDEX IF NOT EXISTS idx_anonymous_credits_device_id ON anonymous_credits(device_id);

-- Add index for created_at for cleanup queries
CREATE INDEX IF NOT EXISTS idx_anonymous_credits_created_at ON anonymous_credits(created_at);

DO $$
BEGIN
    RAISE NOTICE 'Ensured indexes exist for credit tables';
END $$;

-- =====================================================
-- STEP 6: Verification
-- =====================================================

DO $$
DECLARE
    v_user_count INTEGER;
    v_credit_count INTEGER;
BEGIN
    -- Count users
    SELECT COUNT(*) INTO v_user_count FROM auth.users;

    -- Count credit records
    SELECT COUNT(*) INTO v_credit_count FROM user_credits;

    RAISE NOTICE '========================================';
    RAISE NOTICE 'Credit System Activation Complete';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Total users: %', v_user_count;
    RAISE NOTICE 'Users with credits: %', v_credit_count;
    RAISE NOTICE 'Default credits for new users: 10';
    RAISE NOTICE 'Auto-initialization trigger: ACTIVE';
    RAISE NOTICE '========================================';

    -- Verify trigger exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'on_auth_user_created'
    ) THEN
        RAISE EXCEPTION 'Trigger on_auth_user_created not created!';
    END IF;

    RAISE NOTICE '✅ SUCCESS: Credit system is now active!';
END $$;

-- =====================================================
-- Migration Complete
-- =====================================================
-- ✅ Default credits set to 10
-- ✅ Existing users initialized with 10 credits
-- ✅ Auto-initialization trigger created
-- ✅ RLS policies updated for anonymous users
-- ✅ Indexes optimized
-- ✅ Service role access granted
--
-- Next: Migration 063 - Remove daily quota system
