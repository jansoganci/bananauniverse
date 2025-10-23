import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// ============================================
// LOG ROTATION EDGE FUNCTION
// ============================================
// Automated 90-day log rotation for cleanup_logs table
// Safe batch deletion with comprehensive logging

interface LogRotationResult {
  logsDeleted: number;
  batchesProcessed: number;
  errors: string[];
  executionTime: number;
  oldestDeletedDate?: string;
  newestDeletedDate?: string;
}

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
    console.warn('⚠️ [LOG-ROTATION] Missing or invalid authorization header');
    return new Response(JSON.stringify({ error: 'Missing authorization header' }), { 
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
    });
  }
  
  // Additional API key check for extra security
  const expectedApiKey = Deno.env.get('CLEANUP_API_KEY');
  const providedApiKey = req.headers.get('x-api-key');
  
  if (expectedApiKey && (!providedApiKey || providedApiKey !== expectedApiKey)) {
    console.warn('⚠️ [LOG-ROTATION] Invalid or missing API key');
    return new Response(JSON.stringify({ error: 'Unauthorized' }), { 
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
    });
  }

  const startTime = Date.now();
  
  try {
    console.log('🧹 [LOG-ROTATION] Starting 90-day log rotation...');
    
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const result: LogRotationResult = {
      logsDeleted: 0,
      batchesProcessed: 0,
      errors: [],
      executionTime: 0
    };

    // ============================================
    // 2. BATCH LOG DELETION (90 days)
    // ============================================
    
    console.log('🗑️ [LOG-ROTATION] Starting batch deletion of logs older than 90 days...');
    
    const BATCH_SIZE = 500;
    const RETENTION_DAYS = 90;
    const cutoffDate = new Date(Date.now() - RETENTION_DAYS * 24 * 60 * 60 * 1000);
    
    let totalDeleted = 0;
    let batchesProcessed = 0;
    let hasMoreLogs = true;
    let oldestDeletedDate: string | undefined;
    let newestDeletedDate: string | undefined;
    
    while (hasMoreLogs) {
      try {
        // Get batch of old logs to delete
        const { data: oldLogs, error: fetchError } = await supabase
          .from('cleanup_logs')
          .select('id, created_at')
          .lt('created_at', cutoffDate.toISOString())
          .order('created_at', { ascending: true })
          .limit(BATCH_SIZE);
        
        if (fetchError) {
          throw new Error(`Failed to fetch logs: ${fetchError.message}`);
        }
        
        if (!oldLogs || oldLogs.length === 0) {
          hasMoreLogs = false;
          break;
        }
        
        // Track date range for reporting
        if (!oldestDeletedDate) {
          oldestDeletedDate = oldLogs[0].created_at;
        }
        newestDeletedDate = oldLogs[oldLogs.length - 1].created_at;
        
        // Delete batch
        const logIds = oldLogs.map(log => log.id);
        const { error: deleteError } = await supabase
          .from('cleanup_logs')
          .delete()
          .in('id', logIds);
        
        if (deleteError) {
          throw new Error(`Failed to delete log batch: ${deleteError.message}`);
        }
        
        totalDeleted += oldLogs.length;
        batchesProcessed++;
        
        console.log(`🔄 [LOG-ROTATION] Batch ${batchesProcessed}: Deleted ${oldLogs.length} logs (Total: ${totalDeleted})`);
        
        // Safety check: if we got fewer logs than batch size, we're done
        if (oldLogs.length < BATCH_SIZE) {
          hasMoreLogs = false;
        }
        
        // Small delay between batches to avoid overwhelming the database
        if (hasMoreLogs) {
          await new Promise(resolve => setTimeout(resolve, 100));
        }
        
      } catch (error) {
        const errorMsg = `Batch ${batchesProcessed + 1} failed: ${error.message}`;
        result.errors.push(errorMsg);
        console.error(`❌ [LOG-ROTATION] ${errorMsg}`);
        
        // Continue with next batch instead of failing completely
        hasMoreLogs = false;
      }
    }
    
    result.logsDeleted = totalDeleted;
    result.batchesProcessed = batchesProcessed;
    result.oldestDeletedDate = oldestDeletedDate;
    result.newestDeletedDate = newestDeletedDate;
    
    console.log(`✅ [LOG-ROTATION] Completed: ${totalDeleted} logs deleted in ${batchesProcessed} batches`);

    // ============================================
    // 3. LOG ROTATION RESULTS
    // ============================================
    
    result.executionTime = Date.now() - startTime;
    
    // Log the rotation operation itself
    try {
      await supabase
        .from('cleanup_logs')
        .insert({
          operation: 'log_rotation_complete',
          details: {
            logs_deleted: totalDeleted,
            batches_processed: batchesProcessed,
            retention_days: RETENTION_DAYS,
            execution_time_ms: result.executionTime,
            errors: result.errors,
            oldest_deleted: oldestDeletedDate,
            newest_deleted: newestDeletedDate
          }
        });
    } catch (logError) {
      console.warn('⚠️ [LOG-ROTATION] Failed to log rotation results:', logError);
    }

    // ============================================
    // 4. SEND TELEGRAM NOTIFICATION
    // ============================================
    
    try {
      await sendTelegramNotification(result);
    } catch (telegramError) {
      console.warn('⚠️ [LOG-ROTATION] Telegram notification failed:', telegramError);
      // Don't throw - we don't want Telegram failures to break log rotation
    }

    // ============================================
    // 5. RETURN RESULTS
    // ============================================
    
    return new Response(JSON.stringify(result), { 
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
    });

  } catch (error) {
    console.error('❌ [LOG-ROTATION] Fatal error:', error);
    
    const errorResult: LogRotationResult = {
      logsDeleted: 0,
      batchesProcessed: 0,
      errors: [`Fatal error: ${error.message}`],
      executionTime: Date.now() - startTime
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

async function sendTelegramNotification(result: LogRotationResult): Promise<void> {
  const botToken = Deno.env.get('TELEGRAM_BOT_TOKEN');
  const chatId = Deno.env.get('TELEGRAM_CHAT_ID');
  
  if (!botToken || !chatId) {
    console.log('ℹ️ [LOG-ROTATION] Telegram credentials not configured, skipping notification');
    return;
  }
  
  const message = `🧹 **Log rotation complete**: ${result.logsDeleted} logs deleted\n\n` +
    `📊 **Details:**\n` +
    `• Batches processed: ${result.batchesProcessed}\n` +
    `• Execution time: ${result.executionTime}ms\n` +
    `• Errors: ${result.errors.length}\n` +
    (result.oldestDeletedDate ? `• Oldest deleted: ${new Date(result.oldestDeletedDate).toLocaleDateString()}\n` : '') +
    (result.newestDeletedDate ? `• Newest deleted: ${new Date(result.newestDeletedDate).toLocaleDateString()}\n` : '') +
    (result.errors.length > 0 ? `\n⚠️ **Errors:**\n${result.errors.slice(0, 3).join('\n')}` : '');
  
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
    
    console.log('✅ [LOG-ROTATION] Telegram notification sent successfully');
  } catch (error) {
    console.error('❌ [LOG-ROTATION] Failed to send Telegram notification:', error);
    throw error;
  }
}
