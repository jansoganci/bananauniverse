import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// ============================================
// MANUAL IMAGE CLEANUP EDGE FUNCTION
// ============================================
// Deletes ALL images older than 24 hours from storage
// Simple rule: delete if file timestamp > 24 hours old
// Manual trigger only - no scheduling

interface CleanupResult {
  files_deleted: number;
  files_skipped: number;
  total_storage_freed_mb: number;
  errors: string[];
  deleted_files: Array<{
    path: string;
    folder: string;
    age_hours: number;
    size_bytes: number;
    deleted_at: string;
  }>;
  skipped_files: Array<{
    path: string;
    folder: string;
    age_hours: number;
    reason: string;
  }>;
  execution_time_ms: number;
  dry_run: boolean;
}

interface FileInfo {
  name: string;
  id: string;
  updated_at: string;
  created_at: string;
  last_accessed_at: string;
  metadata: {
    size?: number;
    mimetype?: string;
  };
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

  const startTime = Date.now();
  
  try {
    // ============================================
    // 1. AUTHENTICATE REQUEST
    // ============================================
    const authError = await authenticateRequest(req);
    if (authError) {
      return new Response(JSON.stringify({ error: authError }), { 
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      });
    }

    // ============================================
    // 2. CHECK DRY-RUN MODE
    // ============================================
    const url = new URL(req.url);
    const dryRun = url.searchParams.get('dry_run') === 'true' || 
                   Deno.env.get('DRY_RUN') === 'true';

    console.log(`🧹 [CLEANUP] Starting manual storage cleanup (dry-run: ${dryRun})...`);

    // ============================================
    // 3. INITIALIZE SUPABASE CLIENT
    // ============================================
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const bucketName = 'noname-banana-images-prod';
    const folders = ['uploads', 'processed'];
    const retentionHours = 24;
    const cutoffTime = new Date(Date.now() - retentionHours * 60 * 60 * 1000);

    const result: CleanupResult = {
      files_deleted: 0,
      files_skipped: 0,
      total_storage_freed_mb: 0,
      errors: [],
      deleted_files: [],
      skipped_files: [],
      execution_time_ms: 0,
      dry_run: dryRun
    };

    // ============================================
    // 4. PROCESS EACH FOLDER
    // ============================================
    for (const folder of folders) {
      console.log(`📁 [CLEANUP] Processing folder: ${folder}/`);
    
      const folderResult = await processFolder(
        supabase,
        bucketName,
        folder,
        cutoffTime,
        dryRun
      );

      result.files_deleted += folderResult.deleted_count;
      result.files_skipped += folderResult.skipped_count;
      result.total_storage_freed_mb += folderResult.storage_freed_mb;
      result.errors.push(...folderResult.errors);
      result.deleted_files.push(...folderResult.deleted_files);
      result.skipped_files.push(...folderResult.skipped_files);
    }

    // ============================================
    // 5. LOG RESULTS TO DATABASE
    // ============================================
    result.execution_time_ms = Date.now() - startTime;
    await logCleanupResults(supabase, result);
    
    console.log(`✅ [CLEANUP] Cleanup completed in ${result.execution_time_ms}ms`);
    console.log(`📊 [CLEANUP] Deleted: ${result.files_deleted}, Skipped: ${result.files_skipped}, Errors: ${result.errors.length}`);

    if (dryRun) {
      console.log('🔍 [CLEANUP] DRY-RUN MODE - No files were actually deleted');
    }

    return new Response(JSON.stringify(result), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
    });

  } catch (error) {
    console.error('❌ [CLEANUP] Fatal error:', error);
    
    const errorResult: CleanupResult = {
      files_deleted: 0,
      files_skipped: 0,
      total_storage_freed_mb: 0,
      errors: [`Fatal error: ${error.message}`],
      deleted_files: [],
      skipped_files: [],
      execution_time_ms: Date.now() - startTime,
      dry_run: false
    };

    return new Response(JSON.stringify(errorResult), { 
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
    });
  }
});

