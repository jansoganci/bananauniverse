import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// ============================================
// LOG MONITOR EDGE FUNCTION
// ============================================
// Weekly system monitoring and reporting
// Aggregates cleanup statistics and sends Telegram summary

interface LogMonitorResult {
  weekly_cleanups: number;
  avg_exec_time: number;
  storage_freed_gb: number;
  errors: number;
  executionTime: number;
  alerted: boolean;
  details?: {
    cleanup_breakdown: {
      images: number;
      database: number;
      logs: number;
    };
    error_breakdown: {
      images: number;
      database: number;
      logs: number;
    };
    top_operations: Array<{
      operation: string;
      count: number;
      avg_time: number;
    }>;
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
    console.log('📊 [LOG-MONITOR] Starting weekly system monitoring...');
    
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const result: LogMonitorResult = {
      weekly_cleanups: 0,
      avg_exec_time: 0,
      storage_freed_gb: 0,
      errors: 0,
      executionTime: 0,
      alerted: false
    };

    const oneWeekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();

    // Get weekly cleanup statistics
    const cleanupStats = await getWeeklyCleanupStats(supabase, oneWeekAgo);
    result.weekly_cleanups = cleanupStats.weekly_cleanups;
    result.avg_exec_time = cleanupStats.avg_exec_time;
    result.storage_freed_gb = cleanupStats.storage_freed_gb;

    // Get error statistics
    const errorStats = await getErrorStatistics(supabase, oneWeekAgo);
    result.errors = errorStats.errors;

    // Get detailed breakdown
    const breakdown = await getDetailedBreakdown(supabase, oneWeekAgo);
    result.details = breakdown;

    // Send Telegram weekly summary
    result.executionTime = Date.now() - startTime;
    
    try {
      await sendTelegramWeeklySummary(result);
      result.alerted = true;
    } catch (telegramError) {
      console.warn('⚠️ [LOG-MONITOR] Telegram summary failed:', telegramError);
      // Don't throw - we don't want Telegram failures to break monitoring
    }

    // Log monitoring results
    await logMonitoringResults(supabase, result, result.executionTime);

    // Return monitoring results
    console.log(`📊 [LOG-MONITOR] Weekly monitoring completed in ${result.executionTime}ms`);
    
    return new Response(JSON.stringify(result), { 
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
    });

  } catch (error) {
    console.error('❌ [LOG-MONITOR] Fatal error:', error);
    
    const errorResult: LogMonitorResult = {
      weekly_cleanups: 0,
      avg_exec_time: 0,
      storage_freed_gb: 0,
      errors: 1,
      executionTime: Date.now() - startTime,
      alerted: false
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
    console.warn('⚠️ [LOG-MONITOR] Missing or invalid authorization header');
    return new Response(JSON.stringify({ error: 'Missing authorization header' }), { 
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
    });
  }
  
  const expectedApiKey = Deno.env.get('CLEANUP_API_KEY');
  const providedApiKey = req.headers.get('x-api-key');
  
  if (expectedApiKey && (!providedApiKey || providedApiKey !== expectedApiKey)) {
    console.warn('⚠️ [LOG-MONITOR] Invalid or missing API key');
    return new Response(JSON.stringify({ error: 'Unauthorized' }), { 
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
    });
  }
  
  return null;
}

async function getWeeklyCleanupStats(
  supabase: any,
  oneWeekAgo: string
): Promise<{
  weekly_cleanups: number;
  avg_exec_time: number;
  storage_freed_gb: number;
}> {
  console.log('🔍 [LOG-MONITOR] Aggregating weekly cleanup statistics...');
  
  try {
    // Get all cleanup completion logs from last week
    const { data: cleanupLogs, error: logsError } = await supabase
      .from('cleanup_logs')
      .select('operation, details, created_at')
      .gte('created_at', oneWeekAgo)
      .in('operation', [
        'cleanup_old_jobs_complete',
        'cleanup_rate_limiting_complete',
        'cleanup_cleanup_logs_complete',
        'log_rotation_complete'
      ]);
    
    if (logsError) {
      throw new Error(`Failed to fetch cleanup logs: ${logsError.message}`);
    }
    
    let weekly_cleanups = 0;
    let avg_exec_time = 0;
    let storage_freed_gb = 0;
    
    if (cleanupLogs) {
      weekly_cleanups = cleanupLogs.length;
      
      // Calculate average execution time
      const executionTimes = cleanupLogs
        .map(log => log.details?.execution_time_ms)
        .filter(time => typeof time === 'number');
      
      if (executionTimes.length > 0) {
        avg_exec_time = Math.round(
          executionTimes.reduce((sum, time) => sum + time, 0) / executionTimes.length
        );
      }
      
      // Calculate total storage freed
      const storageFreed = cleanupLogs
        .map(log => log.details?.totalStorageFreed || log.details?.storage_freed || 0)
        .filter(size => typeof size === 'number')
        .reduce((sum, size) => sum + size, 0);
      
      storage_freed_gb = Math.round(storageFreed * 100) / 100; // Round to 2 decimal places
      
      console.log(`📊 [LOG-MONITOR] Found ${weekly_cleanups} cleanups this week`);
      console.log(`📊 [LOG-MONITOR] Average execution time: ${avg_exec_time}ms`);
      console.log(`📊 [LOG-MONITOR] Total storage freed: ${storage_freed_gb} GB`);
    }
    
    return { weekly_cleanups, avg_exec_time, storage_freed_gb };
    
  } catch (error) {
    console.error('❌ [LOG-MONITOR] Failed to get cleanup statistics:', error);
    return { weekly_cleanups: 0, avg_exec_time: 0, storage_freed_gb: 0 };
  }
}

async function getErrorStatistics(
  supabase: any,
  oneWeekAgo: string
): Promise<{ errors: number }> {
  console.log('🔍 [LOG-MONITOR] Checking error statistics...');
  
  try {
    const { data: errorLogs, error: errorCheckError } = await supabase
      .from('cleanup_logs')
      .select('operation, details')
      .gte('created_at', oneWeekAgo)
      .or('details->error.is.not.null,operation.like.%_error');
    
    let errors = 0;
    if (!errorCheckError && errorLogs) {
      errors = errorLogs.length;
      console.log(`📊 [LOG-MONITOR] Found ${errors} errors this week`);
    }
    
    return { errors };
    
  } catch (error) {
    console.warn('⚠️ [LOG-MONITOR] Failed to get error statistics:', error);
    return { errors: 0 };
  }
}

async function getDetailedBreakdown(
  supabase: any,
  oneWeekAgo: string
): Promise<{
  cleanup_breakdown: {
    images: number;
    database: number;
    logs: number;
  };
  error_breakdown: {
    images: number;
    database: number;
    logs: number;
  };
  top_operations: Array<{
    operation: string;
    count: number;
    avg_time: number;
  }>;
} | undefined> {
  try {
    console.log('🔍 [LOG-MONITOR] Getting detailed breakdown...');
    
    const { data: allLogs } = await supabase
      .from('cleanup_logs')
      .select('operation, details, created_at')
      .gte('created_at', oneWeekAgo);
    
    if (!allLogs) {
      return undefined;
    }
    
    // Cleanup breakdown by type
    const cleanupBreakdown = {
      images: allLogs.filter(log => log.operation.includes('cleanup_images')).length,
      database: allLogs.filter(log => log.operation.includes('cleanup_db') || log.operation.includes('cleanup_old_jobs')).length,
      logs: allLogs.filter(log => log.operation.includes('log_rotation')).length
    };
    
    // Error breakdown by type
    const errorBreakdown = {
      images: allLogs.filter(log => log.operation.includes('cleanup_images') && log.operation.includes('error')).length,
      database: allLogs.filter(log => (log.operation.includes('cleanup_db') || log.operation.includes('cleanup_old_jobs')) && log.operation.includes('error')).length,
      logs: allLogs.filter(log => log.operation.includes('log_rotation') && log.operation.includes('error')).length
    };
    
    // Top operations by frequency
    const operationCounts = allLogs.reduce((acc, log) => {
      acc[log.operation] = (acc[log.operation] || 0) + 1;
      return acc;
    }, {} as Record<string, number>);
    
    const topOperations = Object.entries(operationCounts)
      .map(([operation, count]) => ({
        operation,
        count: count as number,
        avg_time: 0 // Could be calculated if needed
      }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 5);
    
    console.log('📊 [LOG-MONITOR] Detailed breakdown completed');
    
    return {
      cleanup_breakdown: cleanupBreakdown,
      error_breakdown: errorBreakdown,
      top_operations: topOperations
    };
    
  } catch (error) {
    console.warn('⚠️ [LOG-MONITOR] Failed to get detailed breakdown:', error);
    return undefined;
  }
}

async function logMonitoringResults(
  supabase: any,
  result: LogMonitorResult,
  executionTime: number
): Promise<void> {
  try {
    await supabase
      .from('cleanup_logs')
      .insert({
        operation: 'log_monitor_complete',
        details: {
          weekly_cleanups: result.weekly_cleanups,
          avg_exec_time: result.avg_exec_time,
          storage_freed_gb: result.storage_freed_gb,
          errors: result.errors,
          execution_time_ms: executionTime
        }
      });
  } catch (logError) {
    console.warn('⚠️ [LOG-MONITOR] Failed to log monitoring results:', logError);
  }
}

async function sendTelegramWeeklySummary(result: LogMonitorResult): Promise<void> {
  const botToken = Deno.env.get('TELEGRAM_BOT_TOKEN');
  const chatId = Deno.env.get('TELEGRAM_CHAT_ID');
  
  if (!botToken || !chatId) {
    console.log('ℹ️ [LOG-MONITOR] Telegram credentials not configured, skipping summary');
    return;
  }
  
  const message = `🧠 **Weekly System Summary**\n\n` +
    `• **${result.weekly_cleanups}** cleanups\n` +
    `• **${result.storage_freed_gb} GB** freed\n` +
    `• **${result.errors}** errors\n` +
    `• **${result.avg_exec_time}ms** avg execution time\n\n` +
    `📊 **Breakdown:**\n` +
    `• Images: ${result.details?.cleanup_breakdown.images || 0}\n` +
    `• Database: ${result.details?.cleanup_breakdown.database || 0}\n` +
    `• Logs: ${result.details?.cleanup_breakdown.logs || 0}\n\n` +
    `⏱️ **Generated**: ${new Date().toLocaleString()}`;
  
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
    
    console.log('✅ [LOG-MONITOR] Telegram weekly summary sent successfully');
  } catch (error) {
    console.error('❌ [LOG-MONITOR] Failed to send Telegram summary:', error);
    throw error;
  }
}
