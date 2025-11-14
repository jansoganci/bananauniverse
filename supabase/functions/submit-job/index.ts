import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { createLogger } from '../_shared/logger.ts';

// ============================================
// SUBMIT-JOB: ASYNC POLLING ARCHITECTURE
// ============================================
// This function submits a job to fal.ai's async queue
// and returns immediately with a job_id for polling.
// Execution time: < 2 seconds

interface SubmitJobRequest {
  image_url: string;
  prompt: string;
  device_id?: string;
  user_id?: string;
  client_request_id?: string;
}

interface SubmitJobResponse {
  success: boolean;
  job_id?: string;           // fal.ai request_id for webhook tracking
  status?: string;            // 'pending' (waiting for webhook)
  estimated_time?: number;    // Estimated processing time in seconds
  error?: string;
  quota_info?: {
    credits_remaining: number;
    is_premium: boolean; // Always false, kept for backward compatibility
  };
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
    // Initialize logger early (before parsing to get requestId)
    // We'll update it with context after parsing
    let logger = createLogger('submit-job');
    
    logger.info('Request received', { method: req.method });

    // Parse and validate request
    const parseResult = await parseAndValidateRequest(req, corsHeaders, logger);
    if (parseResult.error) {
      logger.error('Request parsing failed');
      return parseResult.error;
    }
    const { image_url, prompt, device_id, requestId, user_id } = parseResult.data!;
    
    // Update logger with request context
    logger = createLogger('submit-job', requestId, {
      deviceId: device_id,
      userId: user_id,
    });
    