// ============================================
// AUTHENTICATION & REQUEST HELPERS
// ============================================

async function authenticateRequest(req: Request): Promise<string | null> {
  // Check for Supabase authorization header
  const authHeader = req.headers.get('authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    console.warn('⚠️ [CLEANUP] Missing or invalid authorization header');
    return 'Missing authorization header';
  }
  
  // Additional API key check for extra security
  const expectedApiKey = Deno.env.get('CLEANUP_API_KEY');
  const providedApiKey = req.headers.get('x-api-key');
  
  if (expectedApiKey && (!providedApiKey || providedApiKey !== expectedApiKey)) {
    console.warn('⚠️ [CLEANUP] Invalid or missing API key');
    return 'Unauthorized';
  }

  return null; // No error
}

// ============================================
// FOLDER PROCESSING
// ============================================

async function processFolder(
  supabase: any,
  bucketName: string,
  folder: string,
  cutoffTime: Date,
  dryRun: boolean
): Promise<{
  deleted_count: number;
  skipped_count: number;
  storage_freed_mb: number;
  errors: string[];
  deleted_files: Array<{
    path: string;
    folder: string;
    age_hours: number;
    size_bytes: number;
    deleted_at: string;
  }>;
  skipped_files: Array<{
    path: string;
    folder: string;
    age_hours: number;
    reason: string;
  }>;
}> {
  const deletedFiles: Array<{
    path: string;
    folder: string;
    age_hours: number;
    size_bytes: number;
    deleted_at: string;
  }> = [];

  const skippedFiles: Array<{
    path: string;
    folder: string;
    age_hours: number;
    reason: string;
  }> = [];

  const errors: string[] = [];
  let deletedCount = 0;
  let skippedCount = 0;
  let storageFreedMB = 0;

  try {
    // List all files in folder (recursively)
    const allFiles = await listAllFilesRecursive(supabase, bucketName, folder);

    console.log(`📋 [CLEANUP] Found ${allFiles.length} files in ${folder}/`);

    for (const file of allFiles) {
      try {
        const filePath = `${folder}/${file.name}`;
        const fileTime = new Date(file.updated_at || file.created_at);
        const ageHours = (Date.now() - fileTime.getTime()) / (1000 * 60 * 60);

        // Check if file is older than 24 hours
        if (fileTime < cutoffTime) {
          const fileSize = file.metadata?.size || 0;
          const sizeMB = fileSize / (1024 * 1024);

          if (dryRun) {
            console.log(`🔍 [DRY-RUN] Would delete: ${filePath} (age: ${ageHours.toFixed(1)}h, size: ${sizeMB.toFixed(2)}MB)`);
            deletedFiles.push({
              path: filePath,
              folder: folder,
              age_hours: Math.round(ageHours * 10) / 10,
              size_bytes: fileSize,
              deleted_at: new Date().toISOString()
            });
            deletedCount++;
            storageFreedMB += sizeMB;
          } else {
            // Actually delete the file
            const { error: deleteError } = await supabase.storage
              .from(bucketName)
              .remove([filePath]);

            if (deleteError) {
              errors.push(`Failed to delete ${filePath}: ${deleteError.message}`);
              console.error(`❌ [CLEANUP] Failed to delete ${filePath}:`, deleteError);
            } else {
              console.log(`✅ [CLEANUP] Deleted: ${filePath} (age: ${ageHours.toFixed(1)}h)`);
              deletedFiles.push({
                path: filePath,
                folder: folder,
                age_hours: Math.round(ageHours * 10) / 10,
                size_bytes: fileSize,
                deleted_at: new Date().toISOString()
              });
              deletedCount++;
              storageFreedMB += sizeMB;
            }
        }
      } else {
          // File is too new, skip it
          skippedFiles.push({
            path: filePath,
            folder: folder,
            age_hours: Math.round(ageHours * 10) / 10,
            reason: 'File is less than 24 hours old'
          });
          skippedCount++;
        }
      } catch (fileError: any) {
        errors.push(`Error processing file ${file.name}: ${fileError.message}`);
        console.error(`❌ [CLEANUP] Error processing file ${file.name}:`, fileError);
      }
    }

  } catch (error: any) {
    errors.push(`Failed to process folder ${folder}: ${error.message}`);
    console.error(`❌ [CLEANUP] Failed to process folder ${folder}:`, error);
  }

  return {
    deleted_count: deletedCount,
    skipped_count: skippedCount,
    storage_freed_mb: Math.round(storageFreedMB * 100) / 100,
    errors,
    deleted_files: deletedFiles,
    skipped_files: skippedFiles
  };
}

