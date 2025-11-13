import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// ============================================
// HEALTH CHECK EDGE FUNCTION
// ============================================
// Monitors system health and reports status
// Includes database connectivity, cleanup status, and error tracking

interface HealthCheckResult {
  status: 'healthy' | 'degraded' | 'unhealthy';
  database: 'connected' | 'error';
  last_cleanup: string | null;
  errors_24h: number;
  timestamp: string;
  alerted: boolean;
  details?: {
    cleanup_images_last_run?: string;
    cleanup_db_last_run?: string;
    cleanup_logs_last_run?: string;
    recent_errors?: string[];
  };
}

// Alert thresholds
const ALERT_THRESHOLDS = {
  maxErrors24h: 5,
  maxCleanupDelayHours: 24
};

Deno.serve(async (req: Request) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-api-key',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  };

  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const authError = await authenticateRequest(req, corsHeaders);
  if (authError) {
    return authError;
  }

  const startTime = Date.now();
  
  try {
    console.log('🏥 [HEALTH-CHECK] Starting system health check...');
    
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const result: HealthCheckResult = {
      status: 'healthy',
      database: 'connected',
      last_cleanup: null,
      errors_24h: 0,
      timestamp: new Date().toISOString(),
      alerted: false,
      details: {}
    };

    // Check database connectivity
    result.database = await checkDatabaseConnectivity(supabase);
    if (result.database === 'error') {
      result.status = 'unhealthy';
    }

    // Check last cleanup runs
    if (result.database === 'connected') {
      const cleanupInfo = await checkLastCleanup(supabase);
      result.last_cleanup = cleanupInfo.last_cleanup;
      result.details = { ...result.details, ...cleanupInfo.details };
    }

    // Check error count (last 24 hours)
    if (result.database === 'connected') {
      const errorInfo = await checkErrorCount(supabase);
      result.errors_24h = errorInfo.errors_24h;
      result.details!.recent_errors = errorInfo.recent_errors;
    }

    // Determine overall health status
    result.status = determineHealthStatus(result.database, result.errors_24h);
    console.log(`🏥 [HEALTH-CHECK] Overall status: ${result.status}`);

    // Send Telegram alert if unhealthy
    if (result.status !== 'healthy') {
      try {
        await sendTelegramAlert(result);
        result.alerted = true;
      } catch (telegramError) {
        console.warn('⚠️ [HEALTH-CHECK] Telegram alert failed:', telegramError);
        // Don't throw - we don't want Telegram failures to break health check
      }
    }

    // Return health status
    const statusCode = result.status === 'unhealthy' ? 500 : 200;
    
    return new Response(JSON.stringify(result), { 
      status: statusCode,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
    });

  } catch (error) {
    console.error('❌ [HEALTH-CHECK] Fatal error:', error);
    
    const errorResult: HealthCheckResult = {
      status: 'unhealthy',
      database: 'error',
      last_cleanup: null,
      errors_24h: 1,
      timestamp: new Date().toISOString(),
      alerted: false,
      details: {
        recent_errors: [`Fatal error: ${error.message}`]
      }
    };

    return new Response(JSON.stringify(errorResult), { 
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
    });
  }
});

// ============================================
// HELPER FUNCTIONS
// ============================================

async function authenticateRequest(req: Request, corsHeaders: Record<string, string>): Promise<Response | null> {
  const authHeader = req.headers.get('authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    console.warn('⚠️ [HEALTH-CHECK] Missing or invalid authorization header');
    return new Response(JSON.stringify({ error: 'Missing authorization header' }), { 
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
    });
  }
  
  const expectedApiKey = Deno.env.get('CLEANUP_API_KEY');
  const providedApiKey = req.headers.get('x-api-key');
  
  if (expectedApiKey && (!providedApiKey || providedApiKey !== expectedApiKey)) {
    console.warn('⚠️ [HEALTH-CHECK] Invalid or missing API key');
    return new Response(JSON.stringify({ error: 'Unauthorized' }), { 
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
    });
  }
  
  return null;
}

async function checkDatabaseConnectivity(supabase: any): Promise<'connected' | 'error'> {
  console.log('🔍 [HEALTH-CHECK] Checking database connectivity...');
  
  try {
    const { data: dbTest, error: dbError } = await supabase
      .from('cleanup_logs')
      .select('id')
      .limit(1);
    
    if (dbError) {
      throw new Error(`Database error: ${dbError.message}`);
    }
    
    console.log('✅ [HEALTH-CHECK] Database connectivity confirmed');
    return 'connected';
    
  } catch (error) {
    console.error('❌ [HEALTH-CHECK] Database connectivity failed:', error);
    return 'error';
  }
}

