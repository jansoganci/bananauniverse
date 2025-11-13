import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

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
  is_premium?: boolean;
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
    is_premium: boolean;
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
    console.log('🚀 [SUBMIT-JOB] Request started');

    // Parse and validate request
    const parseResult = await parseAndValidateRequest(req, corsHeaders);
    if (parseResult.error) {
      return parseResult.error;
    }
    const { image_url, prompt, device_id, requestId, user_id, is_premium } = parseResult.data!;

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { autoRefreshToken: false, persistSession: false }
    });

    // Authenticate user
    const authResult = await authenticateUser(req, supabase, user_id, device_id, is_premium, corsHeaders);
    if (authResult.error) {
      return authResult.error;
    }
    const { userIdentifier, userType, isPremium } = authResult.data!;

    // Set device ID session for RLS
    await setDeviceIdSession(supabase, device_id);

    // Consume credits
    const creditResult = await consumeCredits(supabase, userType, userIdentifier, requestId, isPremium, corsHeaders);
    if (creditResult.error) {
      return creditResult.error;
    }
    const { quotaResult, updatedIsPremium } = creditResult.data!;
    const finalIsPremium = updatedIsPremium;

    // Submit to fal.ai
    const falResult = await submitToFalAI(supabase, supabaseUrl, image_url, prompt, userType, userIdentifier, requestId, corsHeaders);
    if (falResult.error) {
      return falResult.error;
    }
    const { falJobId } = falResult.data!;

    // Insert job result
    const insertResult = await insertJobResult(supabase, falJobId, userType, userIdentifier, requestId, corsHeaders);
    if (insertResult.error) {
      return insertResult.error;
    }

    // Return success response
    const response: SubmitJobResponse = {
      success: true,
      job_id: falJobId,
      status: 'pending',
      estimated_time: 15,
      quota_info: {
        credits_remaining: quotaResult.credits_remaining || 0,
        is_premium: finalIsPremium
      }
    };

    console.log('✅ [SUBMIT-JOB] Success:', JSON.stringify(response, null, 2));

    return new Response(
      JSON.stringify(response),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error: any) {
    console.error('❌ [SUBMIT-JOB] Unexpected error:', error.message);
    return new Response(
      JSON.stringify({ success: false, error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

// ============================================
// HELPER FUNCTIONS
// ============================================

async function parseAndValidateRequest(
  req: Request,
  corsHeaders: Record<string, string>
): Promise<{ error?: Response; data?: { image_url: string; prompt: string; device_id?: string; requestId: string; user_id?: string; is_premium?: boolean } }> {
  const requestData: SubmitJobRequest = await req.json();
  let { image_url, prompt, device_id, user_id, is_premium, client_request_id } = requestData;

  // Generate request ID for idempotency
  const requestId = client_request_id || crypto.randomUUID();
  console.log('🔑 [SUBMIT-JOB] Request ID:', requestId);

  // Try to get device_id from header if not in body
  if (!device_id) {
    const deviceIdHeader = req.headers.get('device-id');
    if (deviceIdHeader) {
      device_id = deviceIdHeader;
      console.log('🔧 [SUBMIT-JOB] Device ID from header:', device_id);
    }
  }

  // Validate required fields
  if (!image_url || !prompt) {
    return {
      error: new Response(
        JSON.stringify({ success: false, error: 'Missing image_url or prompt' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    };
  }

  console.log('🔍 [SUBMIT-JOB] Request:', { image_url, prompt: prompt.substring(0, 50) + '...' });

  return {
    data: { image_url, prompt, device_id, requestId, user_id, is_premium }
  };
}

async function authenticateUser(
  req: Request,
  supabase: any,
  user_id_from_body: string | undefined,
  device_id: string | undefined,
  is_premium_from_body: boolean | undefined,
  corsHeaders: Record<string, string>
): Promise<{ error?: Response; data?: { userIdentifier: string; userType: 'authenticated' | 'anonymous'; isPremium: boolean } }> {
  let userIdentifier: string;
  let userType: 'authenticated' | 'anonymous';
  let isPremium: boolean;

  const authHeader = req.headers.get('authorization');
  if (authHeader && authHeader.startsWith('Bearer ')) {
    try {
      const token = authHeader.split(' ')[1];
      console.log('🔑 [SUBMIT-JOB] Validating JWT token...');

      const { data: { user }, error } = await supabase.auth.getUser(token);

      if (error || !user) {
        throw new Error(`JWT validation failed: ${error?.message || 'No user'}`);
      }

      userIdentifier = user_id_from_body || user.id;
      userType = 'authenticated';
      isPremium = is_premium_from_body || false;

      console.log('✅ [SUBMIT-JOB] Authenticated user:', user.id, 'Premium:', isPremium);
    } catch (error: any) {
      console.log('⚠️ [SUBMIT-JOB] JWT auth failed, checking device_id fallback...');

      if (!device_id) {
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
      isPremium = is_premium_from_body || false;

      console.log('🔓 [SUBMIT-JOB] Anonymous user:', device_id, 'Premium:', isPremium);
    }
  } else {
    console.log('🔓 [SUBMIT-JOB] No auth header, checking device_id...');

    if (!device_id) {
      return {
        error: new Response(
          JSON.stringify({ success: false, error: 'Authentication or device_id required' }),
          { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      };
    }

    userIdentifier = device_id;
    userType = 'anonymous';
    isPremium = is_premium_from_body || false;

    console.log('🔓 [SUBMIT-JOB] Anonymous user:', device_id, 'Premium:', isPremium);
  }

  return {
    data: { userIdentifier, userType, isPremium }
  };
}

async function setDeviceIdSession(supabase: any, device_id?: string): Promise<void> {
  if (device_id) {
    console.log('🔧 [RLS] Setting device_id session variable:', device_id);
    const { error: sessionError } = await supabase.rpc('set_device_id_session', {
      p_device_id: device_id
    });

    if (sessionError) {
      console.error('[SUBMIT-JOB] Failed to set device_id session:', sessionError);
    } else {
      console.log('✅ [RLS] Device ID session variable set');
    }
  }
}

async function consumeCredits(
  supabase: any,
  userType: 'authenticated' | 'anonymous',
  userIdentifier: string,
  requestId: string,
  isPremium: boolean,
  corsHeaders: Record<string, string>
): Promise<{ error?: Response; data?: { quotaResult: any; updatedIsPremium: boolean } }> {
  console.log('🆕 [CREDITS] Consuming credits with persistent balance system...');

  try {
    const { data, error } = await supabase.rpc('consume_credits', {
      p_user_id: userType === 'authenticated' ? userIdentifier : null,
      p_device_id: userType === 'anonymous' ? userIdentifier : null,
      p_amount: 1,
      p_idempotency_key: requestId
    });

    if (error) {
      console.error('❌ [CREDITS] consume_credits failed:', error);
      return {
        error: new Response(
          JSON.stringify({ success: false, error: 'Credit validation failed' }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      };
    }

    const quotaResult = data;
    console.log('✅ [CREDITS] Result:', JSON.stringify(quotaResult));

    // Extract premium status from server
    let updatedIsPremium = isPremium;
    if (quotaResult?.is_premium !== undefined) {
      updatedIsPremium = quotaResult.is_premium;
      console.log('🔍 [QUOTA] Server premium status:', updatedIsPremium);
      if (updatedIsPremium) {
        console.log('💎 [QUOTA] Premium user — bypassing quota');
      }
    }

    // Check for idempotent request
    if (quotaResult?.idempotent === true) {
      console.log('✅ [IDEMPOTENCY] Duplicate request detected');

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
      console.log(`❌ [CREDITS] Credit check failed: ${quotaResult.error}`);

      return {
        error: new Response(
          JSON.stringify({
            success: false,
            error: quotaResult.error || 'Insufficient credits. Purchase more credits to continue.',
            quota_info: {
              credits_remaining: quotaResult.credits_remaining || 0,
              is_premium: updatedIsPremium
            }
          }),
          { status: 402, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      };
    }

    console.log(`✅ [CREDITS] Credit consumed: ${quotaResult.credits_remaining} remaining`);

    return {
      data: { quotaResult, updatedIsPremium }
    };
  } catch (error: any) {
    console.error('❌ [CREDITS] Exception:', error.message);
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
  corsHeaders: Record<string, string>
): Promise<{ error?: Response; data?: { falJobId: string } }> {
  console.log('🤖 [FAL.AI] Submitting to async queue...');

  const falAIKey = Deno.env.get('FAL_AI_API_KEY');
  if (!falAIKey) {
    const refundResult = await refundCredit(supabase, userType, userIdentifier, requestId);
    if (!refundResult.success) {
      console.warn('⚠️ [SUBMIT-JOB] Credit refund failed (non-critical):', refundResult.error);
    }
    return {
      error: new Response(
        JSON.stringify({ success: false, error: 'FAL_AI_API_KEY not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    };
  }

  const webhookToken = Deno.env.get('FAL_WEBHOOK_TOKEN') || '';
  const webhookUrl = webhookToken
    ? `${supabaseUrl}/functions/v1/webhook-handler?token=${webhookToken}`
    : `${supabaseUrl}/functions/v1/webhook-handler`;

  const falAIRequest = {
    prompt: prompt,
    image_urls: [image_url],
    num_images: 1,
    output_format: 'jpeg',
    webhook_url: webhookUrl
  };

  console.log('📤 [FAL.AI] Request:', JSON.stringify(falAIRequest, null, 2));
  console.log('🔗 [WEBHOOK] URL:', webhookUrl.replace(webhookToken, '***'));

  try {
    const falResponse = await fetch('https://queue.fal.run/fal-ai/nano-banana/edit', {
      method: 'POST',
      headers: {
        'Authorization': `Key ${falAIKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(falAIRequest),
    });

    if (!falResponse.ok) {
      const errorText = await falResponse.text();
      console.error('❌ [FAL.AI] Queue submission failed:', falResponse.status, errorText);

      const refundResult = await refundCredit(supabase, userType, userIdentifier, requestId);
      if (!refundResult.success) {
        console.warn('⚠️ [SUBMIT-JOB] Credit refund failed (non-critical):', refundResult.error);
      }

      return {
        error: new Response(
          JSON.stringify({ success: false, error: `fal.ai queue submission failed: ${falResponse.status}` }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      };
    }

    const falResult = await falResponse.json();
    console.log('✅ [FAL.AI] Queue submission result:', JSON.stringify(falResult, null, 2));

    const falJobId = falResult.request_id;

    if (!falJobId) {
      throw new Error('No request_id returned from fal.ai queue');
    }

    console.log('🎫 [FAL.AI] Job ID:', falJobId);

    return {
      data: { falJobId }
    };
  } catch (error: any) {
    console.error('❌ [FAL.AI] Exception:', error.message);

    const refundResult = await refundCredit(supabase, userType, userIdentifier, requestId);
    if (!refundResult.success) {
      console.warn('⚠️ [SUBMIT-JOB] Credit refund failed (non-critical):', refundResult.error);
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
  corsHeaders: Record<string, string>
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
    console.error('❌ [JOB-RESULTS] FATAL: Insert failed:', insertError);

    const refundResult = await refundCredit(supabase, userType, userIdentifier, requestId);
    if (!refundResult.success) {
      console.warn('⚠️ [SUBMIT-JOB] Credit refund failed (non-critical):', refundResult.error);
    }

    return {
      error: new Response(
        JSON.stringify({ success: false, error: 'Failed to create job record' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    };
  }

  console.log('✅ [JOB-RESULTS] Job result entry created with status: pending');
  return {};
}

// ============================================
// HELPER: REFUND CREDIT ON FAILURE
// ============================================

async function refundCredit(
  supabase: any,
  userType: 'authenticated' | 'anonymous',
  userIdentifier: string,
  requestId: string
): Promise<{success: boolean, error?: string}> {
  console.log('💰 [REFUND] Attempting credit refund...');

  try {
    const { data, error } = await supabase.rpc('add_credits', {
      p_user_id: userType === 'authenticated' ? userIdentifier : null,
      p_device_id: userType === 'anonymous' ? userIdentifier : null,
      p_amount: 1,
      p_idempotency_key: `refund-${requestId}`
    });

    if (error) {
      console.error('❌ [REFUND] Failed:', error);
      return {
        success: false,
        error: error.message || 'Credit refund failed'
      };
    } else {
      console.log('✅ [REFUND] Success:', data);
      return { success: true };
    }
  } catch (error: any) {
    console.error('❌ [REFUND] Exception:', error.message);
    return {
      success: false,
      error: error.message || 'Unexpected error during credit refund'
    };
  }
}
