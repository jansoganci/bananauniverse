-- Migration: Create rate limiting system for Steve Jobs style processing
-- Author: AI Assistant
-- Date: 2025-10-15
-- Description: Daily request counters for both authenticated and anonymous users

-- Create daily_request_counts table
CREATE TABLE IF NOT EXISTS daily_request_counts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_identifier TEXT NOT NULL, -- user_id or device_id
    user_type TEXT NOT NULL CHECK (user_type IN ('authenticated', 'anonymous')),
    request_date DATE NOT NULL,
    request_count INTEGER DEFAULT 0 CHECK (request_count >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Ensure one record per user per day
    UNIQUE(user_identifier, request_date)
);

-- Create indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_daily_request_counts_user_date ON daily_request_counts(user_identifier, request_date);
CREATE INDEX IF NOT EXISTS idx_daily_request_counts_date ON daily_request_counts(request_date);

-- Enable RLS
ALTER TABLE daily_request_counts ENABLE ROW LEVEL SECURITY;

-- Policy: Service role can manage all rate limit records
CREATE POLICY "Service role can manage rate limits" ON daily_request_counts
    FOR ALL USING (auth.role() = 'service_role');

-- Policy: Users can read their own rate limit records (for transparency)
CREATE POLICY "Users can view own rate limits" ON daily_request_counts
    FOR SELECT USING (
        (user_type = 'authenticated' AND user_identifier = auth.uid()::text) OR
        (user_type = 'anonymous' AND user_identifier = auth.uid()::text)
    );

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger to automatically update updated_at
CREATE TRIGGER update_daily_request_counts_updated_at 
    BEFORE UPDATE ON daily_request_counts 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Add comment
COMMENT ON TABLE daily_request_counts IS 'Daily request counters for rate limiting in Steve Jobs style processing';

-- Example usage:
-- Free users: 5 requests/day
-- Paid users: 100 requests/day
-- Reset at midnight automatically
