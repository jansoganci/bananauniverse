import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

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
  status: string;          // 'COMPLETED' | 'FAILED'
  output?: {
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

  try {
    console.log('🔔 [WEBHOOK] Received callback from fal.ai');

    // Initialize Supabase early
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { autoRefreshToken: false, persistSession: false }
    });

    // Check rate limit
    const rateLimitResult = await checkRateLimit(req, supabase, corsHeaders);
    if (rateLimitResult.error) {
      return rateLimitResult.error;
    }

    // Verify webhook token
    const tokenResult = await verifyWebhookToken(req, corsHeaders);
    if (tokenResult.error) {
      return tokenResult.error;
    }

    // Parse webhook payload
    const parseResult = await parseWebhookPayload(req, corsHeaders);
    if (parseResult.error) {
      return parseResult.error;
    }
    const { request_id, status, output, error } = parseResult.payload!;

    // Validate job exists
    const validateResult = await validateJobExists(supabase, request_id, corsHeaders);
    if (validateResult.error) {
      return validateResult.error;
    }
    const existingJob = validateResult.job!;

    // Handle failed status
    if (status === 'FAILED' || error) {
      const failedResult = await handleFailedJob(supabase, request_id, error || 'Processing failed', existingJob, corsHeaders);
      return failedResult;
    }

    // Handle completed status
    if (status === 'COMPLETED') {
      console.log('✅ [WEBHOOK] Job completed successfully');

      const processedImageURL = output?.images?.[0]?.url;
      if (!processedImageURL) {
        const updateResult = await updateJobStatus(supabase, request_id, 'failed', 'No image URL in response', null);
        if (!updateResult.success) {
          console.warn('⚠️ [WEBHOOK] Failed to update job status (non-critical):', updateResult.error);
        }
        return new Response(
          JSON.stringify({ success: false, error: 'No image URL' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      console.log('🖼️  [WEBHOOK] Processed image URL:', processedImageURL);

      // Download and validate image
      const downloadResult = await downloadAndValidateImage(supabase, processedImageURL, request_id, corsHeaders);
      if (downloadResult.error) {
        return downloadResult.error;
      }
      const imageData = downloadResult.imageData!;

      // Upload to storage
      const uploadResult = await uploadToStorage(supabase, imageData, request_id, corsHeaders);
      if (uploadResult.error) {
        return uploadResult.error;
      }
      const fileName = uploadResult.fileName!;

      // Generate signed URL
      const signedUrlResult = await generateSignedUrl(supabase, fileName, request_id, corsHeaders);
      if (signedUrlResult.error) {
        return signedUrlResult.error;
      }
      const signedURL = signedUrlResult.signedUrl!;

      // Update job result
      const updateResult = await updateJobResult(supabase, request_id, signedURL, corsHeaders);
      if (updateResult.error) {
        return updateResult.error;
      }

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
    console.warn('⚠️  [WEBHOOK] Unknown status:', status);
    return new Response(
      JSON.stringify({ success: false, error: 'Unknown status' }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error: any) {
    console.error('❌ [WEBHOOK] Unexpected error:', error.message);
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
  corsHeaders: Record<string, string>
): Promise<{ error?: Response }> {
  const clientIP = req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ||
                   req.headers.get('x-real-ip') ||
                   'unknown';

  console.log('🔍 [WEBHOOK] Client IP:', clientIP);

  const { data: allowed, error: rateLimitError } = await supabase.rpc('check_webhook_rate_limit', {
    p_ip_address: clientIP,
    p_max_requests: 100,
    p_window_seconds: 60
  });

  if (rateLimitError) {
    console.error('⚠️  [WEBHOOK] Rate limit check failed:', rateLimitError);
    // Fail open - allow request if rate limit check fails
  } else if (allowed === false) {
    console.warn('🚫 [WEBHOOK] Rate limit exceeded for IP:', clientIP);
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
  corsHeaders: Record<string, string>
): Promise<{ error?: Response }> {
  const url = new URL(req.url);
  const receivedToken = url.searchParams.get('token');
  const expectedToken = Deno.env.get('FAL_WEBHOOK_TOKEN');

  if (!expectedToken) {
    console.warn('⚠️  [WEBHOOK] FAL_WEBHOOK_TOKEN not configured - skipping verification (DEV ONLY)');
  } else if (!receivedToken) {
    console.error('❌ [WEBHOOK] Missing token in URL');
    return {
      error: new Response(
        JSON.stringify({ success: false, error: 'Unauthorized: Missing token' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    };
  } else if (receivedToken !== expectedToken) {
    console.error('❌ [WEBHOOK] Invalid token');
    return {
      error: new Response(
        JSON.stringify({ success: false, error: 'Unauthorized: Invalid token' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    };
  } else {
    console.log('✅ [WEBHOOK] Token verified');
  }

  return {};
}

async function parseWebhookPayload(
  req: Request,
  corsHeaders: Record<string, string>
): Promise<{ payload?: FalWebhookPayload; error?: Response }> {
  const payload: FalWebhookPayload = await req.json();
  console.log('📦 [WEBHOOK] Payload:', JSON.stringify(payload, null, 2));

  const { request_id } = payload;

  if (!request_id) {
    console.error('❌ [WEBHOOK] Missing request_id in payload');
    return {
      error: new Response(
        JSON.stringify({ success: false, error: 'Missing request_id' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    };
  }

  console.log(`🎫 [WEBHOOK] Job ID: ${request_id}, Status: ${payload.status}`);

  return { payload };
}

async function validateJobExists(
  supabase: any,
  request_id: string,
  corsHeaders: Record<string, string>
): Promise<{ job?: any; error?: Response }> {
  console.log('🔍 [WEBHOOK] Validating job exists in database...');

  const { data: existingJob, error: queryError } = await supabase
    .from('job_results')
    .select('fal_job_id, status, user_id, device_id')
    .eq('fal_job_id', request_id)
    .single();

  if (queryError && queryError.code === 'PGRST116') {
    console.error('❌ [WEBHOOK] Job not found:', request_id);
    return {
      error: new Response(
        JSON.stringify({ success: false, error: 'Job not found' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    };
  }

  if (queryError) {
    console.error('❌ [WEBHOOK] Database error:', queryError);
    return {
      error: new Response(
        JSON.stringify({ success: false, error: 'Database error' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    };
  }

  if (existingJob.status !== 'pending') {
    console.warn('⚠️  [WEBHOOK] Job already processed:', request_id, 'Status:', existingJob.status);
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

  console.log('✅ [WEBHOOK] Valid pending job found:', request_id,
              'User:', existingJob.user_id || 'none',
              'Device:', existingJob.device_id || 'none');

  return { job: existingJob };
}

async function handleFailedJob(
  supabase: any,
  request_id: string,
  errorMessage: string,
  existingJob: any,
  corsHeaders: Record<string, string>
): Promise<Response> {
  console.error('❌ [WEBHOOK] Job failed:', errorMessage);

  const { error: updateError } = await supabase
    .from('job_results')
    .update({
      status: 'failed',
      error: errorMessage,
      completed_at: new Date().toISOString()
    })
    .eq('fal_job_id', request_id);

  if (updateError) {
    console.error('❌ [WEBHOOK] Failed to update job_results:', updateError);
  } else {
    console.log('✅ [WEBHOOK] Job marked as failed in database');
  }

  // Refund credit for failed job
  console.log('💰 [WEBHOOK] Refunding credit for failed job...');
  
  try {
    const { data: refundData, error: refundError } = await supabase.rpc('add_credits', {
      p_user_id: existingJob.user_id || null,
      p_device_id: existingJob.device_id || null,
      p_amount: 1,
      p_idempotency_key: `refund-${request_id}`
    });

    if (refundError) {
      console.error('❌ [WEBHOOK] Credit refund failed:', refundError);
    } else {
      console.log('✅ [WEBHOOK] Credit refunded successfully:', refundData);
    }
  } catch (refundException: any) {
    console.error('❌ [WEBHOOK] Credit refund exception:', refundException.message);
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
  corsHeaders: Record<string, string>
): Promise<{ imageData?: ArrayBuffer; error?: Response }> {
  console.log('⬇️  [WEBHOOK] Validating and downloading processed image...');

  try {
    // Step 1: HEAD request to check size and type before downloading
    const headResponse = await fetch(processedImageURL, { method: 'HEAD' });

    if (!headResponse.ok) {
      throw new Error(`HEAD request failed: ${headResponse.status}`);
    }

    const contentLength = parseInt(headResponse.headers.get('content-length') || '0');
    const contentType = headResponse.headers.get('content-type') || '';

    console.log(`📊 [WEBHOOK] Image metadata: ${contentLength} bytes, type: ${contentType}`);

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

    console.log(`✅ [WEBHOOK] Downloaded and validated image: ${(imageData.byteLength / 1024).toFixed(2)} KB`);

    return { imageData };
  } catch (error: any) {
    console.error('❌ [WEBHOOK] Image download failed:', error.message);

    const updateResult = await updateJobStatus(supabase, request_id, 'failed', `Image download failed: ${error.message}`, null);
    if (!updateResult.success) {
      console.warn('⚠️ [WEBHOOK] Failed to update job status (non-critical):', updateResult.error);
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
  corsHeaders: Record<string, string>
): Promise<{ fileName?: string; error?: Response }> {
  console.log('⬆️  [WEBHOOK] Uploading to Supabase Storage...');

  const bucketName = 'noname-banana-images-prod';
  const fileName = `processed/${request_id}.jpg`;

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

    console.log('✅ [WEBHOOK] Uploaded to storage:', fileName);
    return { fileName };
  } catch (error: any) {
    console.error('❌ [WEBHOOK] Storage upload failed:', error.message);

    const updateResult = await updateJobStatus(supabase, request_id, 'failed', `Storage upload failed: ${error.message}`, null);
    if (!updateResult.success) {
      console.warn('⚠️ [WEBHOOK] Failed to update job status (non-critical):', updateResult.error);
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
  corsHeaders: Record<string, string>
): Promise<{ signedUrl?: string; error?: Response }> {
  console.log('🔗 [WEBHOOK] Generating signed URL...');

  const bucketName = 'noname-banana-images-prod';

  try {
    const { data: signedData, error: signedError } = await supabase.storage
      .from(bucketName)
      .createSignedUrl(fileName, 604800); // 7 days in seconds

    if (signedError) {
      throw signedError;
    }

    const signedURL = signedData.signedUrl;
    console.log('✅ [WEBHOOK] Signed URL generated (7-day expiry)');

    return { signedUrl: signedURL };
  } catch (error: any) {
    console.error('❌ [WEBHOOK] Signed URL generation failed:', error.message);

    const updateResult = await updateJobStatus(supabase, request_id, 'failed', `Signed URL generation failed: ${error.message}`, null);
    if (!updateResult.success) {
      console.warn('⚠️ [WEBHOOK] Failed to update job status (non-critical):', updateResult.error);
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
  corsHeaders: Record<string, string>
): Promise<{ success?: boolean; error?: Response }> {
  console.log('💾 [WEBHOOK] Updating job_results table...');

  const { error: updateError } = await supabase
    .from('job_results')
    .update({
      status: 'completed',
      image_url: signedURL,
      completed_at: new Date().toISOString()
    })
    .eq('fal_job_id', request_id);

  if (updateError) {
    console.error('❌ [WEBHOOK] Failed to update job_results:', updateError);
    return {
      error: new Response(
        JSON.stringify({ success: false, error: 'Database update failed' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    };
  }

  console.log('✅ [WEBHOOK] Job result saved successfully');
  return { success: true };
}

async function updateJobStatus(
  supabase: any,
  request_id: string,
  status: string,
  errorMessage: string | null,
  image_url: string | null
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
      console.error('❌ [WEBHOOK] Failed to update job_results:', updateError);
      return {
        success: false,
        error: updateError.message || 'Database update failed'
      };
    }

    console.log(`✅ [WEBHOOK] Job status updated to: ${status}`);
    return { success: true };
  } catch (error: any) {
    console.error('❌ [WEBHOOK] Exception updating job_results:', error.message);
    return {
      success: false,
      error: error.message || 'Unexpected error updating job status'
    };
  }
}
