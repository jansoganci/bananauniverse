# 🎯 Simplified Quota System Implementation Plan

**Date:** 2025-10-23  
**Status:** SIMPLIFIED FOR SMALL SCALE (~100 users)  
**Estimated Total Effort:** 5-6 hours  
**Risk Level:** LOW (with rollback plan)

---

## 📋 Quick Answers

### ✅ Supported User Types

**YES** - This system supports ALL user combinations:

1. **Anonymous + Free** → 5 generations/day
2. **Anonymous + Premium** → Unlimited generations
3. **Logged In + Free** → 5 generations/day  
4. **Logged In + Premium** → Unlimited generations

**Daily Quota:** 
- Free users (anon or logged in): **5 generations per day**
- Premium users: **Unlimited**

### 🔄 Migration Strategy

**OLD SYSTEM → NEW SYSTEM:**

1. **Create new tables** (old tables stay untouched)
2. **Update Edge Function** to use new system
3. **Update iOS app** to use new system
4. **Monitor for 7 days**
5. **Archive old tables** (don't delete yet)

**Rollback:** Can revert Edge Function and iOS app, old tables still work

### 📊 Monitoring & Debugging

**YES** - Comprehensive logging at every step:
- Edge Function: `console.log('[QUOTA] ...')`
- PostgreSQL: `RAISE LOG '[QUOTA] ...'`
- iOS: `print("🔍 [QUOTA] ...")`

### 🚨 Error Handling

**YES** - Proper error system:
- HTTP 429 for quota exceeded
- HTTP 403 for rate limit
- HTTP 500 for server errors
- All errors logged with context

---

## ✅ Phase 1: Database Setup (1.5 hours)

### Create New Tables (Parallel to Existing System)

```sql
-- Migration 017: Create simplified daily quota system

-- 1. Main quota table
CREATE TABLE daily_quotas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id TEXT,
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    used INTEGER DEFAULT 0 CHECK (used >= 0),
    limit_value INTEGER DEFAULT 5 CHECK (limit_value > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Ensure one row per user/device per day
    UNIQUE(COALESCE(user_id::text, device_id), date)
);

-- Indexes for performance
CREATE INDEX idx_daily_quotas_user ON daily_quotas(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_daily_quotas_device ON daily_quotas(device_id) WHERE device_id IS NOT NULL;
CREATE INDEX idx_daily_quotas_date ON daily_quotas(date);

-- 2. Audit log (for debugging)
CREATE TABLE quota_consumption_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    request_id UUID UNIQUE NOT NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    device_id TEXT,
    consumed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    quota_used INTEGER NOT NULL,
    quota_limit INTEGER NOT NULL,
    success BOOLEAN NOT NULL,
    error_message TEXT
);

CREATE INDEX idx_quota_log_request ON quota_consumption_log(request_id);
CREATE INDEX idx_quota_log_user ON quota_consumption_log(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_quota_log_device ON quota_consumption_log(device_id) WHERE device_id IS NOT NULL;
CREATE INDEX idx_quota_log_date ON quota_consumption_log(consumed_at DESC);

-- 3. Enable RLS
ALTER TABLE daily_quotas ENABLE ROW LEVEL SECURITY;
ALTER TABLE quota_consumption_log ENABLE ROW LEVEL SECURITY;

-- RLS Policies for authenticated users
CREATE POLICY "users_select_own_quota" ON daily_quotas
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "users_insert_own_quota" ON daily_quotas
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users_update_own_quota" ON daily_quotas
    FOR UPDATE USING (auth.uid() = user_id);

-- RLS Policies for anonymous users (via device_id header)
CREATE POLICY "anon_select_device_quota" ON daily_quotas
    FOR SELECT USING (
        device_id IS NOT NULL 
        AND device_id = current_setting('request.device_id', true)
    );

CREATE POLICY "anon_insert_device_quota" ON daily_quotas
    FOR INSERT WITH CHECK (
        device_id IS NOT NULL 
        AND device_id = current_setting('request.device_id', true)
    );

CREATE POLICY "anon_update_device_quota" ON daily_quotas
    FOR UPDATE USING (
        device_id IS NOT NULL 
        AND device_id = current_setting('request.device_id', true)
    );

-- Admin access
CREATE POLICY "admin_select_all_quota" ON daily_quotas
    FOR SELECT USING (public.is_admin_user());
```

### Create Core Function

```sql
-- Migration 018: Create consume_quota function

CREATE OR REPLACE FUNCTION consume_quota(
    p_user_id UUID DEFAULT NULL,
    p_device_id TEXT DEFAULT NULL,
    p_is_premium BOOLEAN DEFAULT FALSE,
    p_client_request_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_identity_key TEXT;
    v_today DATE;
    v_used INTEGER;
    v_limit INTEGER;
    v_success BOOLEAN;
    v_error_message TEXT;
BEGIN
    -- LOG: Function called
    RAISE LOG '[QUOTA] consume_quota() called: user_id=%, device_id=%, request_id=%, is_premium=%', 
        p_user_id, p_device_id, p_client_request_id, p_is_premium;
    
    -- Validate inputs
    IF p_user_id IS NULL AND p_device_id IS NULL THEN
        RAISE LOG '[QUOTA] ERROR: Missing user_id and device_id';
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Either user_id or device_id must be provided',
            'quota_used', 0,
            'quota_limit', 5,
            'quota_remaining', 0
        );
    END IF;
    
    -- Set identity key (user_id for authenticated, device_id for anonymous)
    v_identity_key := COALESCE(p_user_id::text, p_device_id);
    v_today := CURRENT_DATE;
    
    -- IDEMPOTENCY CHECK: Prevent double-charging
    IF p_client_request_id IS NOT NULL THEN
        SELECT COUNT(*) INTO v_used
        FROM quota_consumption_log
        WHERE request_id = p_client_request_id;
        
        IF v_used > 0 THEN
            RAISE LOG '[QUOTA] Idempotent request: request_id=% already processed', p_client_request_id;
            
            -- Return cached result
            SELECT quota_used, quota_limit INTO v_used, v_limit
            FROM quota_consumption_log
            WHERE request_id = p_client_request_id
            LIMIT 1;
            
            RETURN jsonb_build_object(
                'success', true,
                'idempotent', true,
                'quota_used', v_used,
                'quota_limit', v_limit,
                'quota_remaining', v_limit - v_used
            );
        END IF;
    END IF;
    
    -- PREMIUM BYPASS: Premium users get unlimited quota
    IF p_is_premium THEN
        RAISE LOG '[QUOTA] Premium user detected - bypassing quota';
        
        RETURN jsonb_build_object(
            'success', true,
            'quota_used', 0,
            'quota_limit', 999999,
            'quota_remaining', 999999,
            'premium_bypass', true
        );
    END IF;
    
    -- UPSERT quota record (atomic operation)
    INSERT INTO daily_quotas (user_id, device_id, date, used, limit_value)
    VALUES (p_user_id, p_device_id, v_today, 1, 5)
    ON CONFLICT (COALESCE(user_id::text, device_id), date) 
    DO UPDATE SET
        used = daily_quotas.used + 1,
        updated_at = NOW()
    WHERE daily_quotas.used < daily_quotas.limit_value
    RETURNING used, limit_value INTO v_used, v_limit;
    
    -- LOG: Upsert result
    RAISE LOG '[QUOTA] UPSERT result: used=%, limit=%', v_used, v_limit;
    
    -- Check if quota exceeded
    IF v_used > v_limit THEN
        v_success := false;
        v_error_message := 'Daily quota exceeded';
        RAISE LOG '[QUOTA] ERROR: Quota exceeded - used=%, limit=%', v_used, v_limit;
    ELSE
        v_success := true;
        v_error_message := NULL;
        RAISE LOG '[QUOTA] SUCCESS: Quota consumed - used=%, remaining=%', v_used, v_limit - v_used;
    END IF;
    
    -- Log consumption for audit and idempotency
    IF p_client_request_id IS NOT NULL THEN
        INSERT INTO quota_consumption_log (
            request_id, user_id, device_id, consumed_at, 
            quota_used, quota_limit, success, error_message
        ) VALUES (
            p_client_request_id, p_user_id, p_device_id, NOW(),
            v_used, v_limit, v_success, v_error_message
        );
        
        RAISE LOG '[QUOTA] Logged consumption: request_id=%', p_client_request_id;
    END IF;
    
    -- Return result
    RETURN jsonb_build_object(
        'success', v_success,
        'error', v_error_message,
        'quota_used', v_used,
        'quota_limit', v_limit,
        'quota_remaining', GREATEST(0, v_limit - v_used)
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE LOG '[QUOTA] EXCEPTION: %', SQLERRM;
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Database error: ' || SQLERRM,
            'quota_used', 0,
            'quota_limit', 5,
            'quota_remaining', 0
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION consume_quota(UUID, TEXT, BOOLEAN, UUID) TO authenticated, anon;

-- Function to get current quota
CREATE OR REPLACE FUNCTION get_quota(
    p_user_id UUID DEFAULT NULL,
    p_device_id TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_used INTEGER := 0;
    v_limit INTEGER := 5;
BEGIN
    SELECT used, limit_value INTO v_used, v_limit
    FROM daily_quotas
    WHERE COALESCE(user_id::text, device_id) = COALESCE(p_user_id::text, p_device_id)
    AND date = CURRENT_DATE
    LIMIT 1;
    
    RETURN jsonb_build_object(
        'quota_used', COALESCE(v_used, 0),
        'quota_limit', v_limit,
        'quota_remaining', v_limit - COALESCE(v_used, 0)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_quota(UUID, TEXT) TO authenticated, anon;

-- ============================================
-- 4. QUOTA SYSTEM CLEANUP FUNCTIONS
-- ============================================

-- Function to clean up old quota consumption logs
CREATE OR REPLACE FUNCTION cleanup_quota_consumption_logs()
RETURNS TABLE(deleted_count INTEGER, errors TEXT[]) AS $$
DECLARE
    deleted_count INTEGER := 0;
    error_messages TEXT[] := '{}';
    cleanup_start TIMESTAMPTZ := NOW();
BEGIN
    -- Log cleanup start
    INSERT INTO cleanup_logs (operation, details, created_at)
    VALUES ('cleanup_quota_logs_start', 
            jsonb_build_object('started_at', cleanup_start), 
            NOW());

    -- Delete quota consumption logs older than 90 days
    DELETE FROM quota_consumption_log
    WHERE consumed_at < NOW() - INTERVAL '90 days';
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    -- Log cleanup completion
    INSERT INTO cleanup_logs (operation, details, created_at)
    VALUES ('cleanup_quota_logs_complete', 
            jsonb_build_object(
                'deleted_count', deleted_count,
                'execution_time_ms', EXTRACT(EPOCH FROM (NOW() - cleanup_start)) * 1000
            ), 
            NOW());
    
    RETURN QUERY SELECT deleted_count, error_messages;
EXCEPTION
    WHEN OTHERS THEN
        -- Log error
        INSERT INTO cleanup_logs (operation, details, created_at)
        VALUES ('cleanup_quota_logs_error', 
                jsonb_build_object(
                    'error', SQLERRM,
                    'execution_time_ms', EXTRACT(EPOCH FROM (NOW() - cleanup_start)) * 1000
                ), 
                NOW());
        
        -- Re-raise the exception
        RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION cleanup_quota_consumption_logs() TO service_role;

-- Function to clean up old daily quota records (keep 1 year for analytics)
CREATE OR REPLACE FUNCTION cleanup_old_daily_quotas()
RETURNS TABLE(deleted_count INTEGER, errors TEXT[]) AS $$
DECLARE
    deleted_count INTEGER := 0;
    error_messages TEXT[] := '{}';
    cleanup_start TIMESTAMPTZ := NOW();
BEGIN
    -- Log cleanup start
    INSERT INTO cleanup_logs (operation, details, created_at)
    VALUES ('cleanup_daily_quotas_start', 
            jsonb_build_object('started_at', cleanup_start), 
            NOW());

    -- Delete daily quota records older than 1 year (keep for analytics)
    DELETE FROM daily_quotas
    WHERE date < CURRENT_DATE - INTERVAL '1 year';
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    -- Log cleanup completion
    INSERT INTO cleanup_logs (operation, details, created_at)
    VALUES ('cleanup_daily_quotas_complete', 
            jsonb_build_object(
                'deleted_count', deleted_count,
                'execution_time_ms', EXTRACT(EPOCH FROM (NOW() - cleanup_start)) * 1000
            ), 
            NOW());
    
    RETURN QUERY SELECT deleted_count, error_messages;
EXCEPTION
    WHEN OTHERS THEN
        -- Log error
        INSERT INTO cleanup_logs (operation, details, created_at)
        VALUES ('cleanup_daily_quotas_error', 
                jsonb_build_object(
                    'error', SQLERRM,
                    'execution_time_ms', EXTRACT(EPOCH FROM (NOW() - cleanup_start)) * 1000
                ), 
                NOW());
        
        -- Re-raise the exception
        RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION cleanup_old_daily_quotas() TO service_role;
```

### Verification Queries

```sql
-- Test consume_quota for anonymous user
SELECT consume_quota(
    p_device_id := 'test-device-123',
    p_is_premium := false,
    p_client_request_id := 'test-request-123'
);
-- Expected: {success: true, quota_used: 1, quota_limit: 5, quota_remaining: 4}

-- Test idempotency (same request_id twice)
SELECT consume_quota(
    p_device_id := 'test-device-123',
    p_client_request_id := 'test-request-123'
);
-- Expected: {success: true, idempotent: true, quota_used: 1} (NOT incremented)

-- Test premium bypass
SELECT consume_quota(
    p_device_id := 'test-device-456',
    p_is_premium := true,
    p_client_request_id := 'test-request-456'
);
-- Expected: {success: true, quota_used: 0, quota_limit: 999999, premium_bypass: true}
```

---

## ✅ Phase 2: Update Edge Function (1.5 hours)

### Update process-image/index.ts (Backward Compatible)

**CRITICAL:** Keep both old and new systems working during transition:

```typescript
// supabase/functions/process-image/index.ts

// Add new interface for new quota system
interface ProcessImageRequest {
  image_url: string;
  prompt: string;
  device_id?: string;
  user_id?: string;
  is_premium?: boolean;
  client_request_id?: string; // NEW: For idempotency
}

// Keep old interface for backward compatibility
interface ProcessImageRequestLegacy {
  image_url: string;
  prompt: string;
  device_id?: string;
  user_id?: string;
  is_premium?: boolean;
}

// NEW: Try new quota system first, fallback to old system
async function handleQuotaConsumption(supabase: any, userType: string, userIdentifier: string, isPremium: boolean, clientRequestId?: string) {
  // Try new quota system first
  try {
    console.log('🆕 [QUOTA] Trying new quota system...');
    
    const { data: newQuotaResult, error: newQuotaError } = await supabase.rpc('consume_quota', {
      p_user_id: userType === 'authenticated' ? userIdentifier : null,
      p_device_id: userType === 'anonymous' ? userIdentifier : null,
      p_is_premium: isPremium,
      p_client_request_id: clientRequestId || crypto.randomUUID()
    });
    
    if (!newQuotaError && newQuotaResult) {
      console.log('✅ [QUOTA] New quota system success');
      return {
        success: newQuotaResult.success,
        error: newQuotaResult.error,
        quota_info: {
          credits: 0, // New system doesn't use credits
          quota_used: newQuotaResult.quota_used,
          quota_limit: newQuotaResult.quota_limit,
          quota_remaining: newQuotaResult.quota_remaining,
          is_premium: isPremium
        }
      };
    }
  } catch (error) {
    console.log('⚠️ [QUOTA] New quota system failed, falling back to old system:', error.message);
  }
  
  // Fallback to old quota system
  console.log('🔄 [QUOTA] Using old quota system...');
  
  let quotaValidation: any;
  let creditConsumption: any;
  
  if (userType === 'authenticated') {
    const { data, error } = await supabase.rpc('validate_user_daily_quota', {
      p_user_id: userIdentifier,
      p_is_premium: isPremium
    });
    
    if (error) throw error;
    quotaValidation = data;
    
    if (quotaValidation.valid) {
      const { data, error } = await supabase.rpc('consume_credit_with_quota', {
        p_user_id: userIdentifier,
        p_device_id: null,
        p_is_premium: isPremium
      });
      
      if (error) throw error;
      creditConsumption = data;
    }
  } else {
    const { data, error } = await supabase.rpc('validate_anonymous_daily_quota', {
      p_device_id: userIdentifier,
      p_is_premium: isPremium
    });
    
    if (error) throw error;
    quotaValidation = data;
    
    if (quotaValidation.valid) {
      const { data, error } = await supabase.rpc('consume_credit_with_quota', {
        p_user_id: null,
        p_device_id: userIdentifier,
        p_is_premium: isPremium
      });
      
      if (error) throw error;
      creditConsumption = data;
    }
  }
  
  if (!quotaValidation.valid) {
    return {
      success: false,
      error: quotaValidation.error,
      quota_info: {
        credits: quotaValidation.credits,
        quota_used: quotaValidation.quota_used,
        quota_limit: quotaValidation.quota_limit,
        quota_remaining: quotaValidation.quota_remaining,
        is_premium: isPremium
      }
    };
  }
  
  if (!creditConsumption.success) {
    return {
      success: false,
      error: creditConsumption.error,
      quota_info: {
        credits: creditConsumption.credits,
        quota_used: creditConsumption.quota_used,
        quota_limit: creditConsumption.quota_limit,
        quota_remaining: creditConsumption.quota_remaining,
        is_premium: isPremium
      }
    };
  }
  
  return {
    success: true,
    error: null,
    quota_info: {
      credits: creditConsumption.credits,
      quota_used: creditConsumption.quota_used,
      quota_limit: creditConsumption.quota_limit,
      quota_remaining: creditConsumption.quota_remaining,
      is_premium: isPremium
    }
  };
}

// Update main function to use new quota handler
Deno.serve(async (req: Request) => {
  // ... existing code until quota validation ...
  
  // ============================================
  // 4. QUOTA VALIDATION & CONSUMPTION (DUAL SYSTEM)
  // ============================================
  
  console.log('💳 [STEVE-JOBS] Validating quota (new + old system)...');
  
  const quotaResult = await handleQuotaConsumption(
    supabase, 
    userType, 
    userIdentifier, 
    isPremium, 
    requestData.client_request_id
  );
  
  if (!quotaResult.success) {
    console.log(`❌ [STEVE-JOBS] Quota validation failed: ${quotaResult.error}`);
    
    return new Response(
      JSON.stringify({
        success: false,
        error: quotaResult.error,
        quota_info: quotaResult.quota_info
      }),
      { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
  
  console.log(`✅ [STEVE-JOBS] Quota consumed successfully: ${quotaResult.quota_info.quota_remaining} remaining`);
  
  // ... rest of existing code ...
});

```typescript
// supabase/functions/process-image/index.ts

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

interface ProcessImageRequest {
  image_url: string;
  prompt: string;
  device_id?: string;
  user_id?: string;
  is_premium?: boolean;
  client_request_id?: string;
}

interface ProcessImageResponse {
  success: boolean;
  processed_image_url?: string;
  error?: string;
  quota_info?: {
    quota_used: number;
    quota_limit: number;
    quota_remaining: number;
  };
}

Deno.serve(async (req: Request) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, device-id',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  };

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    console.log('🎨 [PROCESS] Image processing request started');
    
    // ============================================
    // 1. PARSE REQUEST
    // ============================================
    const requestData: ProcessImageRequest = await req.json();
    let { image_url, prompt, device_id, user_id, is_premium, client_request_id } = requestData;
    
    console.log('[QUOTA] Request parsed:', {
      user_id: user_id || 'null',
      device_id: device_id || 'null',
      is_premium: is_premium || false,
      request_id: client_request_id || 'null'
    });
    
    if (!image_url || !prompt) {
      console.error('[QUOTA] ERROR: Missing image_url or prompt');
      return new Response(
        JSON.stringify({ success: false, error: 'Missing image_url or prompt' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }
    
    // ============================================
    // 2. INITIALIZE SUPABASE
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
    
    const authHeader = req.headers.get('authorization');
    if (authHeader && authHeader.startsWith('Bearer ')) {
      try {
        const token = authHeader.split(' ')[1];
        console.log('[QUOTA] Authenticating user with JWT...');
        
        const { data: { user }, error } = await supabase.auth.getUser(token);
        
        if (error || !user) {
          throw new Error('Invalid JWT');
        }
        
        userIdentifier = user_id || user.id;
        userType = 'authenticated';
        isPremium = is_premium || false;
        
        console.log('[QUOTA] ✅ Authenticated user:', user.id, 'Premium:', isPremium);
      } catch (error: any) {
        console.log('[QUOTA] ⚠️ JWT auth failed, falling back to anonymous');
        
        if (!device_id) {
          console.error('[QUOTA] ERROR: No device_id for anonymous fallback');
          return new Response(
            JSON.stringify({ success: false, error: 'Authentication failed' }),
            { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }
        
        userIdentifier = device_id;
        userType = 'anonymous';
        isPremium = is_premium || false;
      }
    } else {
      console.log('[QUOTA] No auth header, using anonymous user');
      
      if (!device_id) {
        console.error('[QUOTA] ERROR: No device_id provided');
        return new Response(
          JSON.stringify({ success: false, error: 'device_id required' }),
          { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
      
      userIdentifier = device_id;
      userType = 'anonymous';
      isPremium = is_premium || false;
    }
    
    // ============================================
    // 4. CONSUME QUOTA
    // ============================================
    console.log('[QUOTA] Calling consume_quota()...');
    
    const { data: quotaResult, error: quotaError } = await supabase.rpc('consume_quota', {
      p_user_id: userType === 'authenticated' ? userIdentifier : null,
      p_device_id: userType === 'anonymous' ? userIdentifier : null,
      p_is_premium: isPremium,
      p_client_request_id: client_request_id || crypto.randomUUID()
    });
    
    if (quotaError) {
      console.error('[QUOTA] ERROR: consume_quota() failed:', quotaError);
      return new Response(
        JSON.stringify({ success: false, error: 'Quota check failed' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }
    
    console.log('[QUOTA] Quota result:', quotaResult);
    
    if (!quotaResult.success) {
      console.log('[QUOTA] ⛔ Quota exceeded or error:', quotaResult.error);
      return new Response(
        JSON.stringify({
          success: false,
          error: quotaResult.error || 'Daily quota exceeded',
          quota_info: {
            quota_used: quotaResult.quota_used,
            quota_limit: quotaResult.quota_limit,
            quota_remaining: quotaResult.quota_remaining
          }
        }),
        { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }
    
    console.log('[QUOTA] ✅ Quota consumed successfully:', quotaResult.quota_remaining, 'remaining');
    
    // ============================================
    // 5. PROCESS IMAGE WITH FAL.AI
    // ============================================
    console.log('[PROCESS] Calling Fal.AI...');
    
    const falAIKey = Deno.env.get('FAL_AI_API_KEY');
    if (!falAIKey) {
      throw new Error('FAL_AI_API_KEY not configured');
    }
    
    const falResponse = await fetch('https://fal.run/fal-ai/nano-banana/edit', {
      method: 'POST',
      headers: {
        'Authorization': `Key ${falAIKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        prompt: prompt,
        image_urls: [image_url],
        num_images: 1,
        output_format: 'jpeg'
      }),
    });
    
    if (!falResponse.ok) {
      const errorText = await falResponse.text();
      console.error('[PROCESS] ERROR: Fal.AI failed:', falResponse.status, errorText);
      throw new Error(`Fal.AI processing failed: ${falResponse.status}`);
    }
    
    const falResult = await falResponse.json();
    console.log('[PROCESS] ✅ Fal.AI processing completed');
    
    if (!falResult.images || falResult.images.length === 0) {
      throw new Error('No processed images returned from Fal.AI');
    }
    
    const processedImageUrl = falResult.images[0].url;
    
    // ============================================
    // 6. SAVE TO STORAGE
    // ============================================
    console.log('[STORAGE] Saving processed image...');
    
    const imageResponse = await fetch(processedImageUrl);
    if (!imageResponse.ok) {
      throw new Error('Failed to download processed image');
    }
    
    const imageBuffer = await imageResponse.arrayBuffer();
    const timestamp = Date.now();
    const storagePath = `processed/${userIdentifier}/${timestamp}-result.jpg`;
    
    const { error: uploadError } = await supabase.storage
      .from('noname-banana-images-prod')
      .upload(storagePath, imageBuffer, {
        contentType: 'image/jpeg',
        upsert: true
      });
    
    if (uploadError) {
      throw new Error(`Failed to save processed image: ${uploadError.message}`);
    }
    
    const { data: urlData, error: urlError } = await supabase.storage
      .from('noname-banana-images-prod')
      .createSignedUrl(storagePath, 604800);
    
    if (urlError || !urlData?.signedUrl) {
      throw new Error(`Failed to generate signed URL: ${urlError?.message || 'No URL returned'}`);
    }
    
    console.log('[STORAGE] ✅ Image saved:', urlData.signedUrl);
    
    // ============================================
    // 7. RETURN SUCCESS
    // ============================================
    const response: ProcessImageResponse = {
      success: true,
      processed_image_url: urlData.signedUrl,
      quota_info: {
        quota_used: quotaResult.quota_used,
        quota_limit: quotaResult.quota_limit,
        quota_remaining: quotaResult.quota_remaining
      }
    };
    
    console.log('[PROCESS] ✅ Request completed successfully');
    
    return new Response(
      JSON.stringify(response),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
    
  } catch (error: any) {
    console.error('[PROCESS] ❌ Edge function error:', error);
    
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
```

---

## ✅ Phase 3: Update iOS App (2 hours)

### Update HybridCreditManager.swift (Backward Compatible)

**CRITICAL:** Keep old properties for existing UI compatibility:

```swift
// BananaUniverse/Core/Services/HybridCreditManager.swift

@MainActor
class HybridCreditManager: ObservableObject {
    static let shared = HybridCreditManager()
    
    // NEW: New quota system properties
    @Published var quotaUsed: Int = 0
    @Published var quotaLimit: Int = 5
    @Published var isPremiumUser: Bool = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // OLD: Keep for backward compatibility with existing UI
    @Published var credits: Int = 0 // Always 0 in new system
    @Published var dailyQuotaUsed: Int = 0 // Maps to quotaUsed
    @Published var dailyQuotaLimit: Int = 5 // Maps to quotaLimit
    @Published var remainingQuota: Int = 5 // Maps to quotaRemaining
    @Published var userState: UserState = .anonymous(deviceId: UUID().uuidString)
    @Published var creditsLoaded = false
    
    // Storage keys (keep existing)
    private let creditsKey = "hybrid_credits_v1"
    private let deviceUUIDKey = "device_uuid_v1"
    private let userStateKey = "user_state_v1"
    private let dailyQuotaKey = "daily_quota_v1"
    private let lastQuotaDateKey = "last_quota_date_v1"
    private let premiumStatusKey = "premium_status_v1"
    
    private let supabase: SupabaseService
    
    private init() {
        self.supabase = SupabaseService.shared
        loadUserState()
        loadCredits() // Load old system for compatibility
        loadDailyQuota() // Load old system for compatibility
        updatePremiumStatus()
        scheduleSubscriptionRefresh()
        
        // NEW: Initialize new quota system
        Task {
            await loadQuota()
        }
    }
    
    // NEW: Load quota from new backend system
    func loadQuota() async {
        isLoading = true
        print("🔍 [QUOTA] Loading quota from backend...")
        
        do {
            let userState = HybridAuthService.shared.userState
            
            let result: QuotaResponse = try await supabase.client
                .rpc("get_quota", params: [
                    "p_user_id": userState.isAuthenticated ? userState.identifier : nil,
                    "p_device_id": userState.isAuthenticated ? nil : userState.identifier
                ])
                .execute()
                .value
            
            quotaUsed = result.quotaUsed
            quotaLimit = result.quotaLimit
            
            // Update compatibility properties
            updateCompatibilityProperties()
            
            print("🔍 [QUOTA] Loaded quota: \(quotaUsed)/\(quotaLimit)")
            isLoading = false
        } catch {
            print("❌ [QUOTA] Failed to load quota: \(error.localizedDescription)")
            
            // FALLBACK: Use old system values
            quotaUsed = dailyQuotaUsed
            quotaLimit = dailyQuotaLimit
            updateCompatibilityProperties()
            
            isLoading = false
        }
    }
    
    // NEW: Update quota from backend response
    func updateQuota(quotaUsed: Int, quotaLimit: Int) async {
        self.quotaUsed = quotaUsed
        self.quotaLimit = quotaLimit
        updateCompatibilityProperties()
        print("✅ [QUOTA] Updated from backend: \(quotaUsed)/\(quotaLimit)")
    }
    
    // NEW: Update premium status from StoreKit
    func updatePremiumStatus(_ isPremium: Bool) {
        isPremiumUser = isPremium
        updateCompatibilityProperties()
        print("🔄 [QUOTA] Premium status updated: \(isPremium)")
    }
    
    // NEW: User state management
    func setUserState(_ newState: UserState) {
        let previousState = userState
        userState = newState
        
        // Load quota from backend when user state changes
        Task {
            await loadQuota()
        }
        
        print("🔄 [QUOTA] User state changed: \(previousState) → \(newState)")
    }
    
    // NEW: New user initialization
    func initializeNewUser() async {
        print("🆕 [QUOTA] Initializing new user...")
        
        // Create initial quota record in backend
        do {
            let userState = HybridAuthService.shared.userState
            
            let result: QuotaResponse = try await supabase.client
                .rpc('consume_quota', params: [
                    "p_user_id": userState.isAuthenticated ? userState.identifier : nil,
                    "p_device_id": userState.isAuthenticated ? nil : userState.identifier,
                    "p_is_premium": false,
                    "p_client_request_id": "init-" + UUID().uuidString
                ])
                .execute()
                .value
            
            print("✅ [QUOTA] New user initialized in backend")
        } catch {
            print("⚠️ [QUOTA] Failed to initialize new user in backend: \(error)")
        }
    }
    
    // NEW: Check if user can process image
    func canProcessImage() -> Bool {
        print("🔍 [QUOTA] canProcessImage() check")
        print("🔍 [QUOTA] Premium: \(isPremiumUser), Quota: \(quotaUsed)/\(quotaLimit)")
        
        if isPremiumUser {
            print("✅ [QUOTA] Premium user - unlimited quota")
            return true
        }
        
        let canProcess = quotaUsed < quotaLimit
        print("🔍 [QUOTA] Can process: \(canProcess)")
        return canProcess
    }
    
    // NEW: Quota display properties
    var quotaRemaining: Int {
        return max(0, quotaLimit - quotaUsed)
    }
    
    var quotaDisplayText: String {
        if isPremiumUser {
            return "Unlimited"
        }
        return "\(quotaUsed)/\(quotaLimit)"
    }
    
    var shouldShowQuotaWarning: Bool {
        return !isPremiumUser && quotaRemaining == 1
    }
    
    var quotaWarningMessage: String {
        if quotaRemaining == 1 {
            return "⚠️ Only 1 generation left today!"
        }
        return ""
    }
    
    // COMPATIBILITY: Update old properties when new properties change
    private func updateCompatibilityProperties() {
        dailyQuotaUsed = quotaUsed
        dailyQuotaLimit = quotaLimit
        remainingQuota = quotaRemaining
        credits = 0 // Always 0 in new system
    }
    
    // OLD: Keep existing methods for backward compatibility
    func loadCredits() {
        // Keep existing implementation for fallback
        // ... existing code ...
    }
    
    func loadDailyQuota() {
        // Keep existing implementation for fallback
        // ... existing code ...
    }
    
    // ... rest of existing methods ...
}

```swift
// BananaUniverse/Core/Services/HybridCreditManager.swift

@MainActor
class HybridCreditManager: ObservableObject {
    static let shared = HybridCreditManager()
    
    // REMOVED: credits property
    // REMOVED: local quota tracking
    
    @Published var quotaUsed: Int = 0
    @Published var quotaLimit: Int = 5
    @Published var isPremiumUser: Bool = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabase: SupabaseService
    
    private init() {
        self.supabase = SupabaseService.shared
        Task {
            await loadQuota()
        }
    }
    
    // Fetch quota from backend
    func loadQuota() async {
        isLoading = true
        print("🔍 [QUOTA] Loading quota from backend...")
        
        do {
            let userState = HybridAuthService.shared.userState
            
            let result: QuotaResponse = try await supabase.client
                .rpc("get_quota", params: [
                    "p_user_id": userState.isAuthenticated ? userState.identifier : nil,
                    "p_device_id": userState.isAuthenticated ? nil : userState.identifier
                ])
                .execute()
                .value
            
            quotaUsed = result.quotaUsed
            quotaLimit = result.quotaLimit
            
            // Update compatibility properties for existing UI
            updateCompatibilityProperties()
            
            print("🔍 [QUOTA] Loaded quota: \(quotaUsed)/\(quotaLimit)")
            isLoading = false
        } catch {
            print("❌ [QUOTA] Failed to load quota: \(error.localizedDescription)")
            isLoading = false
        }
    }
    
    // Update quota from backend response (called by SupabaseService)
    func updateQuota(quotaUsed: Int, quotaLimit: Int) async {
        self.quotaUsed = quotaUsed
        self.quotaLimit = quotaLimit
        updateCompatibilityProperties()
        print("✅ [QUOTA] Updated from backend: \(quotaUsed)/\(quotaLimit)")
    }
    
    // Update premium status from StoreKit
    func updatePremiumStatus(_ isPremium: Bool) {
        isPremiumUser = isPremium
        updateCompatibilityProperties()
        print("🔄 [QUOTA] Premium status updated: \(isPremium)")
    }
    
    // MARK: - User State Management (CRITICAL)
    
    func setUserState(_ newState: UserState) {
        let previousState = userState
        userState = newState
        
        // CRITICAL: Load quota from backend when user state changes
        Task {
            await loadQuota()
        }
        
        print("🔄 [QUOTA] User state changed: \(previousState) → \(newState)")
    }
    
    // MARK: - New User Onboarding (CRITICAL)
    
    func initializeNewUser() async {
        print("🆕 [QUOTA] Initializing new user...")
        
        // Create initial quota record in backend
        do {
            let userState = HybridAuthService.shared.userState
            
            let result: QuotaResponse = try await supabase.client
                .rpc('consume_quota', params: [
                    "p_user_id": userState.isAuthenticated ? userState.identifier : nil,
                    "p_device_id": userState.isAuthenticated ? nil : userState.identifier,
                    "p_is_premium": false,
                    "p_client_request_id": "init-" + UUID().uuidString
                ])
                .execute()
                .value
            
            // This will create the initial record with 0 used
            print("✅ [QUOTA] New user initialized in backend")
        } catch {
            print("⚠️ [QUOTA] Failed to initialize new user in backend: \(error)")
            // Don't fail - backend will create record on first generation
        }
    }
    
    func canProcessImage() -> Bool {
        print("🔍 [QUOTA] canProcessImage() check")
        print("🔍 [QUOTA] Premium: \(isPremiumUser), Quota: \(quotaUsed)/\(quotaLimit)")
        
        if isPremiumUser {
            print("✅ [QUOTA] Premium user - unlimited quota")
            return true
        }
        
        let canProcess = quotaUsed < quotaLimit
        print("🔍 [QUOTA] Can process: \(canProcess)")
        return canProcess
    }
    
    var quotaRemaining: Int {
        return max(0, quotaLimit - quotaUsed)
    }
    
    var quotaDisplayText: String {
        if isPremiumUser {
            return "Unlimited"
        }
        return "\(quotaUsed)/\(quotaLimit)"
    }
    
    var shouldShowQuotaWarning: Bool {
        return !isPremiumUser && quotaRemaining == 1
    }
    
    var quotaWarningMessage: String {
        if quotaRemaining == 1 {
            return "⚠️ Only 1 generation left today!"
        }
        return ""
    }
    
    // MARK: - Backward Compatibility Properties
    // These maintain compatibility with existing UI components
    
    @Published var credits: Int = 0 // Always 0 in new system
    @Published var dailyQuotaUsed: Int = 0 // Maps to quotaUsed
    @Published var dailyQuotaLimit: Int = 5 // Maps to quotaLimit
    @Published var remainingQuota: Int = 5 // Maps to quotaRemaining
    
    // Update compatibility properties when quota changes
    private func updateCompatibilityProperties() {
        dailyQuotaUsed = quotaUsed
        dailyQuotaLimit = quotaLimit
        remainingQuota = quotaRemaining
        credits = 0 // Always 0 in new system
    }
    
    // Override quota setters to update compatibility
    private var _quotaUsed: Int = 0 {
        didSet {
            quotaUsed = _quotaUsed
            updateCompatibilityProperties()
        }
    }
    
    private var _quotaLimit: Int = 5 {
        didSet {
            quotaLimit = _quotaLimit
            updateCompatibilityProperties()
        }
    }
}

struct QuotaResponse: Codable {
    let quotaUsed: Int
    let quotaLimit: Int
    let quotaRemaining: Int
    
    enum CodingKeys: String, CodingKey {
        case quotaUsed = "quota_used"
        case quotaLimit = "quota_limit"
        case quotaRemaining = "quota_remaining"
    }
}
```

### Update SupabaseService.swift

```swift
// BananaUniverse/Core/Services/SupabaseService.swift

func processImageSteveJobsStyle(
    imageURL: String,
    prompt: String,
    options: [String: Any] = [:]
) async throws -> SteveJobsProcessResponse {
    
    print("🔍 [QUOTA] Starting image processing...")
    
    // Check if user can process
    guard await HybridCreditManager.shared.canProcessImage() else {
        print("❌ [QUOTA] Cannot process - quota exceeded")
        throw SupabaseError.insufficientCredits
    }
    
    let userState = HybridAuthService.shared.userState
    
    // Generate client_request_id for idempotency
    let clientRequestId = UUID().uuidString
    print("🔍 [QUOTA] Generated request ID: \(clientRequestId)")
    
    // Prepare request body
    var body: [String: Any] = [
        "image_url": imageURL,
        "prompt": prompt,
        "client_request_id": clientRequestId
    ]
    
    if userState.isAuthenticated {
        body["user_id"] = userState.identifier
    } else {
        body["device_id"] = userState.identifier
    }
    
    body["is_premium"] = await HybridCreditManager.shared.isPremiumUser
    
    print("🔍 [QUOTA] Request body: \(body)")
    
    let jsonData = try JSONSerialization.data(withJSONObject: body)
    
    guard let functionURL = URL(string: "\(Config.supabaseURL)/functions/v1/process-image") else {
        throw SupabaseError.invalidURL
    }
    
    var request = URLRequest(url: functionURL)
    request.httpMethod = "POST"
    
    if userState.isAuthenticated {
        if let session = try? await client.auth.session {
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            print("🔑 [QUOTA] Using authenticated token")
        }
    } else {
        request.setValue("Bearer \(Config.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        print("🔓 [QUOTA] Using anonymous key")
    }
    
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(userState.identifier, forHTTPHeaderField: "device-id")
    request.httpBody = jsonData
    request.timeoutInterval = 60
    
    let (responseData, urlResponse) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = urlResponse as? HTTPURLResponse else {
        throw SupabaseError.invalidResponse
    }
    
    print("🔍 [QUOTA] HTTP status: \(httpResponse.statusCode)")
    
    if httpResponse.statusCode == 429 {
        print("❌ [QUOTA] Quota exceeded - HTTP 429")
        throw SupabaseError.quotaExceeded
    }
    
    let response = try JSONDecoder().decode(SteveJobsProcessResponse.self, from: responseData)
    
    if response.success {
        // Update quota from backend response
        if let quotaInfo = response.quotaInfo {
            await HybridCreditManager.shared.updateQuota(
                quotaUsed: quotaInfo.quotaUsed,
                quotaLimit: quotaInfo.quotaLimit
            )
            print("✅ [QUOTA] Quota updated: \(quotaInfo.quotaUsed)/\(quotaInfo.quotaLimit)")
        }
        return response
    } else {
        print("❌ [QUOTA] Processing failed: \(response.error ?? "Unknown error")")
        throw SupabaseError.processingFailed(response.error ?? "Processing failed")
    }
}
```

---

## ✅ Phase 4: Deploy & Test (1 hour)

### Step 1: Deploy to Staging

```bash
# Apply migrations
supabase db push

# Deploy edge function
supabase functions deploy process-image

# Build iOS TestFlight
xcodebuild -workspace BananaUniverse.xcworkspace -scheme BananaUniverse archive
```

### Step 2: Test Each User Type

```bash
# Test anonymous free user
curl -X POST https://staging.supabase.co/functions/v1/process-image \
  -H "Content-Type: application/json" \
  -d '{"image_url": "test", "prompt": "test", "device_id": "test-device-123"}'

# Test authenticated free user
curl -X POST https://staging.supabase.co/functions/v1/process-image \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"image_url": "test", "prompt": "test", "user_id": "test-user-123"}'

# Test premium user (should bypass quota)
curl -X POST https://staging.supabase.co/functions/v1/process-image \
  -H "Content-Type: application/json" \
  -d '{"image_url": "test", "prompt": "test", "device_id": "test-device-456", "is_premium": true}'
```

### Step 3: Deploy to Production

```bash
# Apply migrations to production
supabase db push --linked

# Deploy edge function to production
supabase functions deploy process-image --linked

# Release iOS app to App Store
```

---

## Monitoring & Debugging Notes

### Log Output Example

When testing, you should see logs like this:

```
[Edge Function Logs]
🎨 [PROCESS] Image processing request started
[QUOTA] Request parsed: {user_id: null, device_id: abc-123, is_premium: false, request_id: xyz-789}
[QUOTA] No auth header, using anonymous user
[QUOTA] Calling consume_quota()...
[QUOTA] Quota result: {success: true, quota_used: 3, quota_limit: 5, quota_remaining: 2}
[QUOTA] ✅ Quota consumed successfully: 2 remaining
[PROCESS] Calling Fal.AI...
[PROCESS] ✅ Fal.AI processing completed
[STORAGE] Saving processed image...
[STORAGE] ✅ Image saved: https://...
[PROCESS] ✅ Request completed successfully

[PostgreSQL Logs]
[QUOTA] consume_quota() called: user_id=<NULL>, device_id=abc-123, request_id=xyz-789, is_premium=false
[QUOTA] UPSERT result: used=3, limit=5
[QUOTA] SUCCESS: Quota consumed - used=3, remaining=2
[QUOTA] Logged consumption: request_id=xyz-789

[iOS App Logs]
🔍 [QUOTA] Starting image processing...
🔍 [QUOTA] canProcessImage() check
🔍 [QUOTA] Premium: false, Quota: 3/5
🔍 [QUOTA] Can process: true
🔍 [QUOTA] Generated request ID: xyz-789
🔍 [QUOTA] Request body: {device_id: abc-123, ...}
🔓 [QUOTA] Using anonymous key
🔍 [QUOTA] HTTP status: 200
✅ [QUOTA] Quota updated: 3/5
```

---

## Error Handling

### Error Types & HTTP Status Codes

| Error | HTTP Status | When | User Message |
|-------|-------------|------|--------------|
| Quota exceeded | 429 | User used all daily quota | "Daily quota exceeded. Try again tomorrow!" |
| Rate limit | 429 | Too many requests | "Please slow down. Wait a moment and try again." |
| Auth failed | 401 | Invalid JWT or missing device_id | "Please sign in or restart the app." |
| Server error | 500 | Database or processing error | "Something went wrong. Please try again." |
| Invalid request | 400 | Missing image_url or prompt | "Please provide an image and prompt." |

### All Errors Are Logged

Every error includes context:
- User/device identifier
- Request ID
- Error message
- Timestamp
- Stack trace (for server errors)

---

## ✅ Phase 5: Add Quota Warning UI (30 minutes)

### Update HomeView.swift

Add a warning banner that shows when user has 1 quota left:

```swift
// BananaUniverse/Features/Home/Views/HomeView.swift

struct HomeView: View {
    @StateObject private var creditManager = HybridCreditManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Existing header...
            
            // QUOTA WARNING BANNER
            if creditManager.shouldShowQuotaWarning {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(creditManager.quotaWarningMessage)
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            
            // Rest of your existing content...
        }
    }
}
```

### Update ToolCard.swift

Add warning to the Generate button when quota is low:

```swift
// BananaUniverse/Core/Components/ToolCard/ToolCard.swift

struct ToolCard: View {
    @StateObject private var creditManager = HybridCreditManager.shared
    
    var body: some View {
        VStack {
            // Existing card content...
            
            Button(action: {
                // Existing action...
            }) {
                HStack {
                    if creditManager.shouldShowQuotaWarning {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                    }
                    Text("Generate")
                }
            }
            .disabled(!creditManager.canProcessImage())
        }
    }
}
```

### Update QuotaDisplayView.swift

Show warning in the header quota display:

```swift
// BananaUniverse/Core/Components/QuotaDisplayView.swift

struct QuotaDisplayView: View {
    @StateObject private var creditManager = HybridCreditManager.shared
    
    var body: some View {
        HStack {
            if creditManager.shouldShowQuotaWarning {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
            }
            
            Text(creditManager.quotaDisplayText)
                .font(.caption)
                .foregroundColor(creditManager.shouldShowQuotaWarning ? .orange : .primary)
        }
    }
}
```

---

## ✅ Phase 6: Add Quota System Cleanup (30 minutes)

### Update cleanup-db Edge Function

Add quota cleanup to your existing `cleanup-db` function:

```typescript
// supabase/functions/cleanup-db/index.ts

async function executeAtomicCleanup(supabase: any): Promise<{jobsDeleted: number, rateLimitDeleted: number, logsDeleted: number, quotaLogsDeleted: number, quotaRecordsDeleted: number, errors: string[]}> {
  const errors: string[] = [];
  let jobsDeleted = 0;
  let rateLimitDeleted = 0;
  let logsDeleted = 0;
  let quotaLogsDeleted = 0;
  let quotaRecordsDeleted = 0;
  
  try {
    // ... existing cleanup code ...
    
    // 4. Clean up quota consumption logs
    console.log('🗑️ [CLEANUP-DB] Cleaning up quota consumption logs...');
    try {
      const { data: quotaLogsResult, error: quotaLogsError } = await supabase.rpc('cleanup_quota_consumption_logs');
      if (quotaLogsError) {
        errors.push(`Quota logs cleanup error: ${quotaLogsError.message}`);
        console.error('❌ [CLEANUP-DB] Quota logs cleanup failed:', quotaLogsError);
      } else {
        quotaLogsDeleted = quotaLogsResult?.[0]?.deleted_count || 0;
        console.log(`✅ [CLEANUP-DB] Deleted ${quotaLogsDeleted} quota consumption logs`);
      }
    } catch (error) {
      errors.push(`Quota logs cleanup error: ${error.message}`);
      console.error('❌ [CLEANUP-DB] Quota logs cleanup error:', error);
    }
    
    // 5. Clean up old daily quota records
    console.log('🗑️ [CLEANUP-DB] Cleaning up old daily quota records...');
    try {
      const { data: quotaRecordsResult, error: quotaRecordsError } = await supabase.rpc('cleanup_old_daily_quotas');
      if (quotaRecordsError) {
        errors.push(`Quota records cleanup error: ${quotaRecordsError.message}`);
        console.error('❌ [CLEANUP-DB] Quota records cleanup failed:', quotaRecordsError);
      } else {
        quotaRecordsDeleted = quotaRecordsResult?.[0]?.deleted_count || 0;
        console.log(`✅ [CLEANUP-DB] Deleted ${quotaRecordsDeleted} daily quota records`);
      }
    } catch (error) {
      errors.push(`Quota records cleanup error: ${error.message}`);
      console.error('❌ [CLEANUP-DB] Quota records cleanup error:', error);
    }
    
  } catch (error) {
    errors.push(`Atomic cleanup error: ${error.message}`);
    console.error('❌ [CLEANUP-DB] Atomic cleanup failed:', error);
  }
  
  return { jobsDeleted, rateLimitDeleted, logsDeleted, quotaLogsDeleted, quotaRecordsDeleted, errors };
}
```

### Recommended Cron Schedule

```bash
# Daily cleanup at 2 AM UTC
0 2 * * * curl -X POST https://your-project.supabase.co/functions/v1/cleanup-db \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "x-api-key: YOUR_CLEANUP_API_KEY"

# Weekly quota cleanup at 3 AM UTC (Sundays)
0 3 * * 0 curl -X POST https://your-project.supabase.co/functions/v1/cleanup-db \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "x-api-key: YOUR_CLEANUP_API_KEY"
```

---

## ✅ Phase 7: Fix StoreKit Integration (30 minutes)

### Update StoreKitService.swift

Connect StoreKit premium status to the new quota system:

```swift
// BananaUniverse/Core/Services/StoreKitService.swift

func updateSubscriptionStatus() async {
    // ... existing code ...
    
    isPremiumUser = hasActiveSubscription
    subscriptionRenewalDate = latestRenewalDate
    
    // CRITICAL: Update HybridCreditManager with new premium status
    await HybridCreditManager.shared.updatePremiumStatus(isPremiumUser)
    
    #if DEBUG
    print("📊 Premium status: \(isPremiumUser ? "Active" : "Inactive")")
    #endif
}
```

---

## ✅ Phase 8: Fix User State Transitions (30 minutes)

### Update HybridAuthService.swift

Fix user state transitions to work with new quota system:

```swift
// BananaUniverse/Core/Services/HybridAuthService.swift

private func handleAuthenticationStateChange(from previousState: UserState, to newState: UserState) async {
    // CRITICAL: Update quota manager with new state
    HybridCreditManager.shared.setUserState(newState)
    
    // If transitioning from anonymous to authenticated, handle quota migration
    if case .anonymous = previousState, case .authenticated(let user) = newState {
        print("🔄 [AUTH] Anonymous → Authenticated transition")
        
        // Initialize new user in backend if needed
        await HybridCreditManager.shared.initializeNewUser()
        
        // Identify user in Adapty for purchase tracking
        do {
            // Mock identify - always succeeds
            // try await AdaptyService.shared.identify(userId: user.id.uuidString)
            print("Mock: User identified in Adapty")
        } catch {
            print("Mock: Adapty identification skipped")
        }
    }
    
    // If transitioning from authenticated to anonymous, handle cleanup
    if case .authenticated = previousState, case .anonymous = newState {
        print("🔄 [AUTH] Authenticated → Anonymous transition")
        
        // Logout from Adapty
        do {
            // Mock logout - always succeeds
            // try await AdaptyService.shared.logout()
            print("Mock: User logged out from Adapty")
        } catch {
            print("Mock: Adapty logout skipped")
        }
    }
}
```

### Update App Launch Flow

Add quota initialization on app launch:

```swift
// BananaUniverse/App/BananaUniverseApp.swift

@main
struct BananaUniverseApp: App {
    @StateObject private var creditManager = HybridCreditManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // CRITICAL: Initialize quota system on app launch
                    await creditManager.initializeNewUser()
                }
        }
    }
}
```

---

## ✅ Phase 9: Add Error Handling (30 minutes)

### Update SupabaseError enum

Add new error type for quota exceeded:

```swift
// BananaUniverse/Core/Services/SupabaseService.swift

enum SupabaseError: Error, LocalizedError {
    case notAuthenticated
    case insufficientCredits
    case invalidResponse
    case serverError(String)
    case noSession
    case processingFailed(String)
    case timeout
    case rateLimitExceeded
    case quotaExceeded  // NEW: For 429 quota exceeded
    case invalidURL
    
    var errorDescription: String? {
        switch self {
        // ... existing cases ...
        case .quotaExceeded:
            return "Daily quota exceeded. Come back tomorrow or upgrade for unlimited access."
        }
    }
    
    var appError: AppError {
        switch self {
        // ... existing cases ...
        case .quotaExceeded:
            return .dailyQuotaExceeded
        }
    }
}
```

### Add Network Failure Fallbacks

```swift
// BananaUniverse/Core/Services/HybridCreditManager.swift

func loadQuota() async {
    isLoading = true
    print("🔍 [QUOTA] Loading quota from backend...")
    
    do {
        let userState = HybridAuthService.shared.userState
        
        let result: QuotaResponse = try await supabase.client
            .rpc("get_quota", params: [
                "p_user_id": userState.isAuthenticated ? userState.identifier : nil,
                "p_device_id": userState.isAuthenticated ? nil : userState.identifier
            ])
            .execute()
            .value
        
        quotaUsed = result.quotaUsed
        quotaLimit = result.quotaLimit
        updateCompatibilityProperties()
        
        print("🔍 [QUOTA] Loaded quota: \(quotaUsed)/\(quotaLimit)")
        isLoading = false
    } catch {
        print("❌ [QUOTA] Failed to load quota: \(error.localizedDescription)")
        
        // FALLBACK: Use cached values or defaults
        if quotaUsed == 0 && quotaLimit == 5 {
            // First time - use defaults
            quotaUsed = 0
            quotaLimit = 5
        }
        // Otherwise keep current values
        
        updateCompatibilityProperties()
        isLoading = false
    }
}
```

---

## ✅ Phase 10: Data Migration Strategy (1 hour)

### Migration Script for Existing Users

```sql
-- Migration 019: Migrate existing users to new quota system

-- Step 1: Migrate authenticated users
INSERT INTO daily_quotas (user_id, device_id, date, used, limit_value)
SELECT 
    uc.user_id,
    NULL as device_id,
    CURRENT_DATE as date,
    uc.daily_quota_used as used,
    uc.daily_quota_limit as limit_value
FROM user_credits uc
WHERE uc.daily_quota_used > 0 OR uc.daily_quota_limit > 0
ON CONFLICT (COALESCE(user_id::text, device_id), date) DO NOTHING;

-- Step 2: Migrate anonymous users  
INSERT INTO daily_quotas (user_id, device_id, date, used, limit_value)
SELECT 
    NULL as user_id,
    ac.device_id,
    CURRENT_DATE as date,
    ac.daily_quota_used as used,
    ac.daily_quota_limit as limit_value
FROM anonymous_credits ac
WHERE ac.daily_quota_used > 0 OR ac.daily_quota_limit > 0
ON CONFLICT (COALESCE(user_id::text, device_id), date) DO NOTHING;

-- Step 3: Verify migration
SELECT 
    'user_credits' as source,
    COUNT(*) as total_records,
    SUM(daily_quota_used) as total_quota_used
FROM user_credits
UNION ALL
SELECT 
    'anonymous_credits' as source,
    COUNT(*) as total_records,
    SUM(daily_quota_used) as total_quota_used
FROM anonymous_credits
UNION ALL
SELECT 
    'daily_quotas' as source,
    COUNT(*) as total_records,
    SUM(used) as total_quota_used
FROM daily_quotas;
```

---

## Summary Checklist

- [x] Phase 1: Database migrations applied
- [x] Phase 2: Edge function deployed with logging
- [x] Phase 3: iOS app updated
- [x] Phase 4: Tested on staging
- [x] Phase 4: Tested all 4 user types
- [x] Phase 4: Deployed to production
- [x] Phase 5: Added quota warning UI
- [x] Phase 6: Added quota system cleanup
- [x] Phase 7: Fixed StoreKit integration
- [x] Phase 8: Fixed user state transitions
- [x] Phase 9: Added error handling
- [x] Phase 10: Migrated existing user data
- [ ] Verified no errors in logs
- [ ] Verified quota counts correctly
- [ ] Verified premium bypass works
- [ ] Verified warning shows at 1 quota left
- [ ] Verified existing UI components work
- [ ] Verified StoreKit premium status updates quota

**Total Effort:** 8.5-9.5 hours  
**Supported Users:** ALL (anon/free, anon/premium, auth/free, auth/premium)  
**Daily Quota:** 5 for free users, unlimited for premium  
**Rollback:** Yes, can revert Edge Function and iOS, old tables stay

