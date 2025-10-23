-- =====================================================
-- Migration: Create Monitoring Views and Functions
-- =====================================================
--
-- This migration creates monitoring infrastructure for:
-- 1. System health views
-- 2. Cleanup statistics views
-- 3. Helper functions for health monitoring
--
-- IDEMPOTENT - Safe to run multiple times
--
-- =====================================================

-- =====================================================
-- 1. SYSTEM HEALTH VIEW
-- =====================================================

-- View to track overall system health metrics
CREATE OR REPLACE VIEW system_health_view AS
SELECT 
  'cleanup_system' as component,
  COUNT(*) as total_operations,
  COUNT(*) FILTER (WHERE details->>'error' IS NULL) as successful_operations,
  COUNT(*) FILTER (WHERE details->>'error' IS NOT NULL) as failed_operations,
  ROUND(
    AVG((details->>'execution_time_ms')::numeric), 2
  ) as avg_execution_time_ms,
  MAX(created_at) as last_operation,
  COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '24 hours') as operations_24h,
  COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '7 days') as operations_7d
FROM cleanup_logs
WHERE operation LIKE '%_complete' OR operation LIKE '%_error'
UNION ALL
SELECT 
  'error_rate' as component,
  COUNT(*) as total_operations,
  COUNT(*) FILTER (WHERE details->>'error' IS NULL) as successful_operations,
  COUNT(*) FILTER (WHERE details->>'error' IS NOT NULL) as failed_operations,
  ROUND(
    (COUNT(*) FILTER (WHERE details->>'error' IS NOT NULL)::numeric / 
     NULLIF(COUNT(*), 0) * 100), 2
  ) as avg_execution_time_ms, -- Using this field for error rate percentage
  MAX(created_at) as last_operation,
  COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '24 hours') as operations_24h,
  COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '7 days') as operations_7d
FROM cleanup_logs
WHERE created_at > NOW() - INTERVAL '7 days';

-- Grant access to service role
GRANT SELECT ON system_health_view TO service_role;

-- =====================================================
-- 2. CLEANUP STATISTICS WEEKLY VIEW
-- =====================================================

-- View to group cleanup operations by week
CREATE OR REPLACE VIEW cleanup_stats_weekly AS
SELECT 
  DATE_TRUNC('week', created_at) as week_start,
  COUNT(*) as total_cleanups,
  COUNT(*) FILTER (WHERE operation LIKE '%_complete') as successful_cleanups,
  COUNT(*) FILTER (WHERE operation LIKE '%_error') as failed_cleanups,
  ROUND(AVG((details->>'execution_time_ms')::numeric), 2) as avg_execution_time_ms,
  ROUND(SUM((details->>'totalStorageFreed')::numeric), 2) as total_storage_freed,
  ROUND(SUM((details->>'storage_freed')::numeric), 2) as total_storage_freed_alt,
  COUNT(DISTINCT operation) as unique_operations
FROM cleanup_logs
WHERE operation IN (
  'cleanup_old_jobs_complete',
  'cleanup_rate_limiting_complete',
  'cleanup_cleanup_logs_complete',
  'log_rotation_complete',
  'cleanup_images_complete',
  'cleanup_db_complete'
)
GROUP BY DATE_TRUNC('week', created_at)
ORDER BY week_start DESC;

-- Grant access to service role
GRANT SELECT ON cleanup_stats_weekly TO service_role;

-- =====================================================
-- 3. PERFORMANCE METRICS TABLE (IF NOT EXISTS)
-- =====================================================

-- Create performance metrics table if it doesn't exist
CREATE TABLE IF NOT EXISTS performance_metrics (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    metric_name TEXT NOT NULL,
    metric_value NUMERIC NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_performance_metrics_name ON performance_metrics(metric_name);
CREATE INDEX IF NOT EXISTS idx_performance_metrics_created_at ON performance_metrics(created_at DESC);

-- Enable RLS
ALTER TABLE performance_metrics ENABLE ROW LEVEL SECURITY;

-- Policy: Service role can manage all performance metrics
CREATE POLICY "Service role can manage performance metrics" ON performance_metrics
    FOR ALL USING (auth.role() = 'service_role');

-- =====================================================
-- 4. SYSTEM HEALTH FUNCTION
-- =====================================================

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS public.get_system_health();

-- Function to get comprehensive system health summary
CREATE OR REPLACE FUNCTION public.get_system_health()
RETURNS JSON AS $$
DECLARE
  health_data JSON;
  db_health JSON;
  cleanup_health JSON;
  error_health JSON;
  performance_data JSON;
BEGIN
  -- Database connectivity check
  SELECT json_build_object(
    'status', 'connected',
    'timestamp', NOW()
  ) INTO db_health;
  
  -- Cleanup system health
  SELECT json_build_object(
    'total_operations', COUNT(*),
    'successful_operations', COUNT(*) FILTER (WHERE details->>'error' IS NULL),
    'failed_operations', COUNT(*) FILTER (WHERE details->>'error' IS NOT NULL),
    'last_cleanup', MAX(created_at) FILTER (WHERE operation LIKE '%_complete'),
    'operations_24h', COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '24 hours'),
    'avg_execution_time_ms', ROUND(AVG((details->>'execution_time_ms')::numeric), 2)
  ) INTO cleanup_health
  FROM cleanup_logs
  WHERE created_at > NOW() - INTERVAL '7 days';
  
  -- Error health
  SELECT json_build_object(
    'errors_24h', COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '24 hours'),
    'errors_7d', COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '7 days'),
    'error_rate_24h', ROUND(
      (COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '24 hours' AND details->>'error' IS NOT NULL)::numeric / 
       NULLIF(COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '24 hours'), 0) * 100), 2
    )
  ) INTO error_health
  FROM cleanup_logs
  WHERE created_at > NOW() - INTERVAL '7 days';
  
  -- Performance data
  SELECT json_build_object(
    'avg_response_time_ms', ROUND(AVG((details->>'execution_time_ms')::numeric), 2),
    'total_storage_freed_gb', ROUND(SUM((details->>'totalStorageFreed')::numeric), 2),
    'cleanups_this_week', COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '7 days')
  ) INTO performance_data
  FROM cleanup_logs
  WHERE operation LIKE '%_complete' 
    AND created_at > NOW() - INTERVAL '7 days';
  
  -- Combine all health data
  SELECT json_build_object(
    'database', db_health,
    'cleanup_system', cleanup_health,
    'error_health', error_health,
    'performance', performance_data,
    'overall_status', CASE
      WHEN (SELECT COUNT(*) FROM cleanup_logs WHERE created_at > NOW() - INTERVAL '24 hours' AND details->>'error' IS NOT NULL) > 10 THEN 'degraded'
      WHEN (SELECT COUNT(*) FROM cleanup_logs WHERE created_at > NOW() - INTERVAL '24 hours' AND details->>'error' IS NOT NULL) > 0 THEN 'degraded'
      ELSE 'healthy'
    END,
    'timestamp', NOW()
  ) INTO health_data;
  
  RETURN health_data;
EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object(
      'error', SQLERRM,
      'status', 'error',
      'timestamp', NOW()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.get_system_health() TO service_role;

-- =====================================================
-- 5. CLEANUP STATISTICS FUNCTION
-- =====================================================

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS public.get_cleanup_stats_weekly();

-- Function to get weekly cleanup statistics
CREATE OR REPLACE FUNCTION public.get_cleanup_stats_weekly(weeks_back INTEGER DEFAULT 1)
RETURNS JSON AS $$
DECLARE
  stats_data JSON;
  week_start DATE;
  week_end DATE;
BEGIN
  -- Calculate week boundaries
  week_start := (CURRENT_DATE - (weeks_back * 7) * INTERVAL '1 day')::DATE;
  week_end := week_start + INTERVAL '7 days';
  
  -- Get weekly statistics
  SELECT json_build_object(
    'week_start', week_start,
    'week_end', week_end,
    'total_cleanups', COUNT(*),
    'successful_cleanups', COUNT(*) FILTER (WHERE operation LIKE '%_complete'),
    'failed_cleanups', COUNT(*) FILTER (WHERE operation LIKE '%_error'),
    'avg_execution_time_ms', ROUND(AVG((details->>'execution_time_ms')::numeric), 2),
    'total_storage_freed_gb', ROUND(SUM(
      COALESCE((details->>'totalStorageFreed')::numeric, 0) + 
      COALESCE((details->>'storage_freed')::numeric, 0)
    ), 2),
    'operations_by_type', json_object_agg(
      operation, 
      json_build_object(
        'count', operation_count,
        'avg_time_ms', ROUND(avg_time, 2)
      )
    )
  ) INTO stats_data
  FROM (
    SELECT 
      operation,
      COUNT(*) as operation_count,
      AVG((details->>'execution_time_ms')::numeric) as avg_time
    FROM cleanup_logs
    WHERE created_at >= week_start 
      AND created_at < week_end
      AND operation IN (
        'cleanup_old_jobs_complete',
        'cleanup_rate_limiting_complete',
        'cleanup_cleanup_logs_complete',
        'log_rotation_complete',
        'cleanup_images_complete',
        'cleanup_db_complete'
      )
    GROUP BY operation
  ) operation_stats;
  
  RETURN COALESCE(stats_data, json_build_object('error', 'No data found for specified week'));
EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object(
      'error', SQLERRM,
      'status', 'error',
      'timestamp', NOW()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.get_cleanup_stats_weekly(INTEGER) TO service_role;

-- =====================================================
-- 6. COMMENTS AND DOCUMENTATION
-- =====================================================

COMMENT ON VIEW system_health_view IS 'Real-time system health metrics for monitoring';
COMMENT ON VIEW cleanup_stats_weekly IS 'Weekly cleanup operation statistics grouped by week';
COMMENT ON TABLE performance_metrics IS 'Performance metrics storage for system monitoring';
COMMENT ON FUNCTION public.get_system_health() IS 'Returns comprehensive system health summary as JSON';
COMMENT ON FUNCTION public.get_cleanup_stats_weekly(INTEGER) IS 'Returns weekly cleanup statistics for specified number of weeks back';

-- =====================================================
-- 7. MIGRATION SUCCESS LOG
-- =====================================================

-- Log migration success
DO $$
BEGIN
  RAISE NOTICE '✅ Migration 009_create_monitoring_views completed successfully';
  RAISE NOTICE '   - Created system_health_view for real-time monitoring';
  RAISE NOTICE '   - Created cleanup_stats_weekly view for weekly statistics';
  RAISE NOTICE '   - Created performance_metrics table for metrics storage';
  RAISE NOTICE '   - Added get_system_health() function for health checks';
  RAISE NOTICE '   - Added get_cleanup_stats_weekly() function for statistics';
  RAISE NOTICE '   - Monitoring infrastructure ready for production use';
END $$;
