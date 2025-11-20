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
  image_url: string;              // Backward compatibility (single image)
  image_urls?: string[];          // NEW: Array of Storage URLs (preferred)
  prompt: string;
  device_id?: string;
  user_id?: string;
  client_request_id?: string;
  // NEW PARAMETERS:
  model_type?: 'nano-banana' | 'nano-banana-pro';
  aspect_ratio?: string;          // '1:1', '16:9', '9:16', '4:3', etc.
  output_format?: 'jpeg' | 'png' | 'webp';
  resolution?: '1K' | '2K' | '4K'; // Pro model only
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
    const {
      image_url,
      image_urls,
      prompt,
      device_id,
      requestId,
      user_id,
      model_type,
      aspect_ratio,
      output_format,
      resolution
    } = parseResult.data!;
    
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

    // Calculate credit cost based on model type and resolution
    const credit_cost = calculateCreditCost(model_type, resolution);
    logger.step('3.1. Calculated credit cost', {
      modelType: model_type,
      resolution: resolution,
      cost: credit_cost
    });

    // Atomic job creation (deduct credits + create job)
    logger.step('4. Creating job atomically (credits + job record)');
    const atomicResult = await supabase.rpc('submit_job_atomic', {
      p_client_request_id: requestId,
      p_user_id: userType === 'authenticated' ? userIdentifier : null,
      p_device_id: userType === 'anonymous' ? userIdentifier : null,
      p_idempotency_key: requestId,
      p_credit_cost: credit_cost,        // NEW
      p_model_type: model_type,          // NEW
      p_aspect_ratio: aspect_ratio,      // NEW
      p_output_format: output_format,    // NEW
      p_resolution: resolution || null,  // NEW (nullable)
      p_num_images: image_urls.length    // NEW
    });

    if (atomicResult.error || !atomicResult.data?.success) {
      logger.error('Atomic job creation failed', {
        error: atomicResult.error?.message || atomicResult.data?.error
      });
      return new Response(
        JSON.stringify({
          success: false,
          error: atomicResult.data?.error || 'Failed to create job and deduct credits'
        }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const { job_id, credits_remaining, duplicate } = atomicResult.data;

    logger.step('4.1. Job created atomically', {
      jobId: job_id,
      creditsRemaining: credits_remaining,
      duplicate: duplicate || false
    });

    // Submit to fal.ai
    logger.step('5. Submitting to fal.ai');
    const falResult = await submitToFalAI(
      supabase,
      supabaseUrl,
      image_urls,          // Changed to array
      prompt,
      model_type,          // NEW
      aspect_ratio,        // NEW
      output_format,       // NEW
      resolution,          // NEW
      userType,
      userIdentifier,
      requestId,
      corsHeaders,
      logger
    );
    if (falResult.error) {
      logger.error('Fal.ai submission failed - marking job as failed and refunding credits');
      await markJobFailedAndRefund(supabase, job_id, userType, userIdentifier, credit_cost, requestId, logger);
      return falResult.error;
    }
    const { falJobId } = falResult.data!;

    logger.step('5.1. Submitted to fal.ai', { falJobId });

    // Update job with fal_job_id (job already created by atomic procedure)
    logger.step('6. Updating job with fal_job_id');
    await updateJobWithFalId(supabase, job_id, falJobId, logger);

    logger.step('6.1. Job updated with fal_job_id', { jobId: job_id, falJobId });

    // Return success response
    const response: SubmitJobResponse = {
      success: true,
      job_id: falJobId,
      status: 'pending',
      estimated_time: 15,
      quota_info: {
        credits_remaining: credits_remaining || 0,
        is_premium: false
      }
    };

    logger.summary('success', {
      jobId: falJobId,
      creditsRemaining: credits_remaining
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

/**
 * Calculate credit cost based on model type and resolution
 */
function calculateCreditCost(modelType: string, resolution?: string): number {
  if (modelType === 'nano-banana') {
    return 1; // Basic model: flat 1 credit
  }

  if (modelType === 'nano-banana-pro') {
    switch (resolution) {
      case '1K':
        return 2;
      case '2K':
        return 3; // Default pro tier
      case '4K':
        return 4;
      default:
        return 2; // Fallback to 1K pricing
    }
  }

  return 1; // Default fallback for unknown models
}

async function parseAndValidateRequest(
  req: Request,
  corsHeaders: Record<string, string>,
  logger?: any
): Promise<{
  error?: Response;
  data?: {
    image_url: string;
    image_urls: string[];
    prompt: string;
    device_id?: string;
    requestId: string;
    user_id?: string;
    model_type: string;
    aspect_ratio: string;
    output_format: string;
    resolution?: string;
  }
}> {
    const requestData: SubmitJobRequest = await req.json();
    let {
      image_url,
      image_urls,
      prompt,
      device_id,
      user_id,
      client_request_id,
      model_type = 'nano-banana',
      aspect_ratio = '1:1',
      output_format = 'jpeg',
      resolution
    } = requestData;

    // Normalize image URLs (support both single and array)
    const normalizedImageUrls = image_urls || (image_url ? [image_url] : []);

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
    if (normalizedImageUrls.length === 0 || !prompt) {
      if (logger) logger.warn('Missing required fields', {
        hasImageUrls: normalizedImageUrls.length > 0,
        hasPrompt: !!prompt
      });
      return {
        error: new Response(
          JSON.stringify({ success: false, error: 'Missing image_url(s) or prompt' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      };
    }

    if (logger) logger.debug('Request validated', {
      numImages: normalizedImageUrls.length,
      firstImageUrl: normalizedImageUrls[0].substring(0, 50) + '...',
      promptPreview: prompt.substring(0, 50) + '...',
      modelType: model_type,
      aspectRatio: aspect_ratio,
      outputFormat: output_format,
      resolution: resolution,
      hasDeviceId: !!device_id,
      hasUserId: !!user_id
    });

  return {
    data: {
      image_url: normalizedImageUrls[0], // Keep for backward compatibility
      image_urls: normalizedImageUrls,
      prompt,
      device_id,
      requestId,
      user_id,
      model_type,
      aspect_ratio,
      output_format,
      resolution
    }
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

// ============================================
// DEPRECATED: consumeCredits (no longer used)
// Credit deduction now handled by submit_job_atomic()
// ============================================
// This function is kept for reference but is no longer called.
// Credit deduction is now handled atomically with job creation
// in the submit_job_atomic() stored procedure.
//
// async function consumeCredits(...) { ... }

async function submitToFalAI(
  supabase: any,
  supabaseUrl: string,
  image_urls: string[],       // Changed to array
  prompt: string,
  model_type: string,         // NEW
  aspect_ratio: string,       // NEW
  output_format: string,      // NEW
  resolution: string | undefined, // NEW
  userType: 'authenticated' | 'anonymous',
  userIdentifier: string,
  requestId: string,
  corsHeaders: Record<string, string>,
  logger?: any
): Promise<{ error?: Response; data?: { falJobId: string } }> {
    if (logger) logger.debug('Submitting to fal.ai async queue', {
      modelType: model_type,
      numImages: image_urls.length,
      aspectRatio: aspect_ratio,
      outputFormat: output_format,
      resolution: resolution
    });

    const falAIKey = Deno.env.get('FAL_AI_API_KEY');
    if (!falAIKey) {
      if (logger) logger.error('FAL_AI_API_KEY not configured');
      // Refund handled by markJobFailedAndRefund in main flow
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
    //
    // CRITICAL: Include client_request_id as query parameter for race condition protection
    // The webhook receives fal.ai's request_id (which becomes fal_job_id), but if the
    // webhook arrives before we update the job record with fal_job_id, the lookup would fail.
    // By passing client_request_id, the webhook can find the job using either:
    // - fal_job_id (normal case)
    // - client_request_id (race condition fallback)
    const webhookUrl = `${supabaseUrl}/functions/v1/webhook-handler?client_request_id=${encodeURIComponent(requestId)}`;

    // Build fal.ai request with new parameters
    const falAIRequest: any = {
      prompt: prompt,
      image_urls: image_urls,     // Array of Storage URLs
      num_images: 1,
      aspect_ratio: aspect_ratio,
      output_format: output_format,
    };

    // Add resolution only for pro model
    if (model_type === 'nano-banana-pro' && resolution) {
      falAIRequest.resolution = resolution; // '1K', '2K', or '4K'
    }

    // Select correct endpoint
    const endpoint = model_type === 'nano-banana-pro'
      ? 'fal-ai/nano-banana-pro/edit'
      : 'fal-ai/nano-banana/edit';

    // Build URL with fal_webhook query parameter (required by fal.ai)
    const falApiUrl = `https://queue.fal.run/${endpoint}?fal_webhook=${encodeURIComponent(webhookUrl)}`;

    if (logger) logger.debug('Fal.ai request prepared', {
      endpoint: endpoint,
      hasWebhook: !!webhookUrl,
      webhookUrl: webhookUrl,
      falApiUrl: falApiUrl,
      requestParams: {
        numImages: image_urls.length,
        aspectRatio: aspect_ratio,
        outputFormat: output_format,
        resolution: resolution || 'auto'
      }
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

      // Refund handled by markJobFailedAndRefund in main flow

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

    // Refund handled by markJobFailedAndRefund in main flow

    return {
      error: new Response(
        JSON.stringify({ success: false, error: 'Failed to submit job to fal.ai queue' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    };
    }
}

// ============================================
// DEPRECATED: insertJobResult (no longer used)
// Job creation now handled by submit_job_atomic()
// ============================================
// This function is kept for reference but is no longer called.
// Job records are now created atomically with credit deduction
// in the submit_job_atomic() stored procedure.
//
// async function insertJobResult(...) { ... }

// ============================================
// HELPER: REFUND CREDIT ON FAILURE
// ============================================

async function refundCredit(
  supabase: any,
  userType: 'authenticated' | 'anonymous',
  userIdentifier: string,
  amount: number,              // NEW: dynamic refund amount
  requestId: string,
  logger?: any
): Promise<{success: boolean, error?: string}> {
  if (logger) logger.debug('Attempting credit refund', {
    userType,
    amount,
    requestId
  });

  try {
    const { data, error } = await supabase.rpc('add_credits', {
      p_user_id: userType === 'authenticated' ? userIdentifier : null,
      p_device_id: userType === 'anonymous' ? userIdentifier : null,
      p_amount: amount,          // CHANGED: use dynamic amount
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

// ============================================
// HELPER: UPDATE JOB WITH FAL_JOB_ID
// ============================================

async function updateJobWithFalId(
  supabase: any,
  jobId: string,
  falJobId: string,
  logger?: any
): Promise<{ error?: Response }> {
  if (logger) logger.debug('Updating job with fal_job_id', { jobId, falJobId });

  const { error } = await supabase
    .from('job_results')
    .update({ fal_job_id: falJobId })
    .eq('id', jobId);

  if (error) {
    if (logger) logger.error('Failed to update job with fal_job_id', { error: error.message });
    // This is non-critical - job exists, webhook can still find it by client_request_id
  } else {
    if (logger) logger.debug('Job updated with fal_job_id successfully');
  }

  return {};
}

// ============================================
// HELPER: MARK JOB AS FAILED AND REFUND CREDIT
// ============================================

async function markJobFailedAndRefund(
  supabase: any,
  jobId: string,
  userType: 'authenticated' | 'anonymous',
  userIdentifier: string,
  creditCost: number,        // NEW: amount to refund
  requestId: string,
  logger?: any
): Promise<void> {
  if (logger) logger.debug('Marking job as failed and refunding credits', {
    jobId,
    creditCost
  });

  // Mark job as failed
  const { error: updateError } = await supabase
    .from('job_results')
    .update({ status: 'failed', error: 'fal.ai submission failed' })
    .eq('id', jobId);

  if (updateError) {
    if (logger) logger.error('Failed to mark job as failed', { error: updateError.message });
  } else {
    if (logger) logger.debug('Job marked as failed');
  }

  // Refund credits (using the same amount that was deducted)
  const refundResult = await refundCredit(supabase, userType, userIdentifier, creditCost, requestId, logger);
  if (!refundResult.success) {
    if (logger) logger.error('Credit refund failed after fal.ai failure', { error: refundResult.error });
    // Critical: Log for manual intervention
  } else {
    if (logger) logger.info('Credits refunded successfully after fal.ai failure', {
      creditsRefunded: creditCost
    });
  }
}
