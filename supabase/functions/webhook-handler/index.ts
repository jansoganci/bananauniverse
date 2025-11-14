import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { createLogger } from '../_shared/logger.ts';

// ============================================
// WEBHOOK-HANDLER: FAL.AI CALLBACK RECEIVER
// ============================================
// This function receives POST callbacks from fal.ai when jobs complete.
// It downloads the processed image, uploads to Supabase Storage,
// and updates the job_results table for iOS to fetch.

// Configuration constants
const MAX_IMAGE_SIZE = 50 * 1024 * 1024;  // 50 MB
const ALLOWED_CONTENT_TYPES = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];

interface FalWebhookPayload {
  request_id: string;      // The fal job ID we submitted
  status: string;          // 'OK' | 'ERROR' (fal.ai webhook format)
  payload?: {             // 'output' değil, 'payload' (fal.ai format)
    images?: Array<{
      url: string;
      content_type: string;
    }>;
  };
  error?: string;
}

Deno.serve(async (req: Request) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  };

  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const requestId = `webhook-${Date.now()}`;
  let logger = createLogger('webhook-handler', requestId);

  try {
    // Log immediately - before any checks
    logger.info('Webhook received', {
      method: req.method,
      url: req.url,
      userAgent: req.headers.get('user-agent') || 'unknown',
      origin: req.headers.get('origin') || 'unknown',
      hasAuth: !!req.headers.get('authorization'),
      contentType: req.headers.get('content-type') || 'unknown'
    });

    // Initialize Supabase early
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { autoRefreshToken: false, persistSession: false }
    });

    // Check rate limit
    logger.step('1. Checking rate limit');
    const rateLimitResult = await checkRateLimit(req, supabase, corsHeaders, logger);
    if (rateLimitResult.error) {
      logger.error('Rate limit check failed');
      return rateLimitResult.error;
    }
    logger.step('1.1. Rate limit check passed');

    // Verify webhook token (with Fal.ai bypass)
    logger.step('2. Verifying webhook token');
    const tokenResult = await verifyWebhookToken(req, corsHeaders, logger);
    if (tokenResult.error) {
      logger.error('Webhook token verification failed', {
        errorResponse: tokenResult.error.status,
        url: req.url
      });
      // Don't return immediately - log first, then return
      return tokenResult.error;
    }
    logger.step('2.1. Webhook token verified');

    // Parse webhook payload
    logger.step('3. Parsing webhook payload');
    const parseResult = await parseWebhookPayload(req, corsHeaders, logger);
    if (parseResult.error) {
      logger.error('Webhook payload parsing failed');
      return parseResult.error;
    }
    const { request_id, status, payload, error } = parseResult.payload!;
    
    // Update logger with job context (preserve duration tracking)
    logger.setContext({ falJobId: request_id });
    logger.step('3.1. Webhook payload parsed', { status, hasError: !!error, hasPayload: !!payload });

    // Validate job exists
    logger.step('4. Validating job exists');
    const validateResult = await validateJobExists(supabase, request_id, corsHeaders, logger);
    if (validateResult.error) {
      logger.error('Job validation failed');
      return validateResult.error;
    }
    const existingJob = validateResult.job!;
    logger.step('4.1. Job validated', {
      userId: existingJob.user_id || null,
      deviceId: existingJob.device_id || null
    });

    // Handle failed/error status
    if (status !== 'OK' || error) {
      logger.step('5. Handling failed job');
      const failedResult = await handleFailedJob(supabase, request_id, error || 'Processing failed', existingJob, corsHeaders, logger);
      logger.summary('success', { status: 'failed', errorMessage: error || 'Processing failed' });
      return failedResult;
    }

    // Handle completed status (status === 'OK')
    if (status === 'OK') {
      logger.step('5. Handling completed job');
      logger.info('Job completed successfully');

      const processedImageURL = payload?.images?.[0]?.url;
      if (!processedImageURL) {
        logger.error('No image URL in response');
        const updateResult = await updateJobStatus(supabase, request_id, 'failed', 'No image URL in response', null, logger);
        if (!updateResult.success) {
          logger.warn('Failed to update job status (non-critical)', { error: updateResult.error });
        }
        return new Response(
          JSON.stringify({ success: false, error: 'No image URL' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      logger.step('6. Processing image', { imageUrl: processedImageURL.substring(0, 50) + '...' });

      // Download and validate image
      logger.step('6.1. Downloading and validating image');
      const downloadResult = await downloadAndValidateImage(supabase, processedImageURL, request_id, corsHeaders, logger);
      if (downloadResult.error) {
        logger.error('Image download failed');
        return downloadResult.error;
      }
      const imageData = downloadResult.imageData!;
      logger.step('6.1.1. Image downloaded and validated');

      // Upload to storage
      logger.step('6.2. Uploading to storage');
      const uploadResult = await uploadToStorage(supabase, imageData, request_id, corsHeaders, logger);
      if (uploadResult.error) {
        logger.error('Storage upload failed');
        return uploadResult.error;
      }
      const fileName = uploadResult.fileName!;
      logger.step('6.2.1. Image uploaded to storage', { fileName });

      // Generate signed URL
      logger.step('6.3. Generating signed URL');
      const signedUrlResult = await generateSignedUrl(supabase, fileName, request_id, corsHeaders, logger);
      if (signedUrlResult.error) {
        logger.error('Signed URL generation failed');
        return signedUrlResult.error;
      }
      const signedURL = signedUrlResult.signedUrl!;
      logger.step('6.3.1. Signed URL generated');

      // Update job result
      logger.step('6.4. Updating job result');
      const updateResult = await updateJobResult(supabase, request_id, signedURL, corsHeaders, logger);
      if (updateResult.error) {
        logger.error('Job result update failed');
        return updateResult.error;
      }
      logger.step('6.4.1. Job result updated');

      logger.summary('success', {
        status: 'completed',
        falJobId: request_id,
        fileName
      });

      return new Response(
        JSON.stringify({
          success: true,
          message: 'Job result saved successfully',
          job_id: request_id
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Handle unknown status
    logger.warn('Unknown status', { status });
    logger.summary('error', { error: 'Unknown status', status });
    return new Response(
      JSON.stringify({ success: false, error: 'Unknown status' }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error: any) {
    logger.error('Unexpected error', error);
    logger.summary('error', { error: error.message });
    return new Response(
      JSON.stringify({ success: false, error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

// ============================================
// HELPER FUNCTIONS
// ============================================

async function checkRateLimit(
  req: Request,
  supabase: any,
  corsHeaders: Record<string, string>,
  logger?: any
): Promise<{ error?: Response }> {
  const clientIP = req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ||
                   req.headers.get('x-real-ip') ||
                   'unknown';

  if (logger) logger.debug('Checking rate limit', { clientIP });

    const { data: allowed, error: rateLimitError } = await supabase.rpc('check_webhook_rate_limit', {
      p_ip_address: clientIP,
    p_max_requests: 100,
      p_window_seconds: 60
    });

    if (rateLimitError) {
      if (logger) logger.warn('Rate limit check failed (failing open)', { error: rateLimitError.message });
      // Fail open - allow request if rate limit check fails
    } else if (allowed === false) {
      if (logger) logger.warn('Rate limit exceeded', { clientIP });
    return {
      error: new Response(
        JSON.stringify({ success: false, error: 'Too many requests' }),
        { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    };
    }

  return {};
}

async function verifyWebhookToken(
  req: Request,
  corsHeaders: Record<string, string>,
  logger?: any
): Promise<{ error?: Response }> {
    // Log incoming request details for debugging
    if (logger) {
      logger.info('Webhook request received', {
        url: req.url,
        method: req.method,
        userAgent: req.headers.get('user-agent') || 'unknown',
        origin: req.headers.get('origin') || 'unknown',
        referer: req.headers.get('referer') || 'unknown',
        falRequestId: req.headers.get('x-fal-webhook-request-id') || null,
        falSignature: req.headers.get('x-fal-webhook-signature') ? 'present' : 'missing',
        allHeaders: Object.fromEntries(req.headers.entries())
      });
    }

    // Fal.ai webhook behavior (based on official documentation):
    // - Fal.ai does NOT preserve query parameters when calling webhook
    // - Fal.ai does NOT send Authorization headers
    // - Fal.ai sends custom headers: X-Fal-Webhook-Request-Id, X-Fal-Webhook-Signature, etc.
    // 
    // Security measures in place:
    // 1. JWT verification disabled for this function (via .supabase.config.json or --no-verify-jwt)
    // 2. Job validation: request_id must exist in database (validates in validateJobExists)
    // 3. Rate limiting: 100 requests/minute per IP (validates in checkRateLimit)
    // 4. Idempotency: Prevents duplicate processing of same job
    //
    // Future enhancement: Implement Fal.ai signature verification using X-Fal-Webhook-Signature
    // See: https://docs.fal.ai/model-apis/model-endpoints/webhooks

    // Always allow - security is handled by job validation and rate limiting
    if (logger) {
      logger.debug('Webhook token check passed (security via job validation and rate limiting)');
    }
    return {};
}

async function parseWebhookPayload(
  req: Request,
  corsHeaders: Record<string, string>,
  logger?: any
): Promise<{ payload?: FalWebhookPayload; error?: Response }> {
    const payload: FalWebhookPayload = await req.json();
    if (logger) logger.debug('Webhook payload received', { 
      requestId: payload.request_id,
      status: payload.status,
      hasError: !!payload.error,
      hasPayload: !!payload.payload,
      rawPayload: JSON.stringify(payload).substring(0, 500) // Log first 500 chars for debugging
    });

  const { request_id } = payload;

    if (!request_id) {
      if (logger) logger.error('Missing request_id in payload');
    return {
      error: new Response(
        JSON.stringify({ success: false, error: 'Missing request_id' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    };
    }

  if (logger) logger.debug('Payload parsed', { requestId: request_id, status: payload.status });

  return { payload };
}

async function validateJobExists(
  supabase: any,
  request_id: string,
  corsHeaders: Record<string, string>,
  logger?: any
): Promise<{ job?: any; error?: Response }> {
    if (logger) logger.debug('Validating job exists in database');

    const { data: existingJob, error: queryError } = await supabase
      .from('job_results')
      .select('fal_job_id, status, user_id, device_id')
      .eq('fal_job_id', request_id)
      .single();

    if (queryError && queryError.code === 'PGRST116') {
      if (logger) logger.error('Job not found', { requestId: request_id });
    return {
      error: new Response(
        JSON.stringify({ success: false, error: 'Job not found' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    };
    }

    if (queryError) {
      if (logger) logger.error('Database error', { error: queryError.message });
    return {
      error: new Response(
        JSON.stringify({ success: false, error: 'Database error' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    };
    }

    if (existingJob.status !== 'pending') {
      if (logger) logger.warn('Job already processed (idempotent)', { 
        requestId: request_id,
        currentStatus: existingJob.status
      });
    return {
      error: new Response(
        JSON.stringify({
          success: true,
          message: 'Job already processed (idempotent)',
          status: existingJob.status
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    };
    }

    if (logger) logger.debug('Valid pending job found', {
      requestId: request_id,
      userId: existingJob.user_id || null,
      deviceId: existingJob.device_id || null
    });

  return { job: existingJob };
}

async function handleFailedJob(
  supabase: any,
  request_id: string,
  errorMessage: string,
  existingJob: any,
  corsHeaders: Record<string, string>,
  logger?: any
): Promise<Response> {
  if (logger) logger.error('Job failed', { errorMessage });

      const { error: updateError } = await supabase
        .from('job_results')
        .update({
          status: 'failed',
      error: errorMessage,
          completed_at: new Date().toISOString()
        })
        .eq('fal_job_id', request_id);

      if (updateError) {
        if (logger) logger.error('Failed to update job_results', { error: updateError.message });
      } else {
        if (logger) logger.debug('Job marked as failed in database');
      }

  // Refund credit for failed job
  if (logger) logger.debug('Refunding credit for failed job');
  
  try {
    const { data: refundData, error: refundError } = await supabase.rpc('add_credits', {
      p_user_id: existingJob.user_id || null,
      p_device_id: existingJob.device_id || null,
      p_amount: 1,
      p_idempotency_key: `refund-${request_id}`
    });

    if (refundError) {
      if (logger) logger.error('Credit refund failed', { error: refundError.message });
    } else {
      if (logger) logger.info('Credit refunded successfully', {
        creditsAdded: refundData?.credits_added,
        creditsRemaining: refundData?.credits_remaining
      });
    }
  } catch (refundException: any) {
    if (logger) logger.error('Credit refund exception', refundException);
  }

      return new Response(
        JSON.stringify({ success: true, message: 'Job failure recorded' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

async function downloadAndValidateImage(
  supabase: any,
  processedImageURL: string,
  request_id: string,
  corsHeaders: Record<string, string>,
  logger?: any
): Promise<{ imageData?: ArrayBuffer; error?: Response }> {
      if (logger) logger.debug('Validating and downloading processed image');

      try {
        // Step 1: HEAD request to check size and type before downloading
        const headResponse = await fetch(processedImageURL, { method: 'HEAD' });

        if (!headResponse.ok) {
          throw new Error(`HEAD request failed: ${headResponse.status}`);
        }

        const contentLength = parseInt(headResponse.headers.get('content-length') || '0');
        const contentType = headResponse.headers.get('content-type') || '';

        if (logger) logger.debug('Image metadata retrieved', {
          contentLength,
          contentType,
          sizeMB: (contentLength / 1024 / 1024).toFixed(2)
        });

        // Step 2: Validate size
        if (contentLength === 0) {
          throw new Error('Image size is unknown or zero');
        }

        if (contentLength > MAX_IMAGE_SIZE) {
          throw new Error(`Image too large: ${(contentLength / 1024 / 1024).toFixed(2)} MB (max ${MAX_IMAGE_SIZE / 1024 / 1024} MB)`);
        }

        // Step 3: Validate content type
        if (!ALLOWED_CONTENT_TYPES.includes(contentType.toLowerCase())) {
          throw new Error(`Invalid content type: ${contentType} (allowed: ${ALLOWED_CONTENT_TYPES.join(', ')})`);
        }

        // Step 4: Download image (now validated)
        const imageResponse = await fetch(processedImageURL);

        if (!imageResponse.ok) {
          throw new Error(`Failed to download image: ${imageResponse.status}`);
        }

    const imageData = await imageResponse.arrayBuffer();

        // Step 5: Verify actual size matches header
        if (imageData.byteLength !== contentLength) {
          throw new Error(`Size mismatch: expected ${contentLength}, got ${imageData.byteLength}`);
        }

        // Step 6: Verify image magic bytes
        const header = new Uint8Array(imageData.slice(0, 4));
        const isJPEG = header[0] === 0xFF && header[1] === 0xD8;
        const isPNG = header[0] === 0x89 && header[1] === 0x50 && header[2] === 0x4E && header[3] === 0x47;
        const isWebP = header[0] === 0x52 && header[1] === 0x49 && header[2] === 0x46 && header[3] === 0x46;

        if (!isJPEG && !isPNG && !isWebP) {
          throw new Error('File is not a valid image (magic bytes verification failed)');
        }

        if (logger) logger.info('Downloaded and validated image', {
          sizeKB: (imageData.byteLength / 1024).toFixed(2),
          contentType
        });

    return { imageData };
      } catch (error: any) {
        if (logger) logger.error('Image download failed', error);

    const updateResult = await updateJobStatus(supabase, request_id, 'failed', `Image download failed: ${error.message}`, null, logger);
    if (!updateResult.success) {
      if (logger) logger.warn('Failed to update job status (non-critical)', { error: updateResult.error });
        }

    return {
      error: new Response(
          JSON.stringify({ success: false, error: 'Image download failed' }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    };
  }
}

async function uploadToStorage(
  supabase: any,
  imageData: ArrayBuffer,
  request_id: string,
  corsHeaders: Record<string, string>,
  logger?: any
): Promise<{ fileName?: string; error?: Response }> {
      const bucketName = 'noname-banana-images-prod';
      const fileName = `processed/${request_id}.jpg`;

      if (logger) logger.debug('Uploading to Supabase Storage', { fileName, sizeKB: (imageData.byteLength / 1024).toFixed(2) });

      try {
        const { data: uploadData, error: uploadError } = await supabase.storage
          .from(bucketName)
          .upload(fileName, imageData, {
            contentType: 'image/jpeg',
            upsert: true
          });

        if (uploadError) {
          throw uploadError;
        }

        if (logger) logger.info('Uploaded to storage', { fileName });
    return { fileName };
      } catch (error: any) {
        if (logger) logger.error('Storage upload failed', { error: error.message, fileName });

    const updateResult = await updateJobStatus(supabase, request_id, 'failed', `Storage upload failed: ${error.message}`, null, logger);
    if (!updateResult.success) {
      if (logger) logger.warn('Failed to update job status (non-critical)', { error: updateResult.error });
        }

    return {
      error: new Response(
          JSON.stringify({ success: false, error: 'Storage upload failed' }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    };
      }
}

async function generateSignedUrl(
  supabase: any,
  fileName: string,
  request_id: string,
  corsHeaders: Record<string, string>,
  logger?: any
): Promise<{ signedUrl?: string; error?: Response }> {
  const bucketName = 'noname-banana-images-prod';

      if (logger) logger.debug('Generating signed URL', { fileName, expiryDays: 7 });

      try {
        const { data: signedData, error: signedError } = await supabase.storage
          .from(bucketName)
          .createSignedUrl(fileName, 604800); // 7 days in seconds

        if (signedError) {
          throw signedError;
        }

    const signedURL = signedData.signedUrl;
        if (logger) logger.info('Signed URL generated', { fileName, expiryDays: 7 });

    return { signedUrl: signedURL };
      } catch (error: any) {
        if (logger) logger.error('Signed URL generation failed', { error: error.message, fileName });

    const updateResult = await updateJobStatus(supabase, request_id, 'failed', `Signed URL generation failed: ${error.message}`, null, logger);
    if (!updateResult.success) {
      if (logger) logger.warn('Failed to update job status (non-critical)', { error: updateResult.error });
        }

    return {
      error: new Response(
          JSON.stringify({ success: false, error: 'Signed URL generation failed' }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    };
  }
}

async function updateJobResult(
  supabase: any,
  request_id: string,
  signedURL: string,
  corsHeaders: Record<string, string>,
  logger?: any
): Promise<{ success?: boolean; error?: Response }> {
      if (logger) logger.debug('Updating job_results table');

      const { error: updateError } = await supabase
        .from('job_results')
        .update({
          status: 'completed',
          image_url: signedURL,
          completed_at: new Date().toISOString()
        })
        .eq('fal_job_id', request_id);

      if (updateError) {
        if (logger) logger.error('Failed to update job_results', { error: updateError.message });
    return {
      error: new Response(
          JSON.stringify({ success: false, error: 'Database update failed' }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    };
      }

      if (logger) logger.info('Job result saved successfully', { requestId: request_id });
  return { success: true };
}

async function updateJobStatus(
  supabase: any,
  request_id: string,
  status: string,
  errorMessage: string | null,
  image_url: string | null,
  logger?: any
): Promise<{success: boolean, error?: string}> {
  const updateData: any = {
    status,
    completed_at: new Date().toISOString()
  };

  if (errorMessage) {
    updateData.error = errorMessage;
  }

  if (image_url) {
    updateData.image_url = image_url;
  }

  try {
    const { error: updateError } = await supabase
      .from('job_results')
      .update(updateData)
      .eq('fal_job_id', request_id);

    if (updateError) {
      if (logger) logger.error('Failed to update job_results', { error: updateError.message, status });
      return {
        success: false,
        error: updateError.message || 'Database update failed'
      };
    }

    if (logger) logger.debug('Job status updated', { requestId: request_id, status });
    return { success: true };
  } catch (error: any) {
    if (logger) logger.error('Exception updating job_results', error);
    return {
      success: false,
      error: error.message || 'Unexpected error updating job status'
    };
  }
}
