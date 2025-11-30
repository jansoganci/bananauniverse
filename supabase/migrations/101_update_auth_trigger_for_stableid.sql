-- =====================================================
-- Migration: Update Auth Trigger for StableID Recovery
-- Purpose: Stop auto-granting credits, let iOS app handle via recover_or_init_user
-- Date: 2025-11-30
-- =====================================================

-- Drop the old trigger function and recreate it
DROP FUNCTION IF EXISTS public.handle_new_user_consolidated() CASCADE;

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

    -- B. DO NOT initialize credits here anymore
    -- Credits will be handled by recover_or_init_user RPC called from iOS
    -- This prevents the "10 free credits on every new user" bug

    RAISE LOG 'Created profile for user: % (Anon: %) - Credits will be initialized by app', NEW.id, NEW.is_anonymous;

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    -- Log error but don't fail the transaction (allow user creation to succeed)
    RAISE LOG 'Error in handle_new_user_consolidated: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate the trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user_consolidated();

-- Log completion
DO $$
BEGIN
    RAISE NOTICE '✅ Updated auth trigger - credits now managed by StableID recovery system';
END $$;

