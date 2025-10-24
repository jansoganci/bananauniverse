import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// ============================================
// STEVE JOBS STYLE: SIMPLE, FAST, RELIABLE
// ============================================

interface ProcessImageRequest {
  image_url: string;
  prompt: string;
  device_id?: string; // For anonymous users
  user_id?: string; // For authenticated users
  is_premium?: boolean; // Premium user status
  client_request_id?: string; // For idempotency
}

interface ProcessImageResponse {
  success: boolean;
  processed_image_url?: string;
  job_id?: string; // Database job ID for tracking
  error?: string;
  quota_info?: {
    credits: number;
    quota_used: number;
    quota_limit: number;
    quota_remaining: number;
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
    console.log('🍎 [STEVE-JOBS] Process Image Request Started');
    
    // ============================================
    // 1. PARSE REQUEST
    // ============================================
    
    const requestData: ProcessImageRequest = await req.json();
    let { image_url, prompt, device_id, user_id, is_premium, client_request_id } = requestData;
    
    // CRITICAL FIX: Also try to get device_id from header if not in body
    if (!device_id) {
      const deviceIdHeader = req.headers.get('device-id');
      if (deviceIdHeader) {
        device_id = deviceIdHeader;
        console.log('🔧 [STEVE-JOBS] Device ID retrieved from header:', device_id);
      }
    }
    
    if (!image_url || !prompt) {
      return new Response(
        JSON.stringify({ success: false, error: 'Missing image_url or prompt' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }
    
    console.log('🔍 [STEVE-JOBS] Processing request:', { image_url, prompt: prompt.substring(0, 50) + '...' });
    
    // ============================================
    // 2. INITIALIZE SUPABASE CLIENT
    // ============================================
    
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { autoRefreshToken: false, persistSession: false }
    });
    
    // ============================================
    // 3. AUTHENTICATION & USER IDENTIFICATION
    // ============================================
    
    let userIdentifier: string;
    let userType: 'authenticated' | 'anonymous';
    let isPremium: boolean;
    
    // Check for JWT token (authenticated user)
    const authHeader = req.headers.get('authorization');
    if (authHeader && authHeader.startsWith('Bearer ')) {
      try {
        const token = authHeader.split(' ')[1];
        console.log('🔑 [STEVE-JOBS] Attempting to validate JWT token...');
        
        const { data: { user }, error } = await supabase.auth.getUser(token);
        
        if (error) {
          console.error('❌ [STEVE-JOBS] JWT validation error:', error.message);
          throw new Error(`JWT validation failed: ${error.message}`);
        }
        
        if (!user) {
          console.error('❌ [STEVE-JOBS] No user returned from JWT');
          throw new Error('No user found in JWT');
        }
        
        userIdentifier = user_id || user.id;
        userType = 'authenticated';
        isPremium = is_premium || false;
        
        console.log('✅ [STEVE-JOBS] Authenticated user:', user.id, 'Premium:', isPremium);
      } catch (error: any) {
        // If JWT fails, check for device_id (anonymous user fallback)
        console.log('⚠️ [STEVE-JOBS] JWT auth failed, checking for device_id fallback...');
        console.error('⚠️ [STEVE-JOBS] Auth error details:', error.message || error);
        
        if (!device_id) {
          console.error('❌ [STEVE-JOBS] No device_id provided for fallback - returning 401');
          return new Response(
            JSON.stringify({ 
              success: false, 
              error: 'Authentication failed and no device_id provided',
              details: error.message || 'Invalid or expired token'
            }),
            { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }
        
        // Fallback to anonymous user with device_id
        userIdentifier = device_id;
        userType = 'anonymous';
        isPremium = is_premium || false;
        
        console.log('🔓 [STEVE-JOBS] Falling back to anonymous user:', device_id, 'Premium:', isPremium);
      }
    } else {
      // No auth header, check for device_id (anonymous user)
      console.log('🔓 [STEVE-JOBS] No auth header provided, checking for device_id...');
      
      if (!device_id) {
        console.error('❌ [STEVE-JOBS] Neither auth token nor device_id provided - returning 401');
        return new Response(
          JSON.stringify({ success: false, error: 'Authentication or device_id required' }),
          { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
      
      userIdentifier = device_id;
      userType = 'anonymous';
      isPremium = is_premium || false;
      
      console.log('🔓 [STEVE-JOBS] Anonymous user:', device_id, 'Premium:', isPremium);
    }
    
    // ============================================
    // 4. SET DEVICE ID SESSION FOR RLS POLICIES
    // ============================================
    
    // Set session variable for RLS policies
    if (device_id) {
      console.log('🔧 [RLS] Setting device_id session variable:', device_id);
      const { error: sessionError } = await supabase.rpc('set_device_id_session', { 
        p_device_id: device_id 
      });
      
      if (sessionError) {
        console.error('[Edge Function] Failed to set device_id session:', sessionError);
        // Continue anyway - the consume_quota function will also try to set it
      } else {
        console.log('✅ [RLS] Device ID session variable set successfully');
      }
    }
    
    // ============================================
    // 5. NEW QUOTA SYSTEM (WITH FALLBACK)
    // ============================================
    
    console.log('🆕 [QUOTA] Trying new quota system...');
    
    let quotaResult: any;
    let useNewSystem = true;
    
    try {
      const { data, error } = await supabase.rpc('consume_quota', {
        p_user_id: userType === 'authenticated' ? userIdentifier : null,
        p_device_id: userType === 'anonymous' ? userIdentifier : null,
        p_is_premium: isPremium,
        p_client_request_id: client_request_id || crypto.randomUUID()
      });
      
      if (error) {
        console.warn('⚠️ [QUOTA] New quota system failed, falling back to old system:', error.message);
        useNewSystem = false;
      } else {
        quotaResult = data;
        console.log('✅ [QUOTA] New quota system success:', JSON.stringify(quotaResult));
      }
    } catch (error: any) {
      console.warn('⚠️ [QUOTA] New quota system exception, falling back to old system:', error.message);
      useNewSystem = false;
    }
    
    // Fallback to old system if new system failed
    if (!useNewSystem) {
      console.warn('⚠️ [QUOTA] Fallback to old credit system');
      
      let quotaValidation: any;
      
      if (userType === 'authenticated') {
        const { data, error } = await supabase.rpc('validate_user_daily_quota', {
          p_user_id: userIdentifier,
          p_is_premium: isPremium
        });
        
        if (error) {
          console.error('❌ [STEVE-JOBS] Quota validation error:', error);
          return new Response(
            JSON.stringify({ success: false, error: 'Quota validation failed' }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }
        
        quotaValidation = data;
      } else {
        const { data, error } = await supabase.rpc('validate_anonymous_daily_quota', {
          p_device_id: userIdentifier,
          p_is_premium: isPremium
        });
        
        if (error) {
          console.error('❌ [STEVE-JOBS] Quota validation error:', error);
          return new Response(
            JSON.stringify({ success: false, error: 'Quota validation failed' }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }
        
        quotaValidation = data;
      }
      
      if (!quotaValidation.valid) {
        console.log(`❌ [STEVE-JOBS] Quota validation failed: ${quotaValidation.error}`);
        
        return new Response(
          JSON.stringify({
            success: false,
            error: quotaValidation.error,
            quota_info: {
              credits: quotaValidation.credits,
              quota_used: quotaValidation.quota_used,
              quota_limit: quotaValidation.quota_limit,
              quota_remaining: quotaValidation.quota_remaining,
              is_premium: isPremium
            }
          }),
          { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
      
      // Consume credit in old system
      let creditConsumption: any;
      
      if (userType === 'authenticated') {
        const { data, error } = await supabase.rpc('consume_credit_with_quota', {
          p_user_id: userIdentifier,
          p_device_id: null,
          p_is_premium: isPremium
        });
        
        if (error) {
          console.error('❌ [STEVE-JOBS] Credit consumption error:', error);
          return new Response(
            JSON.stringify({ success: false, error: 'Credit consumption failed' }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }
        
        creditConsumption = data;
      } else {
        const { data, error } = await supabase.rpc('consume_credit_with_quota', {
          p_user_id: null,
          p_device_id: userIdentifier,
          p_is_premium: isPremium
        });
        
        if (error) {
          console.error('❌ [STEVE-JOBS] Credit consumption error:', error);
          return new Response(
            JSON.stringify({ success: false, error: 'Credit consumption failed' }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }
        
        creditConsumption = data;
      }
      
      if (!creditConsumption.success) {
        console.log(`❌ [STEVE-JOBS] Credit consumption failed: ${creditConsumption.error}`);
        
        return new Response(
          JSON.stringify({
            success: false,
            error: creditConsumption.error,
            quota_info: {
              credits: creditConsumption.credits,
              quota_used: creditConsumption.quota_used,
              quota_limit: creditConsumption.quota_limit,
              quota_remaining: creditConsumption.quota_remaining,
              is_premium: isPremium
            }
          }),
          { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
      
      // Set quota result for old system
      quotaResult = {
        success: true,
        quota_used: creditConsumption.quota_used,
        quota_limit: creditConsumption.quota_limit,
        quota_remaining: creditConsumption.quota_remaining,
        credits: creditConsumption.credits
      };
      
      console.log(`✅ [STEVE-JOBS] Old system credit consumed: ${creditConsumption.credits} credits remaining`);
    }
    
    // Check quota result (works for both systems)
    if (!quotaResult.success) {
      console.log(`❌ [QUOTA] Quota check failed: ${quotaResult.error}`);
      
      return new Response(
        JSON.stringify({
          success: false,
          error: quotaResult.error || 'Daily limit reached. Please try again tomorrow or upgrade to Premium.',
          quota_info: {
            credits: quotaResult.credits || 0,
            quota_used: quotaResult.quota_used || 0,
            quota_limit: quotaResult.quota_limit || 5,
            quota_remaining: quotaResult.quota_remaining || 0,
            is_premium: isPremium
          }
        }),
        { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }
    
    console.log(`✅ [QUOTA] Quota consumed successfully: ${quotaResult.quota_remaining} remaining`);
    
    // ============================================
    // 7. GENERATE JOB ID & TRACK START TIME
    // ============================================
    
    // Generate unique job ID for database tracking
    const jobId = crypto.randomUUID();
    const processingStartTime = Date.now();
    
    console.log(`📋 [STEVE-JOBS] Job ID: ${jobId}`);
    
    // ============================================
    // 8. CALL FAL.AI DIRECTLY (STEVE JOBS STYLE!)
    // ============================================
    
    console.log('🤖 [STEVE-JOBS] Calling Fal.AI directly...');
    
    const falAIKey = Deno.env.get('FAL_AI_API_KEY');
    if (!falAIKey) {
      throw new Error('FAL_AI_API_KEY not configured');
    }
    
    // Prepare Fal.AI request
    const falAIRequest = {
      prompt: prompt,
      image_urls: [image_url],
      num_images: 1,
      output_format: 'jpeg'
    };
    
    console.log('📤 [STEVE-JOBS] Fal.AI request:', JSON.stringify(falAIRequest, null, 2));
    
    // Call Fal.AI directly (synchronous)
    const falResponse = await fetch('https://fal.run/fal-ai/nano-banana/edit', {
      method: 'POST',
      headers: {
        'Authorization': `Key ${falAIKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(falAIRequest),
    });
    
    if (!falResponse.ok) {
      const errorText = await falResponse.text();
      console.error('❌ [STEVE-JOBS] Fal.AI error:', falResponse.status, errorText);
      throw new Error(`Fal.AI processing failed: ${falResponse.status}`);
    }
    
    const falResult = await falResponse.json();
    console.log('✅ [STEVE-JOBS] Fal.AI processing completed');
    
    if (!falResult.images || falResult.images.length === 0) {
      throw new Error('No processed images returned from Fal.AI');
    }
    
    const processedImageUrl = falResult.images[0].url;
    
    // ============================================
    // 9. SAVE PROCESSED IMAGE TO STORAGE
    // ============================================
    
    console.log('💾 [STEVE-JOBS] Saving processed image to storage...');
    
    // Download the processed image
    const imageResponse = await fetch(processedImageUrl);
    if (!imageResponse.ok) {
      throw new Error('Failed to download processed image');
    }
    
    const imageBuffer = await imageResponse.arrayBuffer();
    const timestamp = Date.now();
    const storagePath = `processed/${userIdentifier}/${timestamp}-result.jpg`;
    
    // Upload to Supabase Storage
    const { error: uploadError } = await supabase.storage
      .from('noname-banana-images-prod')
      .upload(storagePath, imageBuffer, {
        contentType: 'image/jpeg',
        upsert: true
      });
    
    if (uploadError) {
      throw new Error(`Failed to save processed image: ${uploadError.message}`);
    }
    
    // Generate signed URL for the processed image
    const { data: urlData, error: urlError } = await supabase.storage
      .from('noname-banana-images-prod')
      .createSignedUrl(storagePath, 604800); // 7 days
    
    if (urlError || !urlData?.signedUrl) {
      throw new Error(`Failed to generate signed URL: ${urlError?.message || 'No URL returned'}`);
    }
    
    console.log('✅ [STEVE-JOBS] Processed image saved:', urlData.signedUrl);
    
    // ============================================
    // 10. PERSIST JOB TO DATABASE
    // ============================================
    
    const processingEndTime = Date.now();
    const processingTimeSeconds = Math.floor((processingEndTime - processingStartTime) / 1000);
    const now = new Date().toISOString();
    
    console.log('💾 [STEVE-JOBS] Saving job to database...');
    console.log('🔍 [STEVE-JOBS] User identifier:', userIdentifier);
    console.log('🔍 [STEVE-JOBS] User type:', userType);
    
    // Test database connection and RLS policies
    console.log('🔍 [STEVE-JOBS] Testing database connection...');
    try {
      const { data: testData, error: testError } = await supabase
        .from('jobs')
        .select('id')
        .limit(1);
      
      if (testError) {
        console.error('❌ [STEVE-JOBS] Database connection test failed:', testError);
      } else {
        console.log('✅ [STEVE-JOBS] Database connection test passed');
      }
    } catch (testException) {
      console.error('❌ [STEVE-JOBS] Database connection test exception:', testException);
    }
    
    try {
      const jobRecord = {
        id: jobId,
        user_id: userType === 'authenticated' ? userIdentifier : null,
        device_id: userType === 'anonymous' ? userIdentifier : null,
        model: 'nano-banana-edit',
        status: 'completed',
        input_url: image_url,
        output_url: storagePath,
        options: {
          prompt: prompt,
          timestamp: timestamp,
          fal_image_url: processedImageUrl,
          processing_time_seconds: processingTimeSeconds
        },
        created_at: now,
        completed_at: now,
        updated_at: now,
        processing_time_seconds: processingTimeSeconds
      };
      
      console.log('🔍 [STEVE-JOBS] Job record to insert:', JSON.stringify(jobRecord, null, 2));
      
      const { data: insertData, error: dbError } = await supabase
        .from('jobs')
        .insert(jobRecord)
        .select();
      
      if (dbError) {
        // Log error but don't fail the request - image is already in storage
        console.error('❌ [STEVE-JOBS] Database insert failed:', dbError);
        console.error('❌ [STEVE-JOBS] Database error details:', JSON.stringify(dbError, null, 2));
        console.error('❌ [STEVE-JOBS] Error code:', dbError.code);
        console.error('❌ [STEVE-JOBS] Error message:', dbError.message);
        console.error('❌ [STEVE-JOBS] Error hint:', dbError.hint);
        console.error('⚠️ [STEVE-JOBS] Image saved but not in database. Job ID:', jobId);
        // Consider adding to a retry queue here in production
      } else {
        console.log('✅ [STEVE-JOBS] Job saved to database successfully:', jobId);
        console.log('✅ [STEVE-JOBS] Insert data returned:', JSON.stringify(insertData, null, 2));
        console.log('✅ [STEVE-JOBS] Job record inserted with user_id:', jobRecord.user_id, 'device_id:', jobRecord.device_id);
      }
    } catch (dbException: any) {
      // Catch any unexpected errors during DB insert
      console.error('❌ [STEVE-JOBS] Database exception:', dbException);
      console.error('❌ [STEVE-JOBS] Exception details:', JSON.stringify(dbException, null, 2));
      console.error('⚠️ [STEVE-JOBS] Continuing despite DB error. Job ID:', jobId);
    }
    
    // ============================================
    // 11. RETURN SUCCESS RESPONSE
    // ============================================
    
    const response: ProcessImageResponse = {
      success: true,
      processed_image_url: urlData.signedUrl,
      job_id: jobId,
      quota_info: {
        credits: quotaResult.credits || 0,
        quota_used: quotaResult.quota_used,
        quota_limit: quotaResult.quota_limit,
        quota_remaining: quotaResult.quota_remaining,
        is_premium: isPremium
      }
    };
    
    console.log('🎉 [STEVE-JOBS] Process completed successfully!');
    
    return new Response(
      JSON.stringify(response),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
    
  } catch (error: any) {
    console.error('❌ [STEVE-JOBS] Edge function error:', error);
    
    const response: ProcessImageResponse = {
      success: false,
      error: error.message || 'Internal server error'
    };
    
    return new Response(
      JSON.stringify(response),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
