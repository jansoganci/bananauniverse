-- Migration 017: Create simplified daily quota system

-- 1. Main quota table
CREATE TABLE daily_quotas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id TEXT,
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    used INTEGER DEFAULT 0 CHECK (used >= 0),
    limit_value INTEGER DEFAULT 5 CHECK (limit_value > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Ensure one row per user/device per day
    UNIQUE(user_id, device_id, date)
);

-- Indexes for performance
CREATE INDEX idx_daily_quotas_user ON daily_quotas(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_daily_quotas_device ON daily_quotas(device_id) WHERE device_id IS NOT NULL;
CREATE INDEX idx_daily_quotas_date ON daily_quotas(date);

-- 2. Audit log (for debugging)
CREATE TABLE quota_consumption_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    request_id UUID UNIQUE NOT NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    device_id TEXT,
    consumed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    quota_used INTEGER NOT NULL,
    quota_limit INTEGER NOT NULL,
    success BOOLEAN NOT NULL,
    error_message TEXT
);

CREATE INDEX idx_quota_log_request ON quota_consumption_log(request_id);
CREATE INDEX idx_quota_log_user ON quota_consumption_log(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_quota_log_device ON quota_consumption_log(device_id) WHERE device_id IS NOT NULL;
CREATE INDEX idx_quota_log_date ON quota_consumption_log(consumed_at DESC);

-- 3. Enable RLS
ALTER TABLE daily_quotas ENABLE ROW LEVEL SECURITY;
ALTER TABLE quota_consumption_log ENABLE ROW LEVEL SECURITY;

-- RLS Policies for authenticated users
CREATE POLICY "users_select_own_quota" ON daily_quotas
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "users_insert_own_quota" ON daily_quotas
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users_update_own_quota" ON daily_quotas
    FOR UPDATE USING (auth.uid() = user_id);

-- RLS Policies for anonymous users (via device_id header)
CREATE POLICY "anon_select_device_quota" ON daily_quotas
    FOR SELECT USING (
        device_id IS NOT NULL 
        AND device_id = current_setting('request.device_id', true)
    );

CREATE POLICY "anon_insert_device_quota" ON daily_quotas
    FOR INSERT WITH CHECK (
        device_id IS NOT NULL 
        AND device_id = current_setting('request.device_id', true)
    );

CREATE POLICY "anon_update_device_quota" ON daily_quotas
    FOR UPDATE USING (
        device_id IS NOT NULL 
        AND device_id = current_setting('request.device_id', true)
    );

-- Admin access
CREATE POLICY "admin_select_all_quota" ON daily_quotas
    FOR SELECT USING (public.is_admin_user());
