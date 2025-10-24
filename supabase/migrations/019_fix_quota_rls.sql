-- Migration 019: Fix RLS policies for quota system
-- Ensures anonymous and authenticated users can insert/update quota records

-- Ensure RLS is enabled
ALTER TABLE daily_quotas ENABLE ROW LEVEL SECURITY;
ALTER TABLE quota_consumption_log ENABLE ROW LEVEL SECURITY;

-- ✅ Grant function execution to service and anon roles
GRANT EXECUTE ON FUNCTION consume_quota TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_quota TO anon, authenticated, service_role;

-- ✅ Allow inserts and updates for anonymous + authenticated users through the function
CREATE POLICY "Allow quota inserts for anon/auth"
ON daily_quotas
FOR INSERT
TO anon, authenticated
WITH CHECK (true);

CREATE POLICY "Allow quota updates for anon/auth"
ON daily_quotas
FOR UPDATE
TO anon, authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "Allow quota logs for anon/auth"
ON quota_consumption_log
FOR INSERT
TO anon, authenticated
WITH CHECK (true);

-- ✅ Optional: allow service_role full access (for background cleanup or maintenance)
CREATE POLICY "Full access for service role"
ON daily_quotas
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

CREATE POLICY "Full access for service role (log)"
ON quota_consumption_log
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);