async function checkLastCleanup(supabase: any): Promise<{
  last_cleanup: string | null;
  details: {
    cleanup_images_last_run?: string;
    cleanup_db_last_run?: string;
    cleanup_logs_last_run?: string;
  };
}> {
  try {
    console.log('🔍 [HEALTH-CHECK] Checking last cleanup runs...');
    
    // Get last cleanup run from any cleanup operation
    const { data: lastCleanup, error: cleanupError } = await supabase
      .from('cleanup_logs')
      .select('created_at, operation')
      .in('operation', [
        'cleanup_old_jobs_complete',
        'cleanup_rate_limiting_complete', 
        'cleanup_cleanup_logs_complete',
        'log_rotation_complete'
      ])
      .order('created_at', { ascending: false })
      .limit(1)
      .single();
    
    let last_cleanup: string | null = null;
    if (!cleanupError && lastCleanup) {
      last_cleanup = lastCleanup.created_at;
      console.log(`✅ [HEALTH-CHECK] Last cleanup: ${lastCleanup.operation} at ${lastCleanup.created_at}`);
    } else {
      console.log('⚠️ [HEALTH-CHECK] No recent cleanup runs found');
    }
    
    // Get detailed cleanup status for each function
    const { data: cleanupDetails } = await supabase
      .from('cleanup_logs')
      .select('operation, created_at')
      .in('operation', [
        'cleanup_images_complete',
        'cleanup_db_complete',
        'log_rotation_complete'
      ])
      .order('created_at', { ascending: false })
      .limit(3);
    
    const details: {
      cleanup_images_last_run?: string;
      cleanup_db_last_run?: string;
      cleanup_logs_last_run?: string;
    } = {};
    
    if (cleanupDetails) {
      cleanupDetails.forEach(detail => {
        const key = detail.operation.replace('_complete', '_last_run') as keyof typeof details;
        details[key] = detail.created_at;
      });
    }
    
    return { last_cleanup, details };
    
  } catch (error) {
    console.warn('⚠️ [HEALTH-CHECK] Failed to check cleanup status:', error);
    return { last_cleanup: null, details: {} };
  }
}

async function checkErrorCount(supabase: any): Promise<{
  errors_24h: number;
  recent_errors: string[];
}> {
  try {
    console.log('🔍 [HEALTH-CHECK] Checking recent errors...');
    
    const twentyFourHoursAgo = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
    
    // Fetch all logs from last 24 hours, then filter for errors in JavaScript
    // This is more reliable than complex PostgREST OR filters
    const { data: allLogs, error: errorCheckError } = await supabase
      .from('cleanup_logs')
      .select('details, operation, created_at')
      .gte('created_at', twentyFourHoursAgo);
    
    let errors_24h = 0;
    let recent_errors: string[] = [];
    
    if (!errorCheckError && allLogs) {
      // Filter for errors: operation ends with '_error' OR details contains 'error' field
      const errorLogs = allLogs.filter(log => {
        const hasErrorOperation = log.operation.endsWith('_error');
        const hasErrorInDetails = log.details && typeof log.details === 'object' && 'error' in log.details && log.details.error !== null;
        return hasErrorOperation || hasErrorInDetails;
      });
      
      errors_24h = errorLogs.length;
      
      // Get recent error details
      const recentErrorDetails = errorLogs
        .slice(0, 5)
        .map(log => ({
          operation: log.operation,
          error: (log.details && typeof log.details === 'object' && log.details.error) 
            ? String(log.details.error) 
            : 'Unknown error',
          timestamp: log.created_at || 'Unknown'
        }));
      
      recent_errors = recentErrorDetails.map(err => 
        `${err.operation}: ${err.error}`
      );
      
      console.log(`📊 [HEALTH-CHECK] Found ${errors_24h} errors in last 24h`);
    }
    
    return { errors_24h, recent_errors };
    
  } catch (error) {
    console.warn('⚠️ [HEALTH-CHECK] Failed to check error count:', error);
    return { errors_24h: 0, recent_errors: [] };
  }
}

function determineHealthStatus(
  database: 'connected' | 'error',
  errors_24h: number
): 'healthy' | 'degraded' | 'unhealthy' {
  if (database === 'error') {
    return 'unhealthy';
  } else if (errors_24h > 10) {
    return 'degraded';
  } else if (errors_24h > 0) {
    return 'degraded';
  } else {
    return 'healthy';
  }
}

async function sendTelegramAlert(result: HealthCheckResult): Promise<void> {
  const botToken = Deno.env.get('TELEGRAM_BOT_TOKEN');
  const chatId = Deno.env.get('TELEGRAM_CHAT_ID');
  
  if (!botToken || !chatId) {
    console.log('ℹ️ [HEALTH-CHECK] Telegram credentials not configured, skipping alert');
    return;
  }
  
  const statusEmoji = result.status === 'unhealthy' ? '🚨' : '⚠️';
  const message = `${statusEmoji} **System Health Alert**\n\n` +
    `**Status**: ${result.status.toUpperCase()}\n` +
    `**Database**: ${result.database}\n` +
    `**Last Cleanup**: ${result.last_cleanup || 'Never'}\n` +
    `**Errors (24h)**: ${result.errors_24h}\n` +
    `**Timestamp**: ${result.timestamp}\n\n` +
    (result.details?.recent_errors?.length ? 
      `**Recent Errors:**\n${result.details.recent_errors.slice(0, 3).join('\n')}` : 
      'No recent errors');
  
  try {
    const response = await fetch(`https://api.telegram.org/bot${botToken}/sendMessage`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        chat_id: chatId,
        text: message,
        parse_mode: 'Markdown'
      })
    });
    
    if (!response.ok) {
      throw new Error(`Telegram API error: ${response.status} ${response.statusText}`);
    }
    
    console.log('✅ [HEALTH-CHECK] Telegram alert sent successfully');
  } catch (error) {
    console.error('❌ [HEALTH-CHECK] Failed to send Telegram alert:', error);
    throw error;
  }
}
