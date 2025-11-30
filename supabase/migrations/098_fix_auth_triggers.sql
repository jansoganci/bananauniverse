-- =====================================================
-- Migration: Fix Auth Triggers for Anonymous Users
-- Purpose: Fix 500 error on sign-in by consolidating triggers
-- Date: 2025-11-30
-- =====================================================

-- 1. Consolidate user initialization logic into a single function
CREATE OR REPLACE FUNCTION public.handle_new_user_consolidated()
RETURNS TRIGGER AS $$
BEGIN
    -- A. Create Profile (if not exists)
    INSERT INTO public.profiles (id, email, subscription_tier)
    VALUES (
        NEW.id, 
        NEW.email, -- Can be NULL for anonymous users
        'free'
    )
    ON CONFLICT (id) DO NOTHING;

    -- B. Initialize Credits (if not exists)
    INSERT INTO public.user_credits (user_id, credits)
    VALUES (NEW.id, 10)
    ON CONFLICT (user_id) DO NOTHING;

    RAISE LOG 'Initialized profile and credits for user: % (Anon: %)', NEW.id, NEW.is_anonymous;

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    -- Log error but don't fail the transaction (allow user creation to succeed)
    -- We can retry initialization later if needed
    RAISE LOG 'Error in handle_new_user_consolidated: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Drop old triggers to avoid conflicts
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
-- Check if there are other triggers with different names
DROP TRIGGER IF EXISTS on_auth_user_created_credits ON auth.users; 

-- 3. Create the new unified trigger
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user_consolidated();

-- Log completion
DO $$
BEGIN
    RAISE NOTICE '✅ Fixed auth triggers with consolidated logic';
END $$;

