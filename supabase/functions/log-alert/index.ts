import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

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

  // ============================================
  // 1. SUPABASE AUTHENTICATION
  // ============================================
  
  // Check for Supabase authorization header
  const authHeader = req.headers.get('authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    console.warn('⚠️ [LOG-ALERT] Missing or invalid authorization header');
    return new Response(JSON.stringify({ error: 'Missing authorization header' }), { 
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
    });
  }
  
  // Additional API key check for extra security
  const expectedApiKey = Deno.env.get('CLEANUP_API_KEY');
  const providedApiKey = req.headers.get('x-api-key');
  
  if (expectedApiKey && (!providedApiKey || providedApiKey !== expectedApiKey)) {
    console.warn('⚠️ [LOG-ALERT] Invalid or missing API key');
    return new Response(JSON.stringify({ error: 'Unauthorized' }), { 
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
    });
  }

  const startTime = Date.now();
  
  try {
    console.log('🚨 [LOG-ALERT] Starting automated alerting check...');
    
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

    // ============================================
    // 2. DATABASE CONNECTIVITY CHECK
    // ============================================
    
    console.log('🔍 [LOG-ALERT] Checking database connectivity...');
    
    let databaseConnected = false;
    let databaseError = null;
    
    try {
      const { data: dbTest, error: dbError } = await supabase
        .from('cleanup_logs')
        .select('id')
        .limit(1);
      
      if (dbError) {
        throw new Error(`Database error: ${dbError.message}`);
      }
      
      databaseConnected = true;
      console.log('✅ [LOG-ALERT] Database connectivity confirmed');
      
    } catch (error) {
      databaseConnected = false;
      databaseError = error.message;
      console.error('❌ [LOG-ALERT] Database connectivity failed:', error);
    }

    result.details = {
      database_status: {
        connected: databaseConnected,
        error_message: databaseError || undefined
      }
    };

    // ============================================
    // 3. ERROR RATE CHECK (LAST 24 HOURS)
    // ============================================
    
    let totalErrors = 0;
    let cleanupErrors = 0;
    let apiErrors = 0;
    
    if (databaseConnected) {
      try {
        console.log('🔍 [LOG-ALERT] Checking error rates...');
        
        const twentyFourHoursAgo = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
        
        // Check cleanup errors
        const { data: cleanupErrorLogs, error: cleanupErrorCheckError } = await supabase
          .from('cleanup_logs')
          .select('operation, details')
          .gte('created_at', twentyFourHoursAgo)
          .or('details->error.is.not.null,operation.like.%_error');
        
        if (!cleanupErrorCheckError && cleanupErrorLogs) {
          cleanupErrors = cleanupErrorLogs.length;
        }
        
        // Check API errors (if api_logs table exists)
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
          console.log('ℹ️ [LOG-ALERT] api_logs table not found, skipping API error check');
        }
        
        totalErrors = cleanupErrors + apiErrors;
        result.errors_24h = totalErrors;
        
        console.log(`📊 [LOG-ALERT] Found ${totalErrors} errors in last 24h (cleanup: ${cleanupErrors}, api: ${apiErrors})`);
        
        result.details!.error_breakdown = {
          cleanup_errors: cleanupErrors,
          api_errors: apiErrors,
          total_errors: totalErrors
        };
        
      } catch (error) {
        console.warn('⚠️ [LOG-ALERT] Failed to check error rates:', error);
      }
    }

    // ============================================
    // 4. CLEANUP DELAY CHECK
    // ============================================
    
    let lastCleanup: string | null = null;
    let hoursSinceCleanup: number | null = null;
    let cleanupDelay = false;
    
    if (databaseConnected) {
      try {
        console.log('🔍 [LOG-ALERT] Checking cleanup delay...');
        
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
          lastCleanup = lastCleanupData.created_at;
          const lastCleanupTime = new Date(lastCleanup!);
          const now = new Date();
          hoursSinceCleanup = Math.round((now.getTime() - lastCleanupTime.getTime()) / (1000 * 60 * 60) * 100) / 100;
          
          cleanupDelay = hoursSinceCleanup > ALERT_THRESHOLDS.maxCleanupDelayHours;
          result.last_cleanup_hours = hoursSinceCleanup;
          
          console.log(`📊 [LOG-ALERT] Last cleanup: ${hoursSinceCleanup}h ago (${lastCleanup})`);
        } else {
          console.log('⚠️ [LOG-ALERT] No recent cleanup found');
          cleanupDelay = true; // No cleanup = delay
        }
        
        result.details!.cleanup_status = {
          last_cleanup: lastCleanup,
          hours_since_cleanup: hoursSinceCleanup,
          cleanup_delay: cleanupDelay
        };
        
      } catch (error) {
        console.warn('⚠️ [LOG-ALERT] Failed to check cleanup delay:', error);
      }
    }

    // ============================================
    // 5. DETERMINE ALERT STATUS
    // ============================================
    
    if (!databaseConnected) {
      result.status = 'critical';
    } else if (totalErrors > ALERT_THRESHOLDS.maxErrors24h || cleanupDelay) {
      result.status = 'degraded';
    } else {
      result.status = 'healthy';
    }
    
    console.log(`🚨 [LOG-ALERT] Alert status: ${result.status}`);

    // ============================================
    // 6. SEND TELEGRAM ALERT IF NEEDED
    // ============================================
    
    if (result.status !== 'healthy') {
      try {
        await sendTelegramAlert(result);
        result.alert_sent = true;
        console.log('✅ [LOG-ALERT] Telegram alert sent successfully');
      } catch (telegramError) {
        console.warn('⚠️ [LOG-ALERT] Telegram alert failed:', telegramError);
        // Don't throw - we don't want Telegram failures to break alerting
      }
    } else {
      console.log('ℹ️ [LOG-ALERT] System healthy, no alert needed');
    }

    // ============================================
    // 7. LOG ALERT RESULTS
    // ============================================
    
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
    } catch (logError) {
      console.warn('⚠️ [LOG-ALERT] Failed to log alert results:', logError);
    }

    // ============================================
    // 8. RETURN ALERT RESULTS
    // ============================================
    
    const statusCode = result.status === 'critical' ? 500 : 200;
    
    return new Response(JSON.stringify(result), { 
      status: statusCode,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
    });

  } catch (error) {
    console.error('❌ [LOG-ALERT] Fatal error:', error);
    
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

async function sendTelegramAlert(result: LogAlertResult): Promise<void> {
  const botToken = Deno.env.get('TELEGRAM_BOT_TOKEN');
  const chatId = Deno.env.get('TELEGRAM_CHAT_ID');
  
  if (!botToken || !chatId) {
    console.log('ℹ️ [LOG-ALERT] Telegram credentials not configured, skipping alert');
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
    
    console.log('✅ [LOG-ALERT] Telegram alert sent successfully');
  } catch (error) {
    console.error('❌ [LOG-ALERT] Failed to send Telegram alert:', error);
    throw error;
  }
}
