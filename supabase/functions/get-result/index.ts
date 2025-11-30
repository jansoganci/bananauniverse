import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { createLogger } from '../_shared/logger.ts';

// ============================================
// GET-RESULT: FETCH COMPLETED JOB RESULT
// ============================================
// This function allows iOS to fetch the result of a submitted job.
// It queries the job_results table and returns the status and image URL.
// Execution time: < 500ms (simple database query)

interface GetResultRequest {
  job_id: string;
  device_id?: string;
  user_id?: string;
}

interface GetResultResponse {
  success: boolean;
  status?: string;           // 'pending' | 'completed' | 'failed'
  image_url?: string;        // Signed URL to processed image
  error?: string;
  created_at?: string;
  completed_at?: string;
}

Deno.serve(async (req: Request) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, device-id',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  };

  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Initialize logger early
    let logger = createLogger('get-result');
    logger.info('Request received', { method: req.method });

    // ============================================
    // 1. PARSE REQUEST
    // ============================================
    logger.step('1. Parsing request');
    const requestData: GetResultRequest = await req.json();
    let { job_id, device_id, user_id } = requestData;

    // Try to get device_id from header if not in body
    if (!device_id) {
      const deviceIdHeader = req.headers.get('device-id');
      if (deviceIdHeader) {
        device_id = deviceIdHeader;
        logger.debug('Device ID from header', { deviceId: device_id });
      }
    }

    // Validate required fields
    if (!job_id) {
      logger.error('Missing job_id');
      return new Response(
        JSON.stringify({ success: false, error: 'Missing job_id' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Update logger with context
    logger = createLogger('get-result', `req-${Date.now()}-${job_id}`, {
      deviceId: device_id,
      userId: user_id,
      jobId: job_id,
    });
    
    logger.step('1.1. Request parsed', { jobId: job_id, hasDeviceId: !!device_id, hasUserId: !!user_id });

    // ============================================
    // 2. INITIALIZE SUPABASE CLIENT
    // ============================================
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { autoRefreshToken: false, persistSession: false }
    });

    // ============================================
    // 3. AUTHENTICATE USER
    // ============================================
    logger.step('2. Authenticating user');
    const { userIdentifier, userType } = await authenticateUser(supabase, req, device_id, user_id, logger);
    logger.step('2.1. User authenticated', { userType });

    // ============================================
    // 4. SET DEVICE ID SESSION FOR RLS
    // ============================================
    if (device_id) {
      logger.step('3. Setting device ID session');
      await setDeviceIdSession(supabase, device_id, logger);
    }

    // ============================================
    // 5. FETCH JOB RESULT
    // ============================================
    logger.step('4. Fetching job result');
    const jobData = await fetchJobResult(supabase, job_id, logger);
    
    // ✅ NEW: Sign Image URL if it's a path (Security Upgrade)
    let signedImageUrl = jobData.image_url;
    if (signedImageUrl && !signedImageUrl.startsWith('http')) {
      logger.step('4.2. Signing image path');
      const { data, error } = await supabase.storage
        .from('noname-banana-images-prod')
        .createSignedUrl(signedImageUrl, 3600); // 1 hour validity
        
      if (!error && data?.signedUrl) {
        signedImageUrl = data.signedUrl;
        logger.debug('Image path signed successfully');
      } else {
        logger.error('Failed to sign image path', { error });
        // We continue with the original path, though client likely won't be able to load it
      }
    }

    logger.step('4.1. Job result fetched', { 
      status: jobData.status,
      hasImage: !!signedImageUrl,
      hasError: !!jobData.error
    });

    // ============================================
    // 6. BUILD AND RETURN RESPONSE
    // ============================================
    logger.step('5. Building response');
    const response: GetResultResponse = {
      success: true,
      status: jobData.status,
      image_url: signedImageUrl || undefined,
      error: jobData.error || undefined,
      created_at: jobData.created_at,
      completed_at: jobData.completed_at || undefined
    };

    logger.summary('success', {
      jobId: job_id,
      status: jobData.status,
      hasImage: !!jobData.image_url,
    });

    return new Response(
      JSON.stringify(response),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error: any) {
    // Try to log error (logger might not be initialized)
    try {
      const logger = createLogger('get-result');
      logger.error('Fatal error', error);
      logger.summary('error', { error: error.message, errorName: error.name });
    } catch {
      console.error('❌ [GET-RESULT] Unexpected error:', error.message);
    }
    
    // Handle specific error types
    if (error.name === 'AuthenticationError') {
      return new Response(
        JSON.stringify({ success: false, error: error.message }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }
    
    if (error.name === 'JobNotFoundError') {
      return new Response(
        JSON.stringify({ success: false, error: error.message }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }
    
    return new Response(
      JSON.stringify({ success: false, error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

// ============================================
// AUTHENTICATION & USER IDENTIFICATION
// ============================================

async function authenticateUser(
  supabase: any,
  req: Request,
  device_id: string | undefined,
  user_id: string | undefined,
  logger?: any
): Promise<{userIdentifier: string, userType: 'authenticated' | 'anonymous'}> {
    const authHeader = req.headers.get('authorization');
  
    if (authHeader && authHeader.startsWith('Bearer ')) {
      try {
        const token = authHeader.split(' ')[1];
        if (logger) logger.debug('Validating JWT token');

        const { data: { user }, error } = await supabase.auth.getUser(token);

        if (error || !user) {
          throw new Error(`JWT validation failed: ${error?.message || 'No user'}`);
        }

      const userIdentifier = user_id || user.id;
        if (logger) logger.debug('JWT validated', { userId: user.id });

      return {
        userIdentifier,
        userType: 'authenticated'
      };
      } catch (error: any) {
        if (logger) logger.info('JWT auth failed, using device_id fallback', { error: error.message });

        if (!device_id) {
        const authError = new Error('Authentication failed and no device_id provided');
        (authError as any).name = 'AuthenticationError';
        (authError as any).details = error.message || 'Invalid or expired token';
        throw authError;
      }

        if (logger) logger.debug('Falling back to anonymous user', { deviceId: device_id });
      return {
        userIdentifier: device_id,
        userType: 'anonymous'
      };
      }
    } else {
      if (logger) logger.debug('No auth header, checking device_id');

      if (!device_id) {
      const authError = new Error('Authentication or device_id required');
      (authError as any).name = 'AuthenticationError';
      throw authError;
    }

      if (logger) logger.debug('Using anonymous user', { deviceId: device_id });
    return {
      userIdentifier: device_id,
      userType: 'anonymous'
    };
  }
    }

    // ============================================
// RLS SESSION MANAGEMENT
    // ============================================

async function setDeviceIdSession(supabase: any, device_id: string, logger?: any): Promise<void> {
      if (logger) logger.debug('Setting device_id session variable', { deviceId: device_id });
  
      const { error: sessionError } = await supabase.rpc('set_device_id_session', {
        p_device_id: device_id
      });

      if (sessionError) {
        if (logger) logger.warn('Failed to set device_id session', { error: sessionError.message });
      } else {
        if (logger) logger.debug('Device ID session variable set');
      }
    }

    // ============================================
// DATABASE QUERIES
    // ============================================

async function fetchJobResult(supabase: any, job_id: string, logger?: any): Promise<{
  status: string;
  image_url: string | null;
  error: string | null;
  created_at: string;
  completed_at: string | null;
}> {
    if (logger) logger.debug('Querying job_results table', { jobId: job_id });

    const { data, error } = await supabase
      .from('job_results')
      .select('fal_job_id, status, image_url, error, created_at, completed_at')
      .eq('fal_job_id', job_id)
      .single();

    if (error) {
      if (logger) logger.error('Query failed', { error: error.message, errorCode: error.code });

      // Check if job doesn't exist
      if (error.code === 'PGRST116') {
      const notFoundError = new Error('Job not found');
      (notFoundError as any).name = 'JobNotFoundError';
      throw notFoundError;
    }

    const dbError = new Error('Failed to fetch job result');
    (dbError as any).name = 'DatabaseError';
    throw dbError;
  }

  if (logger) logger.debug('Job result retrieved', { status: data.status });
  return data;
  }
