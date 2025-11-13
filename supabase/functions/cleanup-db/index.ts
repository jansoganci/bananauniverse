import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// ============================================
// DATABASE CLEANUP EDGE FUNCTION
// ============================================
// Automated cleanup of database records (jobs, rate limiting, logs)
// This function can be called by external cron services

interface CleanupResult {
  jobsDeleted: number;
  rateLimitDeleted: number;
  logsDeleted: number;
  quotaLogsDeleted: number;
  quotaRecordsDeleted: number;
  idempotencyKeysDeleted: number;
  errors: string[];
  executionTime: number;
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
    console.warn('⚠️ [CLEANUP-DB] Missing or invalid authorization header');
    return new Response(JSON.stringify({ error: 'Missing authorization header' }), { 
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
    });
  }
  
  // Additional API key check for extra security
  const expectedApiKey = Deno.env.get('CLEANUP_API_KEY');
  const providedApiKey = req.headers.get('x-api-key');
  
  if (expectedApiKey && (!providedApiKey || providedApiKey !== expectedApiKey)) {
    console.warn('⚠️ [CLEANUP-DB] Invalid or missing API key');
    return new Response(JSON.stringify({ error: 'Unauthorized' }), { 
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
    });
  }

  const startTime = Date.now();
  
  try {
    console.log('🧹 [CLEANUP-DB] Starting database cleanup process...');
    
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const result: CleanupResult = {
      jobsDeleted: 0,
      rateLimitDeleted: 0,
      logsDeleted: 0,
      quotaLogsDeleted: 0,
      quotaRecordsDeleted: 0,
      idempotencyKeysDeleted: 0,
      errors: [],
      executionTime: 0
    };

    // ============================================
    // 1. ATOMIC DATABASE CLEANUP
    // ============================================
    
    console.log('🗑️ [CLEANUP-DB] Starting atomic database cleanup...');
    
    try {
      // Execute all cleanup operations in sequence with proper error handling
      const cleanupResults = await executeAtomicCleanup(supabase);
      
      result.jobsDeleted = cleanupResults.jobsDeleted;
      result.rateLimitDeleted = cleanupResults.rateLimitDeleted;
      result.logsDeleted = cleanupResults.logsDeleted;
      result.quotaLogsDeleted = cleanupResults.quotaLogsDeleted;
      result.quotaRecordsDeleted = cleanupResults.quotaRecordsDeleted;
      result.idempotencyKeysDeleted = cleanupResults.idempotencyKeysDeleted;
      result.errors.push(...cleanupResults.errors);
      
      console.log(`✅ [CLEANUP-DB] Atomic cleanup completed: ${result.jobsDeleted} jobs, ${result.rateLimitDeleted} rate limits, ${result.logsDeleted} logs, ${result.quotaLogsDeleted} quota logs, ${result.quotaRecordsDeleted} quota records, ${result.idempotencyKeysDeleted} idempotency keys`);
      
    } catch (error) {
      result.errors.push(`Atomic cleanup error: ${error.message}`);
      console.error('❌ [CLEANUP-DB] Atomic cleanup failed:', error);
    }

    // ============================================
    // 4. SEND TELEGRAM NOTIFICATION
    // ============================================
    
    result.executionTime = Date.now() - startTime;
    
    // Send Telegram notification asynchronously
    sendTelegramNotification(result).catch(error => {
      console.error('❌ [CLEANUP-DB] Telegram notification failed:', error);
    });

    console.log(`✅ [CLEANUP-DB] Database cleanup completed in ${result.executionTime}ms`);
    console.log(`📊 [CLEANUP-DB] Results: ${result.jobsDeleted} jobs, ${result.rateLimitDeleted} rate limits, ${result.logsDeleted} logs, ${result.quotaLogsDeleted} quota logs, ${result.quotaRecordsDeleted} quota records, ${result.idempotencyKeysDeleted} idempotency keys, ${result.errors.length} errors`);

    return new Response(JSON.stringify(result), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
    });

  } catch (error) {
    console.error('❌ [CLEANUP-DB] Fatal error:', error);
    
    const errorResult: CleanupResult = {
      jobsDeleted: 0,
      rateLimitDeleted: 0,
      logsDeleted: 0,
      quotaLogsDeleted: 0,
      quotaRecordsDeleted: 0,
      idempotencyKeysDeleted: 0,
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

async function executeAtomicCleanup(supabase: any): Promise<{jobsDeleted: number, rateLimitDeleted: number, logsDeleted: number, quotaLogsDeleted: number, quotaRecordsDeleted: number, idempotencyKeysDeleted: number, errors: string[]}> {
  const errors: string[] = [];
  let jobsDeleted = 0;
  let rateLimitDeleted = 0;
  let logsDeleted = 0;
  let quotaLogsDeleted = 0;
  let quotaRecordsDeleted = 0;
  let idempotencyKeysDeleted = 0;
  
  try {
    // 1. Clean up old jobs
    console.log('🗑️ [CLEANUP-DB] Cleaning up old job records...');
    try {
      const { data: jobsResult, error: jobsError } = await supabase.rpc('cleanup_old_jobs');
      if (jobsError) {
        errors.push(`Jobs cleanup error: ${jobsError.message}`);
        console.error('❌ [CLEANUP-DB] Jobs cleanup failed:', jobsError);
      } else {
        jobsDeleted = jobsResult?.[0]?.deleted_count || 0;
        console.log(`✅ [CLEANUP-DB] Deleted ${jobsDeleted} job records`);
      }
    } catch (error) {
      errors.push(`Jobs cleanup error: ${error.message}`);
      console.error('❌ [CLEANUP-DB] Jobs cleanup error:', error);
    }
    
    // 2. Clean up rate limiting data
    console.log('🗑️ [CLEANUP-DB] Cleaning up rate limiting data...');
    try {
      const { data: rateLimitResult, error: rateLimitError } = await supabase.rpc('cleanup_rate_limiting_data');
      if (rateLimitError) {
        errors.push(`Rate limiting cleanup error: ${rateLimitError.message}`);
        console.error('❌ [CLEANUP-DB] Rate limiting cleanup failed:', rateLimitError);
      } else {
        rateLimitDeleted = rateLimitResult?.[0]?.deleted_count || 0;
        console.log(`✅ [CLEANUP-DB] Deleted ${rateLimitDeleted} rate limiting records`);
      }
    } catch (error) {
      errors.push(`Rate limiting cleanup error: ${error.message}`);
      console.error('❌ [CLEANUP-DB] Rate limiting cleanup error:', error);
    }
    
    // 3. Clean up old cleanup logs
    console.log('🗑️ [CLEANUP-DB] Cleaning up old cleanup logs...');
    try {
      const { data: logsResult, error: logsError } = await supabase.rpc('cleanup_cleanup_logs');
      if (logsError) {
        errors.push(`Logs cleanup error: ${logsError.message}`);
        console.error('❌ [CLEANUP-DB] Logs cleanup failed:', logsError);
      } else {
        logsDeleted = logsResult?.[0]?.deleted_count || 0;
        console.log(`✅ [CLEANUP-DB] Deleted ${logsDeleted} cleanup log records`);
      }
    } catch (error) {
      errors.push(`Logs cleanup error: ${error.message}`);
      console.error('❌ [CLEANUP-DB] Logs cleanup error:', error);
    }
    
    // 4. Clean up quota consumption logs
    console.log('🗑️ [CLEANUP-DB] Cleaning up quota consumption logs...');
    try {
      const { data: quotaLogsResult, error: quotaLogsError } = await supabase.rpc('cleanup_quota_consumption_logs');
      if (quotaLogsError) {
        errors.push(`Quota logs cleanup error: ${quotaLogsError.message}`);
        console.error('❌ [CLEANUP-DB] Quota logs cleanup failed:', quotaLogsError);
      } else {
        quotaLogsDeleted = quotaLogsResult?.[0]?.deleted_count || 0;
        console.log(`✅ [CLEANUP-DB] Deleted ${quotaLogsDeleted} quota consumption logs`);
      }
    } catch (error) {
      errors.push(`Quota logs cleanup error: ${error.message}`);
      console.error('❌ [CLEANUP-DB] Quota logs cleanup error:', error);
    }
    
    // 5. Clean up old daily quota records
    console.log('🗑️ [CLEANUP-DB] Cleaning up old daily quota records...');
    try {
      const { data: quotaRecordsResult, error: quotaRecordsError } = await supabase.rpc('cleanup_old_daily_quotas');
      if (quotaRecordsError) {
        errors.push(`Quota records cleanup error: ${quotaRecordsError.message}`);
        console.error('❌ [CLEANUP-DB] Quota records cleanup failed:', quotaRecordsError);
      } else {
        quotaRecordsDeleted = quotaRecordsResult?.[0]?.deleted_count || 0;
        console.log(`✅ [CLEANUP-DB] Deleted ${quotaRecordsDeleted} daily quota records`);
      }
    } catch (error) {
      errors.push(`Quota records cleanup error: ${error.message}`);
      console.error('❌ [CLEANUP-DB] Quota records cleanup error:', error);
    }
    
    // 6. Clean up old idempotency keys
    console.log('🗑️ [CLEANUP-DB] Cleaning up old idempotency keys...');
    try {
      const { data: idempotencyResult, error: idempotencyError } = await supabase.rpc('cleanup_old_idempotency_keys', {
        p_retention_days: 90
      });
      if (idempotencyError) {
        errors.push(`Idempotency keys cleanup error: ${idempotencyError.message}`);
        console.error('❌ [CLEANUP-DB] Idempotency keys cleanup failed:', idempotencyError);
      } else {
        idempotencyKeysDeleted = idempotencyResult?.[0]?.deleted_count || 0;
        console.log(`✅ [CLEANUP-DB] Deleted ${idempotencyKeysDeleted} idempotency key records`);
      }
    } catch (error) {
      errors.push(`Idempotency keys cleanup error: ${error.message}`);
      console.error('❌ [CLEANUP-DB] Idempotency keys cleanup error:', error);
    }
    
  } catch (error) {
    errors.push(`Atomic cleanup execution error: ${error.message}`);
    console.error('❌ [CLEANUP-DB] Atomic cleanup execution failed:', error);
  }
  
  return { jobsDeleted, rateLimitDeleted, logsDeleted, quotaLogsDeleted, quotaRecordsDeleted, idempotencyKeysDeleted, errors };
}

async function sendTelegramNotification(result: CleanupResult): Promise<void> {
  try {
    const botToken = Deno.env.get('TELEGRAM_BOT_TOKEN');
    const chatId = Deno.env.get('TELEGRAM_CHAT_ID');
    
    if (!botToken || !chatId) {
      console.warn('⚠️ [CLEANUP-DB] Telegram credentials not configured, skipping notification');
      return;
    }

    const message = `🗑️ Database cleanup complete:
• ${result.jobsDeleted} job records
• ${result.rateLimitDeleted} rate limit records  
• ${result.logsDeleted} log records
• ${result.quotaLogsDeleted} quota consumption logs
• ${result.quotaRecordsDeleted} daily quota records
• ${result.idempotencyKeysDeleted} idempotency keys
• ${result.errors.length} errors
• ${(result.executionTime / 1000).toFixed(1)}s execution time`;

    const response = await fetch(`https://api.telegram.org/bot${botToken}/sendMessage`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        chat_id: chatId,
        text: message,
        parse_mode: 'Markdown'
      })
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`HTTP ${response.status}: ${errorText}`);
    }

    console.log('✅ [CLEANUP-DB] Telegram notification sent successfully');
  } catch (error) {
    console.error('❌ [CLEANUP-DB] Failed to send Telegram notification:', error);
    // Don't throw - we don't want Telegram failures to break cleanup
  }
}

