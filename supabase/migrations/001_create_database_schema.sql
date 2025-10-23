-- =====================================================
-- Database Schema for noname_banana AI Processing
-- =====================================================
--
-- This migration is IDEMPOTENT - safe to run multiple times
-- It will create tables/functions if they don't exist
-- and replace/update existing ones without errors
--
-- =====================================================

-- 1. Create profiles table
CREATE TABLE IF NOT EXISTS profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  email TEXT,
  subscription_tier TEXT DEFAULT 'free' CHECK (subscription_tier IN ('free', 'pro')),
  requests_used_today INTEGER DEFAULT 0,
  requests_used_this_month INTEGER DEFAULT 0,
  last_reset_date DATE DEFAULT CURRENT_DATE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Create jobs table
CREATE TABLE IF NOT EXISTS jobs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  model TEXT NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
  input_url TEXT,
  output_url TEXT,
  options JSONB DEFAULT '{}'::jsonb,
  error_message TEXT,
  fal_request_id TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  completed_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Enable RLS on tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE jobs ENABLE ROW LEVEL SECURITY;

-- 4. Create RLS policies for profiles (drop first if exists)
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
CREATE POLICY "Users can view own profile"
  ON profiles FOR SELECT
  USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

-- 5. Create RLS policies for jobs (drop first if exists)
DROP POLICY IF EXISTS "Users can view own jobs" ON jobs;
CREATE POLICY "Users can view own jobs"
  ON jobs FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can create own jobs" ON jobs;
CREATE POLICY "Users can create own jobs"
  ON jobs FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- 6. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_jobs_user_id ON jobs(user_id);
CREATE INDEX IF NOT EXISTS idx_jobs_status ON jobs(status);
CREATE INDEX IF NOT EXISTS idx_jobs_created_at ON jobs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_profiles_subscription_tier ON profiles(subscription_tier);

-- 7. Create function to auto-create profile on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, subscription_tier)
  VALUES (NEW.id, NEW.email, 'free')
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. Create trigger for auto-profile creation
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 9. Create function to reset daily counters
CREATE OR REPLACE FUNCTION public.reset_daily_counters()
RETURNS void AS $$
BEGIN
  UPDATE profiles
  SET 
    requests_used_today = 0,
    last_reset_date = CURRENT_DATE
  WHERE last_reset_date < CURRENT_DATE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 10. Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 11. Create triggers for updated_at
DROP TRIGGER IF EXISTS update_profiles_updated_at ON profiles;
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_jobs_updated_at ON jobs;
CREATE TRIGGER update_jobs_updated_at
  BEFORE UPDATE ON jobs
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- 12. Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON profiles TO authenticated;
GRANT ALL ON jobs TO authenticated;

-- 13. Create view for job statistics (optional, useful for analytics)
CREATE OR REPLACE VIEW job_stats AS
SELECT 
  user_id,
  COUNT(*) as total_jobs,
  COUNT(*) FILTER (WHERE status = 'completed') as completed_jobs,
  COUNT(*) FILTER (WHERE status = 'failed') as failed_jobs,
  COUNT(*) FILTER (WHERE status = 'processing') as processing_jobs,
  COUNT(*) FILTER (WHERE status = 'pending') as pending_jobs
FROM jobs
GROUP BY user_id;

-- 14. Grant access to view
GRANT SELECT ON job_stats TO authenticated;

-- Done! Schema is ready for use.