    logger.step('1. Request parsed', { 
      hasImage: !!image_url, 
      hasPrompt: !!prompt,
      userType: user_id ? 'authenticated' : 'anonymous'
    });

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { autoRefreshToken: false, persistSession: false }
    });

    // Authenticate user
    logger.step('2. Authenticating user');
    const authResult = await authenticateUser(req, supabase, user_id, device_id, corsHeaders, logger);
    if (authResult.error) {
      logger.error('Authentication failed');
      return authResult.error;
    }
    const { userIdentifier, userType } = authResult.data!;
    
    logger.step('2. User authenticated', { userType });

    // Set device ID session for RLS
    logger.step('3. Setting device ID session');
    await setDeviceIdSession(supabase, device_id, logger);

    // Consume credits
    logger.step('4. Consuming credits');
    const creditResult = await consumeCredits(supabase, userType, userIdentifier, requestId, corsHeaders, logger);
    if (creditResult.error) {
      logger.error('Credit consumption failed');
      return creditResult.error;
    }
    const { quotaResult } = creditResult.data!;
    
    logger.step('4.1. Credits consumed', {
      creditsRemaining: quotaResult.credits_remaining,
      idempotent: quotaResult.idempotent || false
    });

    // Submit to fal.ai
    logger.step('5. Submitting to fal.ai');
    const falResult = await submitToFalAI(supabase, supabaseUrl, image_url, prompt, userType, userIdentifier, requestId, corsHeaders, logger);
    if (falResult.error) {
      logger.error('Fal.ai submission failed');
      return falResult.error;
    }
    const { falJobId } = falResult.data!;
    
    logger.step('5.1. Submitted to fal.ai', { falJobId });

    // Insert job result
    logger.step('6. Inserting job result');
    const insertResult = await insertJobResult(supabase, falJobId, userType, userIdentifier, requestId, corsHeaders, logger);
    if (insertResult.error) {
      logger.error('Job result insertion failed');
      return insertResult.error;
    }
    
    logger.step('6.1. Job result inserted', { jobId: falJobId });

    // Return success response
    const response: SubmitJobResponse = {
      success: true,
      job_id: falJobId,
      status: 'pending',
      estimated_time: 15,
      quota_info: {
        credits_remaining: quotaResult.credits_remaining || 0,
        is_premium: false
      }
    };

    logger.summary('success', {
      jobId: falJobId,
      creditsRemaining: quotaResult.credits_remaining
    });

    return new Response(
      JSON.stringify(response),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error: any) {
    // Try to log error (logger might not be initialized)
    try {
      const logger = createLogger('submit-job');
      logger.error('Fatal error', error);
      logger.summary('error', { error: error.message });
    } catch {
      // Fallback if logger creation fails
      const fallbackLogger = createLogger('submit-job');
      fallbackLogger.error('Fatal error (fallback)', error);
    }
    
    return new Response(
      JSON.stringify({ success: false, error: error.message || 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

    // ============================================
// HELPER FUNCTIONS
    // ============================================

async function parseAndValidateRequest(
  req: Request,
  corsHeaders: Record<string, string>,
  logger?: any
): Promise<{ error?: Response; data?: { image_url: string; prompt: string; device_id?: string; requestId: string; user_id?: string } }> {
    const requestData: SubmitJobRequest = await req.json();
    let { image_url, prompt, device_id, user_id, client_request_id } = requestData;

    // Generate request ID for idempotency
    const requestId = client_request_id || crypto.randomUUID();
    if (logger) logger.debug('Request ID generated', { requestId, fromClient: !!client_request_id });

    // Try to get device_id from header if not in body
    if (!device_id) {
      const deviceIdHeader = req.headers.get('device-id');
      if (deviceIdHeader) {
        device_id = deviceIdHeader;
        if (logger) logger.debug('Device ID from header', { deviceId: device_id });
      }
    }

    // Validate required fields
    if (!image_url || !prompt) {
      if (logger) logger.warn('Missing required fields', { hasImageUrl: !!image_url, hasPrompt: !!prompt });
      return {
        error: new Response(
          JSON.stringify({ success: false, error: 'Missing image_url or prompt' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      };
    }

    if (logger) logger.debug('Request validated', { 
      imageUrl: image_url.substring(0, 50) + '...',
      promptPreview: prompt.substring(0, 50) + '...',
      hasDeviceId: !!device_id,
      hasUserId: !!user_id
    });

  return {
    data: { image_url, prompt, device_id, requestId, user_id }
  };
}

async function authenticateUser(
  req: Request,
  supabase: any,
  user_id_from_body: string | undefined,
  device_id: string | undefined,
  corsHeaders: Record<string, string>,
  logger?: any
): Promise<{ error?: Response; data?: { userIdentifier: string; userType: 'authenticated' | 'anonymous' } }> {
    let userIdentifier: string;
    let userType: 'authenticated' | 'anonymous';

    const authHeader = req.headers.get('authorization');
    if (authHeader && authHeader.startsWith('Bearer ')) {
      try {
        const token = authHeader.split(' ')[1];
        if (logger) logger.debug('Validating JWT token');

        const { data: { user }, error } = await supabase.auth.getUser(token);

        if (error || !user) {
          throw new Error(`JWT validation failed: ${error?.message || 'No user'}`);
        }

      userIdentifier = user_id_from_body || user.id;
        userType = 'authenticated';

        if (logger) logger.debug('Authenticated user', { userId: user.id });
      } catch (error: any) {
        if (logger) logger.info('JWT auth failed, using device_id fallback', { error: error.message });

        if (!device_id) {
          if (logger) logger.error('Authentication failed and no device_id provided');
          return {
            error: new Response(
              JSON.stringify({
                success: false,
                error: 'Authentication failed and no device_id provided',
                details: error.message || 'Invalid or expired token'
              }),
              { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
          };
        }

        userIdentifier = device_id;
        userType = 'anonymous';

        if (logger) logger.debug('Anonymous user (JWT fallback)', { deviceId: device_id });
      }
    } else {
      if (logger) logger.debug('No auth header, checking device_id');

      if (!device_id) {
        if (logger) logger.error('Authentication or device_id required');
        return {
          error: new Response(
            JSON.stringify({ success: false, error: 'Authentication or device_id required' }),
            { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          )
        };
      }

      userIdentifier = device_id;
      userType = 'anonymous';

      if (logger) logger.debug('Anonymous user (no auth header)', { deviceId: device_id });
    }

  return {
    data: { userIdentifier, userType }
  };
}

async function setDeviceIdSession(supabase: any, device_id?: string, logger?: any): Promise<void> {
    if (device_id) {
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
}

async function consumeCredits(
  supabase: any,
  userType: 'authenticated' | 'anonymous',
  userIdentifier: string,
  requestId: string,
  corsHeaders: Record<string, string>,
  logger?: any
): Promise<{ error?: Response; data?: { quotaResult: any } }> {
    if (logger) logger.debug('Calling consume_credits RPC', { userType });

    try {
      const { data, error } = await supabase.rpc('consume_credits', {
        p_user_id: userType === 'authenticated' ? userIdentifier : null,
        p_device_id: userType === 'anonymous' ? userIdentifier : null,
        p_amount: 1,
        p_idempotency_key: requestId
      });

      if (error) {
        if (logger) logger.error('consume_credits RPC failed', { error: error.message });
      return {
        error: new Response(
          JSON.stringify({ success: false, error: 'Credit validation failed' }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      };
      }

    const quotaResult = data;
      if (logger) logger.debug('consume_credits RPC result', quotaResult);

      // Check for idempotent request
      if (quotaResult?.idempotent === true) {
        if (logger) logger.info('Idempotent request detected', { previousJobId: quotaResult.previous_job_id });

      return {
        error: new Response(
          JSON.stringify({
            success: true,
            idempotent: true,
            job_id: quotaResult.previous_job_id || null,
            status: 'completed',
            quota_info: quotaResult
          }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      };
    }

    // Check credit result
    if (!quotaResult.success) {
      if (logger) logger.warn('Credit check failed', { 
        error: quotaResult.error, 
        creditsRemaining: quotaResult.credits_remaining 
      });

      return {
        error: new Response(
        JSON.stringify({
          success: false,
          error: quotaResult.error || 'Insufficient credits. Purchase more credits to continue.',
          quota_info: {
            credits_remaining: quotaResult.credits_remaining || 0,
            is_premium: false
          }
        }),
        { status: 402, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      };
    }

    if (logger) logger.info('Credit consumed successfully', { creditsRemaining: quotaResult.credits_remaining });

    return {
      data: { quotaResult }
    };
  } catch (error: any) {
    if (logger) logger.error('Credit consumption exception', error);
    return {
      error: new Response(
        JSON.stringify({ success: false, error: 'Credit system error' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    };
  }
}

async function submitToFalAI(
  supabase: any,
  supabaseUrl: string,
  image_url: string,
  prompt: string,
  userType: 'authenticated' | 'anonymous',
  userIdentifier: string,
  requestId: string,
  corsHeaders: Record<string, string>,
  logger?: any
): Promise<{ error?: Response; data?: { falJobId: string } }> {
    if (logger) logger.debug('Submitting to fal.ai async queue');

    const falAIKey = Deno.env.get('FAL_AI_API_KEY');
    if (!falAIKey) {
      if (logger) logger.error('FAL_AI_API_KEY not configured');
      const refundResult = await refundCredit(supabase, userType, userIdentifier, requestId, logger);
      if (!refundResult.success) {
        if (logger) logger.warn('Credit refund failed (non-critical)', { error: refundResult.error });
      }
      return {
        error: new Response(
          JSON.stringify({ success: false, error: 'FAL_AI_API_KEY not configured' }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      };
    }

    // Fal.ai does NOT preserve query parameters when calling webhooks
    // So we don't include token in URL - security is handled via:
    // 1. JWT verification disabled for webhook-handler function
    // 2. Job validation (request_id must exist in database)
    // 3. Rate limiting per IP
    // 4. Optional: Fal.ai signature verification (can be added later)
    const webhookUrl = `${supabaseUrl}/functions/v1/webhook-handler`;

    const falAIRequest = {
      prompt: prompt,
      image_urls: [image_url],
      num_images: 1,
      output_format: 'jpeg',
    };

    // Build URL with fal_webhook query parameter (required by fal.ai)
    const falApiUrl = `https://queue.fal.run/fal-ai/nano-banana/edit?fal_webhook=${encodeURIComponent(webhookUrl)}`;

    if (logger) logger.debug('Fal.ai request prepared', { 
      hasWebhook: !!webhookUrl,
      webhookUrl: webhookUrl,
      falApiUrl: falApiUrl
    });

    try {
      const falResponse = await fetch(falApiUrl, {
        method: 'POST',
        headers: {
          'Authorization': `Key ${falAIKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(falAIRequest),
      });

      if (!falResponse.ok) {
        const errorText = await falResponse.text();
        if (logger) logger.error('Fal.ai queue submission failed', { 
          status: falResponse.status, 
          error: errorText.substring(0, 200) 
        });

      const refundResult = await refundCredit(supabase, userType, userIdentifier, requestId, logger);
      if (!refundResult.success) {
        if (logger) logger.warn('Credit refund failed (non-critical)', { error: refundResult.error });
      }

      return {
        error: new Response(
          JSON.stringify({ success: false, error: `fal.ai queue submission failed: ${falResponse.status}` }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      };
      }

      const falResult = await falResponse.json();
      if (logger) logger.debug('Fal.ai queue submission successful', { requestId: falResult.request_id });

    const falJobId = falResult.request_id;

      if (!falJobId) {
        throw new Error('No request_id returned from fal.ai queue');
      }

      if (logger) logger.debug('Fal.ai job ID extracted', { falJobId });

    return {
      data: { falJobId }
    };
    } catch (error: any) {
      if (logger) logger.error('Fal.ai submission exception', error);

    const refundResult = await refundCredit(supabase, userType, userIdentifier, requestId, logger);
    if (!refundResult.success) {
      if (logger) logger.warn('Credit refund failed (non-critical)', { error: refundResult.error });
    }

    return {
      error: new Response(
        JSON.stringify({ success: false, error: 'Failed to submit job to fal.ai queue' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    };
    }
}

async function insertJobResult(
  supabase: any,
  falJobId: string,
  userType: 'authenticated' | 'anonymous',
  userIdentifier: string,
  requestId: string,
  corsHeaders: Record<string, string>,
  logger?: any
): Promise<{ error?: Response }> {
    const { error: insertError } = await supabase
      .from('job_results')
      .insert({
        fal_job_id: falJobId,
        user_id: userType === 'authenticated' ? userIdentifier : null,
        device_id: userType === 'anonymous' ? userIdentifier : null,
        status: 'pending'
      });

    if (insertError) {
      if (logger) logger.error('Job result insert failed', { error: insertError.message });

    const refundResult = await refundCredit(supabase, userType, userIdentifier, requestId, logger);
    if (!refundResult.success) {
      if (logger) logger.warn('Credit refund failed (non-critical)', { error: refundResult.error });
    }

    return {
      error: new Response(
        JSON.stringify({ success: false, error: 'Failed to create job record' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    };
    }

    if (logger) logger.debug('Job result entry created', { falJobId, status: 'pending' });
  return {};
}

// ============================================
// HELPER: REFUND CREDIT ON FAILURE
// ============================================

async function refundCredit(
  supabase: any,
  userType: 'authenticated' | 'anonymous',
  userIdentifier: string,
  requestId: string,
  logger?: any
): Promise<{success: boolean, error?: string}> {
  if (logger) logger.debug('Attempting credit refund', { userType, requestId });

  try {
    const { data, error } = await supabase.rpc('add_credits', {
      p_user_id: userType === 'authenticated' ? userIdentifier : null,
      p_device_id: userType === 'anonymous' ? userIdentifier : null,
      p_amount: 1,
      p_idempotency_key: `refund-${requestId}`
    });

    if (error) {
      if (logger) logger.error('Credit refund failed', { error: error.message });
      return {
        success: false,
        error: error.message || 'Credit refund failed'
      };
    } else {
      if (logger) logger.info('Credit refund successful', { 
        creditsAdded: data?.credits_added,
        creditsRemaining: data?.credits_remaining 
      });
      return { success: true };
    }
  } catch (error: any) {
    if (logger) logger.error('Credit refund exception', error);
    return {
      success: false,
      error: error.message || 'Unexpected error during credit refund'
    };
  }
}
