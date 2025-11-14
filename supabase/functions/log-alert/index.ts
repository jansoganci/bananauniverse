import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { createLogger } from '../_shared/logger.ts';

// ============================================
// LOG ALERT EDGE FUNCTION
// ============================================
// Automated alerting system for abnormal conditions
// Detects high error rates, cleanup delays, and database issues

interface LogAlertResult {
  status: 'healthy' | 'degraded' | 'critical';
  errors_24h: number;
  last_cleanup_hours: number | null;
  alert_sent: boolean;
  timestamp: string;
  details?: {
    error_breakdown?: {
      cleanup_errors: number;
      api_errors: number;
      total_errors: number;
    };
    cleanup_status?: {
      last_cleanup: string | null;
      hours_since_cleanup: number | null;
      cleanup_delay: boolean;
    };
    database_status?: {
      connected: boolean;
      error_message?: string;
    };
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
  const requestId = `log-alert-${Date.now()}`;
  const logger = createLogger('log-alert', requestId);
  
  try {
    logger.info('Starting automated alerting check');
    
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const result: LogAlertResult = {
      status: 'healthy',
      errors_24h: 0,
      last_cleanup_hours: null,
      alert_sent: false,
      timestamp: new Date().toISOString()
    };

    // Check database connectivity
    logger.step('1. Checking database connectivity');
    const dbStatus = await checkDatabaseConnectivity(supabase, logger);
    result.details = {
      database_status: dbStatus
    };
    const databaseConnected = dbStatus.connected;
    if (databaseConnected) {
      logger.step('1. Database connected');
    } else {
      logger.warn('Database connectivity failed', { error: dbStatus.error_message });
    }
    
    // Check error rates (last 24 hours)
    let totalErrors = 0;
    let cleanupDelay = false;
    
    if (databaseConnected) {
      logger.step('2. Checking error rates');
      const errorInfo = await checkErrorRates(supabase, logger);
      result.errors_24h = errorInfo.errors_24h;
      result.details!.error_breakdown = errorInfo.error_breakdown;
      totalErrors = errorInfo.errors_24h;
      logger.step('2. Error rates checked', { totalErrors });

      // Check cleanup delay
      logger.step('3. Checking cleanup delay');
      const cleanupInfo = await checkCleanupDelay(supabase, logger);
      result.last_cleanup_hours = cleanupInfo.hours_since_cleanup;
      result.details!.cleanup_status = cleanupInfo;
      cleanupDelay = cleanupInfo.cleanup_delay;
      logger.step('3. Cleanup delay checked', { 
        hoursSinceCleanup: cleanupInfo.hours_since_cleanup,
        cleanupDelay 
      });
    }

    // Determine alert status
    logger.step('4. Determining alert status');
    result.status = determineAlertStatus(databaseConnected, totalErrors, cleanupDelay);
    logger.info('Alert status determined', { status: result.status });

    // Send Telegram alert if needed
    if (result.status !== 'healthy') {
      logger.step('5. Sending Telegram alert');
      try {
        await sendTelegramAlert(result, logger);
        result.alert_sent = true;
        logger.step('5. Telegram alert sent');
      } catch (telegramError) {
        logger.warn('Telegram alert failed', { error: telegramError });
        // Don't throw - we don't want Telegram failures to break alerting
      }
    } else {
      logger.info('System healthy, no alert needed');
    }

    // Log alert results
    logger.step('6. Logging alert results');
    await logAlertResults(supabase, result, startTime, databaseConnected, logger);
    logger.step('6. Alert results logged');

    // Return alert results
    const statusCode = result.status === 'critical' ? 500 : 200;
    const duration = Date.now() - startTime;
    
    logger.summary('success', {
      status: result.status,
      errors24h: result.errors_24h,
      lastCleanupHours: result.last_cleanup_hours,
      alertSent: result.alert_sent,
      duration
    });
    
    return new Response(JSON.stringify(result), { 
      status: statusCode,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
    });

  } catch (error) {
    logger.error('Fatal error', error);
    
    const errorResult: LogAlertResult = {
      status: 'critical',
      errors_24h: 1,
      last_cleanup_hours: null,
      alert_sent: false,
      timestamp: new Date().toISOString(),
      details: {
        database_status: {
          connected: false,
          error_message: error.message
        }
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
  const logger = createLogger('log-alert');
  const authHeader = req.headers.get('authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    logger.warn('Missing or invalid authorization header');
    return new Response(JSON.stringify({ error: 'Missing authorization header' }), { 
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
    });
  }
  
  const expectedApiKey = Deno.env.get('CLEANUP_API_KEY');
  const providedApiKey = req.headers.get('x-api-key');
  
  if (expectedApiKey && (!providedApiKey || providedApiKey !== expectedApiKey)) {
    logger.warn('Invalid or missing API key');
    return new Response(JSON.stringify({ error: 'Unauthorized' }), { 
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
    });
  }
  
  logger.debug('Authentication successful');
  return null;
}

async function checkDatabaseConnectivity(supabase: any, logger?: any): Promise<{
  connected: boolean;
  error_message?: string;
}> {
  if (logger) logger.debug('Checking database connectivity');
  
  try {
    const { data: dbTest, error: dbError } = await supabase
      .from('cleanup_logs')
      .select('id')
      .limit(1);
    
    if (dbError) {
      throw new Error(`Database error: ${dbError.message}`);
    }
    
    if (logger) logger.debug('Database connectivity confirmed');
    return { connected: true };
    
  } catch (error: any) {
    if (logger) logger.error('Database connectivity failed', error);
    return { 
      connected: false, 
      error_message: error.message 
    };
  }
}

async function checkErrorRates(supabase: any, logger?: any): Promise<{
  errors_24h: number;
  error_breakdown: {
    cleanup_errors: number;
    api_errors: number;
    total_errors: number;
  };
}> {
  try {
    if (logger) logger.debug('Checking error rates');
    
    const twentyFourHoursAgo = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
    
    // Fetch all cleanup logs from last 24 hours, then filter for errors in JavaScript
    // This is more reliable than complex PostgREST OR filters
    const { data: allCleanupLogs, error: cleanupErrorCheckError } = await supabase
      .from('cleanup_logs')
      .select('operation, details')
      .gte('created_at', twentyFourHoursAgo);
    
    let cleanupErrors = 0;
    if (!cleanupErrorCheckError && allCleanupLogs) {
      // Filter for errors: operation ends with '_error' OR details contains 'error' field
      cleanupErrors = allCleanupLogs.filter(log => {
        const hasErrorOperation = log.operation.endsWith('_error');
        const hasErrorInDetails = log.details && typeof log.details === 'object' && 'error' in log.details && log.details.error !== null;
        return hasErrorOperation || hasErrorInDetails;
      }).length;
    }
    
    // Check API errors (if api_logs table exists)
    let apiErrors = 0;
    try {
      const { data: apiErrorLogs, error: apiErrorCheckError } = await supabase
        .from('api_logs')
        .select('id')
        .gte('created_at', twentyFourHoursAgo)
        .eq('status', 'error');
      
      if (!apiErrorCheckError && apiErrorLogs) {
        apiErrors = apiErrorLogs.length;
      }
    } catch (apiError) {
      // api_logs table might not exist yet, that's okay
      if (logger) logger.debug('api_logs table not found, skipping API error check');
    }
    
    const totalErrors = cleanupErrors + apiErrors;
    if (logger) logger.info('Error rates retrieved', { 
      totalErrors,
      cleanupErrors,
      apiErrors
    });
    
    return {
      errors_24h: totalErrors,
      error_breakdown: {
        cleanup_errors: cleanupErrors,
        api_errors: apiErrors,
        total_errors: totalErrors
      }
    };
    
  } catch (error) {
    if (logger) logger.warn('Failed to check error rates', error);
    return {
      errors_24h: 0,
      error_breakdown: {
        cleanup_errors: 0,
        api_errors: 0,
        total_errors: 0
      }
    };
  }
}

async function checkCleanupDelay(supabase: any, logger?: any): Promise<{
  last_cleanup: string | null;
  hours_since_cleanup: number | null;
  cleanup_delay: boolean;
}> {
  try {
    if (logger) logger.debug('Checking cleanup delay');
    
    const { data: lastCleanupData, error: cleanupError } = await supabase
      .from('cleanup_logs')
      .select('created_at, operation')
      .in('operation', [
        'cleanup_old_jobs_complete',
        'cleanup_rate_limiting_complete', 
        'cleanup_cleanup_logs_complete',
        'log_rotation_complete',
        'cleanup_images_complete',
        'cleanup_db_complete'
      ])
      .order('created_at', { ascending: false })
      .limit(1)
      .single();
    
    if (!cleanupError && lastCleanupData) {
      const lastCleanup = lastCleanupData.created_at;
      const lastCleanupTime = new Date(lastCleanup);
      const now = new Date();
      const hoursSinceCleanup = Math.round((now.getTime() - lastCleanupTime.getTime()) / (1000 * 60 * 60) * 100) / 100;
      
      const cleanupDelay = hoursSinceCleanup > ALERT_THRESHOLDS.maxCleanupDelayHours;
      
      if (logger) logger.debug('Last cleanup found', { 
        hoursSinceCleanup,
        lastCleanup,
        cleanupDelay
      });
      
      return {
        last_cleanup: lastCleanup,
        hours_since_cleanup: hoursSinceCleanup,
        cleanup_delay: cleanupDelay
      };
    } else {
      if (logger) logger.warn('No recent cleanup found');
      return {
        last_cleanup: null,
        hours_since_cleanup: null,
        cleanup_delay: true // No cleanup = delay
      };
    }
    
  } catch (error) {
    if (logger) logger.warn('Failed to check cleanup delay', error);
    return {
      last_cleanup: null,
      hours_since_cleanup: null,
      cleanup_delay: true
    };
  }
}

function determineAlertStatus(
  databaseConnected: boolean,
  totalErrors: number,
  cleanupDelay: boolean
): 'healthy' | 'degraded' | 'critical' {
  if (!databaseConnected) {
    return 'critical';
  } else if (totalErrors > ALERT_THRESHOLDS.maxErrors24h || cleanupDelay) {
    return 'degraded';
  } else {
    return 'healthy';
  }
}

async function logAlertResults(
  supabase: any,
  result: LogAlertResult,
  startTime: number,
  databaseConnected: boolean,
  logger?: any
): Promise<void> {
  try {
    await supabase
      .from('cleanup_logs')
      .insert({
        operation: 'log_alert_complete',
        details: {
          status: result.status,
          errors_24h: result.errors_24h,
          last_cleanup_hours: result.last_cleanup_hours,
          alert_sent: result.alert_sent,
          execution_time_ms: Date.now() - startTime,
          database_connected: databaseConnected
        }
      });
    if (logger) logger.debug('Alert results logged to database');
  } catch (logError) {
    if (logger) logger.warn('Failed to log alert results', logError);
  }
}

async function sendTelegramAlert(result: LogAlertResult, logger?: any): Promise<void> {
  const botToken = Deno.env.get('TELEGRAM_BOT_TOKEN');
  const chatId = Deno.env.get('TELEGRAM_CHAT_ID');
  
  if (!botToken || !chatId) {
    if (logger) logger.debug('Telegram credentials not configured, skipping alert');
    return;
  }
  
  const statusEmoji = result.status === 'critical' ? '🚨' : '⚠️';
  const statusText = result.status === 'critical' ? 'Critical' : 'Degraded';
  
  let message = `${statusEmoji} **System Alert: ${statusText}**\n\n`;
  
  // Error information
  if (result.errors_24h > 0) {
    message += `• **${result.errors_24h} errors** in last 24h\n`;
    if (result.details?.error_breakdown) {
      message += `  - Cleanup: ${result.details.error_breakdown.cleanup_errors}\n`;
      message += `  - API: ${result.details.error_breakdown.api_errors}\n`;
    }
  } else {
    message += `• **0 errors** in last 24h\n`;
  }
  
  // Cleanup information
  if (result.last_cleanup_hours !== null) {
    message += `• **Last cleanup**: ${result.last_cleanup_hours}h ago\n`;
  } else {
    message += `• **Last cleanup**: Never\n`;
  }
  
  // Database status
  if (result.details?.database_status) {
    const dbStatus = result.details.database_status.connected ? '✅ connected' : '❌ disconnected';
    message += `• **DB**: ${dbStatus}\n`;
  }
  
  // Overall status
  const statusIcon = result.status === 'critical' ? '🚨' : '⚠️';
  message += `• **Status**: ${statusIcon} ${statusText}\n\n`;
  
  // Timestamp
  message += `⏰ **Generated**: ${new Date().toLocaleString()}`;
  
  try {
    if (logger) logger.debug('Sending Telegram alert', { status: result.status });
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
    
    if (logger) logger.info('Telegram alert sent successfully');
  } catch (error) {
    if (logger) logger.error('Failed to send Telegram alert', error);
    throw error;
  }
}
