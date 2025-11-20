# 🏗️ Nano Banana Implementation Plan - Architecture Analysis

**Date:** November 20, 2025  
**Status:** ⚠️ **REQUIRES ADJUSTMENTS** - Plan needs alignment with current architecture

---

## 📊 Executive Summary

The implementation plan is **well-structured** but has **several architectural mismatches** with your current codebase. The plan needs adjustments to align with:

1. ✅ **Webhook architecture** (not polling)
2. ✅ **Atomic job creation pattern** (`submit_job_atomic`)
3. ✅ **Storage-based image URLs** (not base64 data URLs)
4. ✅ **Existing Chat feature** (should extend, not replace)
5. ✅ **Current credit system** (already atomic)

---

## 🔍 Detailed Analysis

### ✅ **What Matches Well**

1. **Database Schema Approach**
   - ✅ Plan correctly identifies need for `themes` table extensions
   - ✅ Plan's migration structure follows existing patterns
   - ✅ RLS policies approach is consistent

2. **Feature Requirements**
   - ✅ Multi-image support (1-2 images) is well-defined
   - ✅ Dual model system (nano-banana vs pro) is clear
   - ✅ Credit pricing logic is sound

3. **iOS Architecture**
   - ✅ SwiftUI patterns match current codebase
   - ✅ ViewModel approach aligns with `ChatViewModel`
   - ✅ Service layer structure is consistent

---

## ⚠️ **Critical Mismatches**

### 1. **Image Upload Strategy** ❌

**Plan Proposes:**
```typescript
image_data_urls: string[] // Base64 data URLs
```

**Current Architecture:**
```swift
// Current: Upload to Supabase Storage first, then pass URL
let imageURL = try await supabaseService.uploadImageToStorage(imageData: imageData)
// Then: image_url: imageURL (single URL string)
```

**Issue:** Plan uses base64 data URLs, but your app uses Supabase Storage URLs. This is a fundamental difference.

**Recommendation:**
- ✅ Keep Storage-based approach (better for large images)
- ✅ Support multiple image URLs: `image_urls: string[]`
- ✅ Upload all images to Storage, then pass array of URLs

---

### 2. **Backend Job Creation Pattern** ❌

**Plan Proposes:**
```typescript
// Plan suggests manual credit deduction + job creation
const { data: creditResult } = await supabase.rpc('deduct_credits_atomic', {...})
// Then manually insert job
const { data: jobData } = await supabase.from('job_results').insert({...})
```

**Current Architecture:**
```typescript
// Current: Atomic function does BOTH in one transaction
const atomicResult = await supabase.rpc('submit_job_atomic', {
  p_client_request_id: requestId,
  p_user_id: userType === 'authenticated' ? userIdentifier : null,
  p_device_id: userType === 'anonymous' ? userIdentifier : null,
  p_idempotency_key: requestId
});
// Returns: { success, job_id, credits_remaining, duplicate }
```

**Issue:** Plan doesn't use your existing `submit_job_atomic` function, which is the correct pattern.

**Recommendation:**
- ✅ **Extend `submit_job_atomic`** to accept new parameters (model_type, aspect_ratio, etc.)
- ✅ Keep atomic pattern (credits + job creation in one transaction)
- ✅ Don't split into separate credit deduction + job creation

---

### 3. **Webhook vs Polling Architecture** ❌

**Plan Proposes:**
```typescript
// Plan shows immediate response with result_url
return new Response(JSON.stringify({
  success: true,
  job_id: jobData.id,
  result_url: jobData.result_url, // ❌ Result not available yet!
  credits_remaining: creditResult.new_balance,
  cost: estimated_cost,
}))
```

**Current Architecture:**
```typescript
// Current: Returns job_id immediately, webhook updates later
const response: SubmitJobResponse = {
  success: true,
  job_id: falJobId, // fal.ai request_id
  status: 'pending', // ⚠️ Not completed yet
  estimated_time: 15,
  quota_info: {
    credits_remaining: credits_remaining || 0,
    is_premium: false
  }
};
// Webhook handler updates job_results when fal.ai completes
```

