import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

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
    console.log('🔍 [GET-RESULT] Request started');

    // ============================================
    // 1. PARSE REQUEST
    // ============================================
    const requestData: GetResultRequest = await req.json();
    let { job_id, device_id, user_id } = requestData;

    // Try to get device_id from header if not in body
    if (!device_id) {
      const deviceIdHeader = req.headers.get('device-id');
      if (deviceIdHeader) {
        device_id = deviceIdHeader;
        console.log('🔧 [GET-RESULT] Device ID from header:', device_id);
      }
    }

    // Validate required fields
    if (!job_id) {
      return new Response(
        JSON.stringify({ success: false, error: 'Missing job_id' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log('🎫 [GET-RESULT] Job ID:', job_id);

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
    const { userIdentifier, userType } = await authenticateUser(supabase, req, device_id, user_id);

    // ============================================
    // 4. SET DEVICE ID SESSION FOR RLS
    // ============================================
    if (device_id) {
      await setDeviceIdSession(supabase, device_id);
    }

    // ============================================
    // 5. FETCH JOB RESULT
    // ============================================
    const jobData = await fetchJobResult(supabase, job_id);
    console.log('✅ [GET-RESULT] Job found:', jobData.status);

    // ============================================
    // 6. BUILD AND RETURN RESPONSE
    // ============================================
    const response: GetResultResponse = {
      success: true,
      status: jobData.status,
      image_url: jobData.image_url || undefined,
      error: jobData.error || undefined,
      created_at: jobData.created_at,
      completed_at: jobData.completed_at || undefined
    };

    console.log('✅ [GET-RESULT] Response:', JSON.stringify(response, null, 2));

    return new Response(
      JSON.stringify(response),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error: any) {
    console.error('❌ [GET-RESULT] Unexpected error:', error.message);
    
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
  user_id: string | undefined
): Promise<{userIdentifier: string, userType: 'authenticated' | 'anonymous'}> {
  const authHeader = req.headers.get('authorization');
  
  if (authHeader && authHeader.startsWith('Bearer ')) {
    try {
      const token = authHeader.split(' ')[1];
      console.log('🔑 [GET-RESULT] Validating JWT token...');

      const { data: { user }, error } = await supabase.auth.getUser(token);

      if (error || !user) {
        throw new Error(`JWT validation failed: ${error?.message || 'No user'}`);
      }

      const userIdentifier = user_id || user.id;
      console.log('✅ [GET-RESULT] Authenticated user:', user.id);

      return {
        userIdentifier,
        userType: 'authenticated'
      };
    } catch (error: any) {
      console.log('⚠️ [GET-RESULT] JWT auth failed, checking device_id fallback...');

      if (!device_id) {
        const authError = new Error('Authentication failed and no device_id provided');
        (authError as any).name = 'AuthenticationError';
        (authError as any).details = error.message || 'Invalid or expired token';
        throw authError;
      }

      console.log('🔓 [GET-RESULT] Anonymous user:', device_id);
      return {
        userIdentifier: device_id,
        userType: 'anonymous'
      };
    }
  } else {
    console.log('🔓 [GET-RESULT] No auth header, checking device_id...');

    if (!device_id) {
      const authError = new Error('Authentication or device_id required');
      (authError as any).name = 'AuthenticationError';
      throw authError;
    }

    console.log('🔓 [GET-RESULT] Anonymous user:', device_id);
    return {
      userIdentifier: device_id,
      userType: 'anonymous'
    };
  }
}

// ============================================
// RLS SESSION MANAGEMENT
// ============================================

async function setDeviceIdSession(supabase: any, device_id: string): Promise<void> {
  console.log('🔧 [RLS] Setting device_id session variable:', device_id);
  
  const { error: sessionError } = await supabase.rpc('set_device_id_session', {
    p_device_id: device_id
  });

  if (sessionError) {
    console.error('[GET-RESULT] Failed to set device_id session:', sessionError);
  } else {
    console.log('✅ [RLS] Device ID session variable set');
  }
}

// ============================================
// DATABASE QUERIES
// ============================================

async function fetchJobResult(supabase: any, job_id: string): Promise<{
  status: string;
  image_url: string | null;
  error: string | null;
  created_at: string;
  completed_at: string | null;
}> {
  console.log('🔍 [GET-RESULT] Querying job_results...');

  const { data, error } = await supabase
    .from('job_results')
    .select('fal_job_id, status, image_url, error, created_at, completed_at')
    .eq('fal_job_id', job_id)
    .single();

  if (error) {
    console.error('❌ [GET-RESULT] Query failed:', error);

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

  return data;
}
