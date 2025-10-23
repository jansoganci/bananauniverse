import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// ============================================
// IMAGE CLEANUP EDGE FUNCTION
// ============================================
// Automated cleanup of images based on user type and retention policies
// Free users: 24 hours, PRO users: 14 days

interface CleanupResult {
  freeUserImagesDeleted: number;
  proUserImagesDeleted: number;
  errors: string[];
  skippedActiveJobs: number;
  totalStorageFreed: number;
  executionTime: number;
}

interface JobRecord {
  id: string;
  user_id: string | null;
  device_id: string | null;
  input_url: string | null;
  output_url: string | null;
  status: string;
  created_at: string;
  completed_at: string | null;
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
    console.warn('⚠️ [CLEANUP] Missing or invalid authorization header');
    return new Response(JSON.stringify({ error: 'Missing authorization header' }), { 
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
    });
  }
  
  // Additional API key check for extra security
  const expectedApiKey = Deno.env.get('CLEANUP_API_KEY');
  const providedApiKey = req.headers.get('x-api-key');
  
  if (expectedApiKey && (!providedApiKey || providedApiKey !== expectedApiKey)) {
    console.warn('⚠️ [CLEANUP] Invalid or missing API key');
    return new Response(JSON.stringify({ error: 'Unauthorized' }), { 
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
    });
  }

  const startTime = Date.now();
  
  try {
    console.log('🧹 [CLEANUP] Starting image cleanup process...');
    
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const result: CleanupResult = {
      freeUserImagesDeleted: 0,
      proUserImagesDeleted: 0,
      errors: [],
      skippedActiveJobs: 0,
      totalStorageFreed: 0,
      executionTime: 0
    };

    // ============================================
    // 1. GET ELIGIBLE JOBS FOR CLEANUP
    // ============================================
    
    console.log('🔍 [CLEANUP] Fetching eligible jobs...');
    
    // Only get completed/failed jobs older than 24 hours (safety buffer)
    const safetyBuffer = new Date(Date.now() - 24 * 60 * 60 * 1000);
    
    const { data: jobs, error: jobsError } = await supabase
      .from('jobs')
      .select('id, user_id, device_id, input_url, output_url, status, created_at, completed_at')
      .in('status', ['completed', 'failed'])
      .lt('created_at', safetyBuffer.toISOString())
      .not('input_url', 'is', null)
      .not('output_url', 'is', null);

    if (jobsError) {
      throw new Error(`Failed to fetch jobs: ${jobsError.message}`);
    }

    if (!jobs || jobs.length === 0) {
      console.log('✅ [CLEANUP] No jobs eligible for cleanup');
      result.executionTime = Date.now() - startTime;
      return new Response(JSON.stringify(result), { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      });
    }

    console.log(`📊 [CLEANUP] Found ${jobs.length} jobs eligible for cleanup`);

    // ============================================
    // 2. SEPARATE JOBS BY USER TYPE
    // ============================================
    
    const freeUserJobs: JobRecord[] = [];
    const proUserJobs: JobRecord[] = [];
    const unknownUserJobs: JobRecord[] = [];

    for (const job of jobs) {
      if (job.device_id && !job.user_id) {
        // Anonymous user (free)
        freeUserJobs.push(job);
      } else if (job.user_id && !job.device_id) {
        // Authenticated user - check if PRO
        const isPro = await checkIfProUser(supabase, job.user_id);
        if (isPro) {
          proUserJobs.push(job);
        } else {
          freeUserJobs.push(job); // Treat as free user
        }
      } else {
        // Unknown state - skip for safety
        unknownUserJobs.push(job);
        result.skippedActiveJobs++;
      }
    }

    console.log(`📊 [CLEANUP] Free users: ${freeUserJobs.length}, PRO users: ${proUserJobs.length}, Unknown: ${unknownUserJobs.length}`);

    // ============================================
    // 3. CLEAN UP FREE USER IMAGES (24 hours) - BATCH PROCESSING
    // ============================================
    
    const freeUserCutoff = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const eligibleFreeJobs = freeUserJobs.filter(job => 
      new Date(job.created_at) < freeUserCutoff
    );

    console.log(`🧹 [CLEANUP] Cleaning ${eligibleFreeJobs.length} free user images in batches...`);
    
    const freeUserResults = await processJobsInBatches(supabase, eligibleFreeJobs, 'free');
    result.freeUserImagesDeleted = freeUserResults.deletedCount;
    result.totalStorageFreed += freeUserResults.storageFreed;
    result.errors.push(...freeUserResults.errors);

    // ============================================
    // 4. CLEAN UP PRO USER IMAGES (14 days) - BATCH PROCESSING
    // ============================================
    
    const proUserCutoff = new Date(Date.now() - 14 * 24 * 60 * 60 * 1000);
    const eligibleProJobs = proUserJobs.filter(job => 
      new Date(job.created_at) < proUserCutoff
    );

    console.log(`🧹 [CLEANUP] Cleaning ${eligibleProJobs.length} PRO user images in batches...`);
    
    const proUserResults = await processJobsInBatches(supabase, eligibleProJobs, 'pro');
    result.proUserImagesDeleted = proUserResults.deletedCount;
    result.totalStorageFreed += proUserResults.storageFreed;
    result.errors.push(...proUserResults.errors);

    // ============================================
    // 5. LOG CLEANUP RESULTS
    // ============================================
    
    result.executionTime = Date.now() - startTime;
    
    await logCleanupResults(supabase, result);
    
    console.log(`✅ [CLEANUP] Cleanup completed in ${result.executionTime}ms`);
    console.log(`📊 [CLEANUP] Results: ${result.freeUserImagesDeleted} free, ${result.proUserImagesDeleted} pro, ${result.errors.length} errors`);

    // ============================================
    // 6. SEND TELEGRAM NOTIFICATION
    // ============================================
    
    // Send Telegram notification asynchronously (don't block response)
    sendTelegramNotification(result).catch(error => {
      console.error('❌ [CLEANUP] Telegram notification failed:', error);
    });

    return new Response(JSON.stringify(result), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
    });

  } catch (error) {
    console.error('❌ [CLEANUP] Fatal error:', error);
    
    const errorResult: CleanupResult = {
      freeUserImagesDeleted: 0,
      proUserImagesDeleted: 0,
      errors: [`Fatal error: ${error.message}`],
      skippedActiveJobs: 0,
      totalStorageFreed: 0,
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

async function checkIfProUser(supabase: any, userId: string): Promise<boolean> {
  try {
    const { data: profile, error } = await supabase
      .from('profiles')
      .select('subscription_tier')
      .eq('id', userId)
      .single();

    if (error || !profile) {
      console.warn(`⚠️ [CLEANUP] Could not fetch profile for user ${userId}: ${error?.message}`);
      return false; // Default to free user for safety
    }

    return profile.subscription_tier === 'pro';
  } catch (error) {
    console.warn(`⚠️ [CLEANUP] Error checking PRO status for user ${userId}:`, error);
    return false; // Default to free user for safety
  }
}

async function processJobsInBatches(supabase: any, jobs: JobRecord[], userType: string): Promise<{deletedCount: number, storageFreed: number, errors: string[]}> {
  const BATCH_SIZE = 100;
  const MAX_RETRIES = 3;
  const RETRY_DELAY = 1000; // 1 second base delay
  
  let totalDeleted = 0;
  let totalStorageFreed = 0;
  const errors: string[] = [];
  
  // Process jobs in batches
  for (let i = 0; i < jobs.length; i += BATCH_SIZE) {
    const batch = jobs.slice(i, i + BATCH_SIZE);
    console.log(`🔄 [CLEANUP] Processing batch ${Math.floor(i / BATCH_SIZE) + 1}/${Math.ceil(jobs.length / BATCH_SIZE)} (${batch.length} jobs)`);
    
    // Process batch with parallel execution
    const batchPromises = batch.map(job => processJobWithRetry(supabase, job, userType, MAX_RETRIES, RETRY_DELAY));
    const batchResults = await Promise.allSettled(batchPromises);
    
    // Process results
    batchResults.forEach((result, index) => {
      if (result.status === 'fulfilled') {
        if (result.value.success) {
          totalDeleted++;
          totalStorageFreed += result.value.storageFreed;
        }
        if (result.value.error) {
          errors.push(result.value.error);
        }
      } else {
        errors.push(`Batch processing error for job ${batch[index].id}: ${result.reason}`);
      }
    });
  }
  
  return { deletedCount: totalDeleted, storageFreed: totalStorageFreed, errors };
}

async function processJobWithRetry(supabase: any, job: JobRecord, userType: string, maxRetries: number, baseDelay: number): Promise<{success: boolean, storageFreed: number, error?: string}> {
  let lastError: string | undefined;
  
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      const result = await deleteJobImagesAtomic(supabase, job);
      if (result.success) {
        return { success: true, storageFreed: result.storageFreed };
      } else {
        lastError = result.error;
      }
    } catch (error) {
      lastError = `Attempt ${attempt}: ${error.message}`;
    }
    
    if (attempt < maxRetries) {
      const delay = baseDelay * Math.pow(2, attempt - 1); // Exponential backoff
      console.log(`⏳ [CLEANUP] Retrying job ${job.id} in ${delay}ms (attempt ${attempt + 1}/${maxRetries})`);
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }
  
  return { success: false, storageFreed: 0, error: lastError };
}

async function deleteJobImagesAtomic(supabase: any, job: JobRecord): Promise<{success: boolean, storageFreed: number, error?: string}> {
  try {
    // Start transaction by collecting all operations
    const operations: Array<{type: 'delete', bucket: string, path: string}> = [];
    
    // Collect input image deletion
    if (job.input_url) {
      const inputPath = extractPathFromUrl(job.input_url);
      if (inputPath) {
        operations.push({ type: 'delete', bucket: 'noname-banana-images-prod', path: inputPath });
      }
    }
    
    // Collect output image deletion
    if (job.output_url) {
      const outputPath = extractPathFromUrl(job.output_url);
      if (outputPath) {
        operations.push({ type: 'delete', bucket: 'noname-banana-images-prod', path: outputPath });
      }
    }
    
    if (operations.length === 0) {
      return { success: false, storageFreed: 0, error: 'No valid image paths found' };
    }
    
    // Execute all deletions
    const deletionPromises = operations.map(op => 
      supabase.storage.from(op.bucket).remove([op.path])
    );
    
    const results = await Promise.allSettled(deletionPromises);
    
    // Check if all deletions succeeded
    let allSuccessful = true;
    const errors: string[] = [];
    
    results.forEach((result, index) => {
      if (result.status === 'rejected') {
        allSuccessful = false;
        errors.push(`Failed to delete ${operations[index].path}: ${result.reason}`);
      } else if (result.value.error) {
        allSuccessful = false;
        errors.push(`Failed to delete ${operations[index].path}: ${result.value.error.message}`);
      }
    });
    
    if (allSuccessful) {
      return { success: true, storageFreed: operations.length * 1 }; // Approximate 1MB per image
    } else {
      return { success: false, storageFreed: 0, error: errors.join('; ') };
    }
    
  } catch (error) {
    return { success: false, storageFreed: 0, error: `Atomic deletion error: ${error.message}` };
  }
}

async function deleteJobImages(supabase: any, job: JobRecord): Promise<boolean> {
  const result = await deleteJobImagesAtomic(supabase, job);
  return result.success;
}

function extractPathFromUrl(url: string): string | null {
  try {
    // Extract path from Supabase Storage URL
    // URL format: https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/noname-banana-images-prod/uploads/...
    const urlObj = new URL(url);
    const pathParts = urlObj.pathname.split('/');
    const bucketIndex = pathParts.indexOf('noname-banana-images-prod');
    
    if (bucketIndex !== -1 && bucketIndex < pathParts.length - 1) {
      return pathParts.slice(bucketIndex + 1).join('/');
    }
    
    return null;
  } catch (error) {
    console.warn(`⚠️ [CLEANUP] Could not extract path from URL: ${url}`);
    return null;
  }
}

async function logCleanupResults(supabase: any, result: CleanupResult): Promise<void> {
  try {
    await supabase
      .from('cleanup_logs')
      .insert({
        operation: 'cleanup_images',
        details: JSON.stringify(result),
        created_at: new Date().toISOString()
      });
  } catch (error) {
    console.warn(`⚠️ [CLEANUP] Failed to log cleanup results: ${error.message}`);
  }
}

async function sendTelegramNotification(result: CleanupResult): Promise<void> {
  try {
    const botToken = Deno.env.get('TELEGRAM_BOT_TOKEN');
    const chatId = Deno.env.get('TELEGRAM_CHAT_ID');
    
    if (!botToken || !chatId) {
      console.warn('⚠️ [CLEANUP] Telegram credentials not configured, skipping notification');
      return;
    }

    // Calculate storage freed in GB (approximate)
    const storageFreedGB = (result.totalStorageFreed * 2) / 1024; // Rough estimate: 2MB per image pair
    
    const message = `🧹 Cleanup complete:
• ${result.freeUserImagesDeleted} free-user images
• ${result.proUserImagesDeleted} pro-user images
• ${storageFreedGB.toFixed(2)} GB freed
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

    console.log('✅ [CLEANUP] Telegram notification sent successfully');
  } catch (error) {
    console.error('❌ [CLEANUP] Failed to send Telegram notification:', error);
    // Don't throw - we don't want Telegram failures to break cleanup
  }
}