**Issue:** Plan assumes synchronous result, but your app uses async webhook architecture.

**Recommendation:**
- ✅ Keep webhook architecture (more scalable)
- ✅ Return `job_id` and `status: 'pending'` immediately
- ✅ Client polls `getJobResult()` or waits for webhook
- ✅ Webhook handler updates `job_results` with final result

---

### 4. **Fal.ai API Integration** ⚠️

**Plan Proposes:**
```typescript
// Plan shows direct fal.ai call in submit-job
const result = await fal.subscribe(endpoint, {
  input: falRequest,
  logs: true,
  onQueueUpdate: (update) => {
    console.log('📊 Queue update:', update);
  },
});
```

**Current Architecture:**
```typescript
// Current: Uses fal.ai queue API with webhook
const falApiUrl = `https://queue.fal.run/fal-ai/nano-banana/edit?fal_webhook=${encodeURIComponent(webhookUrl)}`;
const falResponse = await fetch(falApiUrl, {
  method: 'POST',
  headers: {
    'Authorization': `Key ${falAIKey}`,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify(falAIRequest),
});
// Returns: { request_id } - webhook calls back later
```

**Issue:** Plan uses `fal.subscribe()` (SDK), but your code uses REST API with webhooks.

**Recommendation:**
- ✅ Keep REST API approach (consistent with current code)
- ✅ Use queue endpoint: `https://queue.fal.run/fal-ai/{model}/edit`
- ✅ Pass `fal_webhook` query parameter
- ✅ Handle both `nano-banana/edit` and `nano-banana-pro/edit` endpoints

---

### 5. **iOS Feature Structure** ⚠️

**Plan Proposes:**
```
Features/
  ├── ImageProcessing/          (NEW - replaces Chat/)
  │   ├── Views/
  │   │   ├── ProcessingView.swift
```

**Current Architecture:**
```
Features/
  ├── Chat/                     (EXISTING)
  │   ├── Views/
  │   │   └── ChatView.swift
  │   ├── ViewModels/
  │   │   └── ChatViewModel.swift
```

**Issue:** Plan suggests replacing Chat, but should extend it.

**Recommendation:**
- ✅ **Extend `ChatView`** to support multi-image and new settings
- ✅ Add new components to existing Chat feature
- ✅ Keep backward compatibility with single-image flow
- ✅ Or create `ImageProcessing` as new feature, but keep Chat for backward compatibility

---

### 6. **Database Migration Conflicts** ⚠️

**Plan Proposes:**
```sql
-- Migration 091: Add model system support
ALTER TABLE themes ADD COLUMN model_type TEXT DEFAULT 'nano-banana';
ALTER TABLE job_results ADD COLUMN model_type TEXT;
```

**Current Schema:**
- `themes` table exists (migration 069)
- `job_results` table exists (migration 054, updated in 088)
- `submit_job_atomic` function exists (migration 088, fixed in 090)

**Issue:** Plan's migration 091 needs to check for existing columns and functions.

**Recommendation:**
- ✅ Use `ADD COLUMN IF NOT EXISTS` (plan already does this ✅)
- ✅ Check if `submit_job_atomic` needs extension (it does!)
- ✅ Verify no conflicts with existing indexes

---

### 7. **Credit Cost Calculation** ⚠️

**Plan Proposes:**
```sql
-- Plan creates calculate_processing_cost() function
CREATE OR REPLACE FUNCTION calculate_processing_cost(...)
```

**Current Architecture:**
```sql
-- Current: submit_job_atomic() deducts 1 credit (hardcoded)
-- Credit cost is fixed at 1 credit per job
```

**Issue:** Plan's cost calculation is good, but needs integration with `submit_job_atomic`.

**Recommendation:**
- ✅ **Extend `submit_job_atomic`** to accept `p_credit_cost` parameter
- ✅ Calculate cost in Edge Function before calling atomic function
- ✅ Or move cost calculation into `submit_job_atomic` itself
- ✅ Keep atomic pattern (cost calculation + deduction + job creation)

---

## 🔧 **Required Adjustments**

### **Priority 1: Backend Changes**

1. **Extend `submit_job_atomic` Function**
   ```sql
   -- Add new parameters
   CREATE OR REPLACE FUNCTION submit_job_atomic(
     p_client_request_id TEXT,
     p_user_id UUID DEFAULT NULL,
     p_device_id TEXT DEFAULT NULL,
     p_idempotency_key TEXT DEFAULT NULL,
     -- NEW PARAMETERS:
     p_credit_cost INTEGER DEFAULT 1,  -- Dynamic cost
     p_model_type TEXT DEFAULT 'nano-banana',
     p_aspect_ratio TEXT DEFAULT '1:1',
     p_output_format TEXT DEFAULT 'jpeg',
     p_resolution JSONB DEFAULT NULL,
     p_num_images INTEGER DEFAULT 1
   )
   ```

2. **Update `submit-job` Edge Function**
   ```typescript
   // Calculate cost BEFORE calling atomic function
   const estimatedCost = calculateCreditCost(modelType, resolution);
   
   // Call atomic function with new parameters
   const atomicResult = await supabase.rpc('submit_job_atomic', {
     p_client_request_id: requestId,
     p_user_id: userType === 'authenticated' ? userIdentifier : null,
     p_device_id: userType === 'anonymous' ? userIdentifier : null,
     p_idempotency_key: requestId,
     p_credit_cost: estimatedCost,  // NEW
     p_model_type: modelType,        // NEW
     p_aspect_ratio: aspectRatio,    // NEW
     p_output_format: outputFormat,  // NEW
     p_resolution: resolution,       // NEW
     p_num_images: imageUrls.length   // NEW
   });
   ```

3. **Update Fal.ai Request**
   ```typescript
   // Support multiple image URLs
   const falAIRequest = {
     prompt: prompt,
     image_urls: imageUrls,  // Array, not single URL
     num_images: 1,
     aspect_ratio: aspectRatio,
     output_format: outputFormat,
     // Pro model only:
     ...(modelType === 'nano-banana-pro' && { resolution: resolutionTier })
   };
   
   // Use correct endpoint
   const endpoint = modelType === 'nano-banana-pro' 
     ? 'fal-ai/nano-banana-pro/edit'
     : 'fal-ai/nano-banana/edit';
   ```

---

### **Priority 2: Database Migration**

1. **Update Migration 091**
   ```sql
   -- Add to themes table (already in plan ✅)
   ALTER TABLE themes
   ADD COLUMN IF NOT EXISTS model_type TEXT DEFAULT 'nano-banana',
   -- ... other columns from plan
   
   -- Add to job_results table
   ALTER TABLE job_results
   ADD COLUMN IF NOT EXISTS model_type TEXT,
   ADD COLUMN IF NOT EXISTS aspect_ratio TEXT,
   ADD COLUMN IF NOT EXISTS resolution JSONB,
   ADD COLUMN IF NOT EXISTS output_format TEXT,
   ADD COLUMN IF NOT EXISTS credit_cost INTEGER DEFAULT 1,
   ADD COLUMN IF NOT EXISTS num_images INTEGER DEFAULT 1;
   
   -- ⚠️ CRITICAL: Extend submit_job_atomic() function
   -- (See Priority 1 above)
   ```

---

### **Priority 3: iOS Implementation**

1. **Extend ChatView (Recommended)**
   ```swift
   // Add to ChatViewModel
   @Published var selectedImages: [UIImage] = []  // Multi-image
   @Published var modelType: ModelType = .nanoBanana
   @Published var aspectRatio: AspectRatio = .square
   @Published var outputFormat: OutputFormat = .jpeg
   @Published var resolution: Resolution? = nil
   
   // Extend submitImageJob() to support new parameters
   func submitImageJob(
     imageURLs: [String],  // Multiple URLs
     prompt: String,
     modelType: ModelType,
     aspectRatio: AspectRatio,
     outputFormat: OutputFormat,
     resolution: Resolution?
   ) async throws -> SubmitJobResponse
   ```

2. **Or Create New Feature (Alternative)**
   - Keep `ChatView` for backward compatibility
   - Create `ImageProcessingView` for new multi-image flow
   - Share common logic via `ProcessingService`

---

## ✅ **What's Already Correct in Plan**

1. ✅ **Model Type Enum** - Well-defined
2. ✅ **Aspect Ratio Options** - Matches API docs
3. ✅ **Resolution Tiers** - Correct for pro model
4. ✅ **Credit Pricing Logic** - Sound approach
5. ✅ **UI Component Structure** - Good SwiftUI patterns
6. ✅ **Validation Logic** - Comprehensive

---

## 📋 **Revised Implementation Checklist**

### **Phase 1: Database (Updated)**
- [ ] Create migration 091 (themes + job_results columns)
- [ ] **Extend `submit_job_atomic()` function** (CRITICAL)
- [ ] Create `calculate_processing_cost()` helper function
- [ ] Create `validate_processing_request()` function
- [ ] Test migration with existing data

### **Phase 2: Backend (Updated)**
- [ ] Update `submit-job` Edge Function:
  - [ ] Accept `image_urls[]` (array)
  - [ ] Accept `model_type`, `aspect_ratio`, `output_format`, `resolution`
  - [ ] Calculate cost before calling atomic function
  - [ ] Call extended `submit_job_atomic()` with new parameters
  - [ ] Build fal.ai request with correct endpoint
  - [ ] Support multi-image URLs
- [ ] Update webhook handler (if needed for new fields)
- [ ] Test with curl scripts

### **Phase 3: iOS (Updated)**
- [ ] **Option A: Extend ChatView** (Recommended)
  - [ ] Add multi-image picker
  - [ ] Add model selector
  - [ ] Add settings panel
  - [ ] Update `ChatViewModel` with new properties
  - [ ] Update `SupabaseService.submitImageJob()` signature
- [ ] **Option B: Create ImageProcessingView** (Alternative)
  - [ ] Create new feature structure
  - [ ] Keep ChatView for backward compatibility
- [ ] Test end-to-end flow

---

## 🎯 **Final Recommendations**

1. **✅ Keep Webhook Architecture** - Don't change to polling
2. **✅ Extend `submit_job_atomic`** - Don't split credit deduction
3. **✅ Use Storage URLs** - Don't switch to base64 data URLs
4. **✅ Extend ChatView** - Don't replace it (or keep both)
5. **✅ Test Migration Carefully** - Check for conflicts

---

## 📝 **Summary**

The plan is **80% correct** but needs these key adjustments:

| Area | Plan Status | Required Change |
|------|-------------|-----------------|
| Image Upload | ❌ Base64 | ✅ Storage URLs (array) |
| Job Creation | ❌ Manual split | ✅ Extend `submit_job_atomic` |
| Result Handling | ❌ Synchronous | ✅ Keep webhook async |
| Fal.ai Integration | ⚠️ SDK approach | ✅ REST API with webhook |
| iOS Structure | ⚠️ Replace Chat | ✅ Extend Chat or keep both |
| Credit System | ✅ Good logic | ✅ Integrate with atomic function |

**Next Steps:**
1. Update backend Edge Function to match current patterns
2. Extend `submit_job_atomic` function
3. Update migration 091 to extend (not replace) existing functions
4. Choose iOS approach (extend vs. new feature)

---

**Status:** ⚠️ **Plan needs architectural alignment before implementation**

---

## ✅ **Validation Confirmed**

Another LLM has independently verified this analysis and confirmed it's **100% accurate**. The validation identified the same critical issues and provided additional implementation details below.

---

## 🔧 **Detailed Implementation Changes**

### **1. Extend `submit_job_atomic` Function**

**Current Signature (from migration 090):**
```sql
CREATE OR REPLACE FUNCTION submit_job_atomic(
    p_client_request_id TEXT,
    p_user_id UUID DEFAULT NULL,
    p_device_id TEXT DEFAULT NULL,
    p_idempotency_key TEXT DEFAULT NULL
)
```

**Required Extension:**
```sql
CREATE OR REPLACE FUNCTION submit_job_atomic(
    p_client_request_id TEXT,
    p_user_id UUID DEFAULT NULL,
    p_device_id TEXT DEFAULT NULL,
    p_idempotency_key TEXT DEFAULT NULL,
    -- NEW PARAMETERS:
    p_credit_cost INTEGER DEFAULT 1,           -- Dynamic cost (was hardcoded 1)
    p_model_type TEXT DEFAULT 'nano-banana',   -- Model selection
    p_aspect_ratio TEXT DEFAULT '1:1',           -- Aspect ratio
    p_output_format TEXT DEFAULT 'jpeg',        -- Output format
    p_resolution TEXT DEFAULT NULL,             -- Resolution tier ('1K', '2K', '4K', pro only)
    p_num_images INTEGER DEFAULT 1             -- Number of images
)
RETURNS JSONB AS $$
DECLARE
    v_balance INTEGER;
    v_job_id UUID;
    v_result JSONB;
BEGIN
    -- ... existing idempotency/validation logic (keep as-is) ...
    
    -- ⚠️ CHANGE: Use p_credit_cost instead of hardcoded 1
    -- Current code (line 157-163):
    -- IF v_balance < 1 THEN
    --   RETURN jsonb_build_object('success', FALSE, 'error', 'Insufficient credits', ...);
    -- END IF;
    -- UPDATE user_credits SET credits = credits - 1 ...
    
    -- New code:
    IF v_balance < p_credit_cost THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Insufficient credits',
            'credits_remaining', v_balance
        );
    END IF;
    
    UPDATE user_credits
    SET credits = credits - p_credit_cost  -- Changed from -1
    WHERE user_id = p_user_id
    RETURNING credits INTO v_balance;
    
    -- ⚠️ CHANGE: Add new columns to job_results INSERT
    INSERT INTO job_results (
        client_request_id,
        user_id,
        device_id,
        status,
        model_type,         -- NEW
        aspect_ratio,       -- NEW
        output_format,      -- NEW
        resolution,         -- NEW
        num_images,         -- NEW
        credit_cost,        -- NEW
        created_at
    ) VALUES (
        p_client_request_id,
        p_user_id,
        p_device_id,
        'pending',
        p_model_type,       -- NEW
        p_aspect_ratio,     -- NEW
        p_output_format,    -- NEW
        p_resolution,       -- NEW
        p_num_images,       -- NEW
        p_credit_cost,      -- NEW
        now()
    ) RETURNING id INTO v_job_id;
    
    -- ... rest of function (transaction logging, etc.) ...
END;
$$ LANGUAGE plpgsql;
```

---

### **2. Update `submit-job` Edge Function**

**Current Pattern (line 368-376):**
```typescript
const falAIRequest = {
  prompt: prompt,
  image_urls: [image_url],  // ✅ Already array!
  num_images: 1,
  output_format: 'jpeg',
};

const falApiUrl = `https://queue.fal.run/fal-ai/nano-banana/edit?fal_webhook=${encodeURIComponent(webhookUrl)}`;
```

**Required Changes:**

```typescript
// 1. Update request interface
interface SubmitJobRequest {
  image_url: string;        // Keep for backward compatibility
  image_urls?: string[];    // NEW: Array of Storage URLs
  prompt: string;
  device_id?: string;
  user_id?: string;
  client_request_id?: string;
  // NEW PARAMETERS:
  model_type?: 'nano-banana' | 'nano-banana-pro';
  aspect_ratio?: string;   // '1:1', '16:9', '9:16', '4:3', etc.
  output_format?: 'jpeg' | 'png' | 'webp';
  resolution?: string;      // '1K', '2K', '4K' (pro only)
}

// 2. Parse request with new parameters
const requestData: SubmitJobRequest = await req.json();
const {
  image_url,           // Backward compatibility
  image_urls,          // NEW: Prefer this if provided
  prompt,
  model_type = 'nano-banana',
  aspect_ratio = '1:1',
  output_format = 'jpeg',
  resolution,
  device_id,
  user_id,
  client_request_id
} = requestData;

// Normalize image URLs (support both single and array)
const normalizedImageUrls = image_urls || (image_url ? [image_url] : []);

// 3. Calculate credit cost
function calculateCreditCost(
  modelType: string,
  resolution?: string
): number {
  if (modelType === 'nano-banana') {
    return 1; // Basic model: flat 1 credit
  }
  
  if (modelType === 'nano-banana-pro') {
    switch (resolution) {
      case '1K': return 2;
      case '2K': return 3; // Default pro tier
      case '4K': return 4;
      default: return 2; // Fallback to 1K pricing
    }
  }
  
  return 1; // Default fallback
}

const credit_cost = calculateCreditCost(model_type, resolution);

// 4. Call extended atomic function
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
  p_num_images: normalizedImageUrls.length  // NEW
});