// ============================================
// RECURSIVE FILE LISTING
// ============================================

async function listAllFilesRecursive(
  supabase: any,
  bucketName: string,
  folder: string,
  allFiles: FileInfo[] = [],
  currentPath: string = folder
): Promise<FileInfo[]> {
  try {
    // List items in current path
    const { data: items, error } = await supabase.storage
      .from(bucketName)
      .list(currentPath, {
        limit: 1000,
        sortBy: { column: 'created_at', order: 'asc' }
      });

    if (error) {
      console.error(`❌ [CLEANUP] Error listing ${currentPath}:`, error);
      return allFiles;
    }
    
    if (!items || items.length === 0) {
      return allFiles;
    }

    for (const item of items) {
      // Supabase Storage returns folders with metadata.id = null or empty
      // Files have a valid id and metadata
      const isFolder = !item.id || item.metadata === null || 
                       (item.name && !item.name.includes('.'));

      if (isFolder && item.name) {
        // Recursively list files in subfolder
        const subfolderPath = currentPath === folder 
          ? `${folder}/${item.name}` 
          : `${currentPath}/${item.name}`;
        
        console.log(`📂 [CLEANUP] Entering subfolder: ${subfolderPath}`);
        await listAllFilesRecursive(supabase, bucketName, folder, allFiles, subfolderPath);
      } else if (item.id) {
        // It's a file, add to list
        const filePath = currentPath === folder 
          ? `${folder}/${item.name}` 
          : `${currentPath}/${item.name}`;
        
        allFiles.push({
          name: filePath,
          id: item.id || '',
          updated_at: item.updated_at || item.created_at || new Date().toISOString(),
          created_at: item.created_at || item.updated_at || new Date().toISOString(),
          last_accessed_at: item.last_accessed_at || '',
          metadata: {
            size: item.metadata?.size || 0,
            mimetype: item.metadata?.mimetype || 'image/jpeg'
          }
        });
      }
    }

    // Note: Supabase Storage list() has a limit of 1000 items per folder
    if (items.length === 1000) {
      console.warn(`⚠️ [CLEANUP] Found 1000 items in ${currentPath} - may have more files`);
    }
    
    return allFiles;
  } catch (error: any) {
    console.error(`❌ [CLEANUP] Error in listAllFilesRecursive for ${currentPath}:`, error);
    return allFiles;
  }
}

// ============================================
// LOGGING & NOTIFICATIONS
// ============================================

// ============================================
// DATABASE LOGGING
// ============================================

async function logCleanupResults(supabase: any, result: CleanupResult): Promise<void> {
  try {
    await supabase
      .from('cleanup_logs')
      .insert({
        operation: 'cleanup_images',
        details: {
          files_deleted: result.files_deleted,
          files_skipped: result.files_skipped,
          total_storage_freed_mb: result.total_storage_freed_mb,
          errors: result.errors,
          deleted_files: result.deleted_files,
          skipped_files: result.skipped_files,
          execution_time_ms: result.execution_time_ms,
          dry_run: result.dry_run
        },
        created_at: new Date().toISOString()
      });

    console.log('✅ [CLEANUP] Results logged to database');
  } catch (error: any) {
    console.warn(`⚠️ [CLEANUP] Failed to log results: ${error.message}`);
    // Don't throw - logging failure shouldn't break cleanup
  }
}