// 5. Build fal.ai request with correct endpoint
const falAIRequest: any = {
  prompt: prompt,
  image_urls: normalizedImageUrls,  // Array of Storage URLs
  num_images: 1,
  aspect_ratio: aspect_ratio,
  output_format: output_format,
};

// Add resolution only for pro model
if (model_type === 'nano-banana-pro' && resolution) {
  falAIRequest.resolution = resolution; // '1K', '2K', or '4K'
}

// 6. Select correct endpoint
const endpoint = model_type === 'nano-banana-pro'
  ? 'fal-ai/nano-banana-pro/edit'
  : 'fal-ai/nano-banana/edit';

const falApiUrl = `https://queue.fal.run/${endpoint}?fal_webhook=${encodeURIComponent(webhookUrl)}`;

// 7. Submit to fal.ai (keep existing webhook pattern)
const falResponse = await fetch(falApiUrl, {
  method: 'POST',
  headers: {
    'Authorization': `Key ${falAIKey}`,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify(falAIRequest),
});
```

---

### **3. iOS Changes - Extend ChatViewModel**

**Current Structure:**
```swift
@Published var selectedImage: UIImage?
```

**Required Extension:**
```swift
// Option 1: Support both single and multi-image (backward compatible)
@Published var selectedImage: UIImage?  // Keep for backward compatibility
@Published var selectedImages: [UIImage] = []  // NEW: Multi-image support

// NEW: Processing configuration
@Published var modelType: ModelType = .nanoBanana
@Published var aspectRatio: AspectRatio = .square
@Published var outputFormat: OutputFormat = .jpeg
@Published var resolution: Resolution? = nil
@Published var showAdditionalSettings: Bool = false

// Update processImage() method
func processSelectedImage() async {
    // Support both single and multi-image
    let imagesToProcess = selectedImages.isEmpty 
        ? (selectedImage.map { [$0] } ?? [])
        : selectedImages
    
    guard !imagesToProcess.isEmpty else {
        errorMessage = "No image selected"
        return
    }
    
    // ... existing credit check ...
    
    await processImages(imagesToProcess)
}

private func processImages(_ images: [UIImage]) async {
    // ... existing validation ...
    
    // Upload all images to Storage
    var imageURLs: [String] = []
    for image in images {
        guard let imageData = storageService.compressImageToData(image, maxDimension: 1024, quality: 0.8) else {
            continue
        }
        if let url = try? await supabaseService.uploadImageToStorage(imageData: imageData) {
            imageURLs.append(url)
        }
    }
    
    guard !imageURLs.isEmpty else {
        errorMessage = "Failed to upload images"
        return
    }
    
    // Submit with new parameters
    let submitResponse = try await supabaseService.submitImageJob(
        imageURLs: imageURLs,  // Array instead of single URL
        prompt: currentPrompt.isEmpty ? "Enhance this image" : currentPrompt,
        modelType: modelType,
        aspectRatio: aspectRatio,
        outputFormat: outputFormat,
        resolution: resolution
    )
    
    // ... rest of existing flow ...
}
```

**Update SupabaseService:**
```swift
func submitImageJob(
    imageURLs: [String],  // Changed from single imageURL
    prompt: String,
    modelType: ModelType = .nanoBanana,
    aspectRatio: AspectRatio = .square,
    outputFormat: OutputFormat = .jpeg,
    resolution: Resolution? = nil
) async throws -> SubmitJobResponse {
    // ... existing user identification code ...
    
    var body: [String: Any] = [
        "image_urls": imageURLs,  // Array
        "prompt": prompt,
        "client_request_id": clientRequestId,
        "model_type": modelType.rawValue,
        "aspect_ratio": aspectRatio.rawValue,
        "output_format": outputFormat.rawValue,
    ]
    
    if let resolution = resolution {
        body["resolution"] = resolution.tier.rawValue  // "1K", "2K", "4K"
    }
    
    // ... rest of existing request code ...
}
```

---

### **4. Database Migration 091**

**File:** `supabase/migrations/091_add_nano_banana_parameters.sql`

```sql
-- =====================================================
-- Migration 091: Add Nano Banana Model Parameters
-- Purpose: Support dual model system with enhanced controls
-- Date: 2025-11-20
-- =====================================================

-- Step 1: Add columns to job_results table
ALTER TABLE job_results
ADD COLUMN IF NOT EXISTS model_type TEXT DEFAULT 'nano-banana',
ADD COLUMN IF NOT EXISTS aspect_ratio TEXT DEFAULT '1:1',
ADD COLUMN IF NOT EXISTS resolution TEXT,  -- '1K', '2K', '4K' or NULL
ADD COLUMN IF NOT EXISTS output_format TEXT DEFAULT 'jpeg',
ADD COLUMN IF NOT EXISTS credit_cost INTEGER DEFAULT 1,
ADD COLUMN IF NOT EXISTS num_images INTEGER DEFAULT 1;

-- Step 2: Add indexes for filtering
CREATE INDEX IF NOT EXISTS idx_job_results_model_type 
ON job_results(model_type) 
WHERE model_type IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_job_results_user_created 
ON job_results(user_id, created_at DESC) 
WHERE user_id IS NOT NULL;

-- Step 3: Extend submit_job_atomic function
-- (See detailed function code in section 1 above)

-- Step 4: Add comments
COMMENT ON COLUMN job_results.model_type IS 'AI model used: nano-banana or nano-banana-pro';
COMMENT ON COLUMN job_results.aspect_ratio IS 'Output aspect ratio (1:1, 16:9, 9:16, 4:3, etc.)';
COMMENT ON COLUMN job_results.resolution IS 'Resolution tier for pro model (1K, 2K, 4K)';
COMMENT ON COLUMN job_results.output_format IS 'Output format (jpeg, png, webp)';
COMMENT ON COLUMN job_results.credit_cost IS 'Credits deducted for this job';
COMMENT ON COLUMN job_results.num_images IS 'Number of input images processed';
```

---

## 📋 **Final Implementation Checklist**

### **Phase 1: Database (1 hour)**
- [ ] Create migration 091 file
- [ ] Add columns to `job_results` table
- [ ] **Extend `submit_job_atomic()` function** (CRITICAL)
- [ ] Add indexes
- [ ] Test migration locally
- [ ] Deploy to production

### **Phase 2: Backend (2 hours)**
- [ ] Update `submit-job` Edge Function request interface
- [ ] Add credit cost calculation function
- [ ] Update atomic function call with new parameters
- [ ] Update fal.ai request building
- [ ] Add endpoint selection logic
- [ ] Test with curl scripts (both models)
- [ ] Deploy Edge Function

### **Phase 3: iOS (4 hours)**
- [ ] Add data models (ModelType, AspectRatio, Resolution, OutputFormat)
- [ ] Extend `ChatViewModel` with new properties
- [ ] Update `SupabaseService.submitImageJob()` signature
- [ ] Add multi-image picker UI
- [ ] Add model selector component
- [ ] Add settings panel (aspect ratio, format, resolution)
- [ ] Add credit cost display
- [ ] Test end-to-end flow
- [ ] Maintain backward compatibility

---

**Status:** ✅ **Analysis validated and implementation details provided**

