# Nano Banana Implementation Plan
**Project:** BananaUniverse Enhanced Processing System
**Date:** November 20, 2025
**Status:** Planning Phase - Awaiting API Documentation

---

## 📋 Overview

This document outlines the complete implementation plan for adding dual model support (nano-banana & nano-banana-pro) with enhanced image processing controls including multi-image upload, aspect ratio selection, resolution control, and output format options.

---

## 🎯 Project Goals

1. **Enhanced ChatView Transformation**
   - Multi-image upload (1-2 images)
   - Model selection interface
   - Collapsible "Additional Settings" section
   - Real-time credit cost display
   - Improved UX with modern controls

2. **Dual Model System**
   - `nano-banana`: Standard model with basic controls
   - `nano-banana-pro`: Advanced model with full resolution control

3. **Credit Cost Transparency**
   - Display estimated cost before processing
   - Dynamic cost calculation based on:
     - Model type (nano-banana vs pro)
     - Resolution settings (for pro)
     - Number of images

4. **Flexible Processing Options**
   - User-selectable aspect ratios
   - User-selectable output formats
   - User-selectable resolutions (pro only)

---

## 📊 Requirements Specification

### User Flow
```
Home Screen (Theme Selection)
    ↓
Enhanced Processing View
    ├── Step 1: Upload Images (1-2 images)
    ├── Step 2: Select Model (nano-banana / nano-banana-pro)
    ├── Step 3: Enter Prompt
    └── Step 4: Additional Settings (toggle)
        ├── Aspect Ratio: 1:1, 16:9, 9:16, 4:3
        ├── Output Format: JPEG, PNG, WEBP
        └── Resolution: [Only for nano-banana-pro]
            └── Options: 512x512, 768x768, 1024x1024, etc.
    ↓
Credit Cost Display ("This will cost X credits")
    ↓
Process Button (with current balance)
    ↓
Processing State (loading indicator)
    ↓
Result View
    ├── Processed Image(s)
    ├── Download/Share Actions
    ├── View Details
    └── Actions: Process Another / Go Home
```

### Feature Comparison Matrix

| Feature                | nano-banana | nano-banana-pro |
|------------------------|-------------|-----------------|
| **Max Images**         | 1-2         | 1-2            |
| **Aspect Ratio**       | ✅ Yes      | ✅ Yes         |
| **Output Format**      | ✅ Yes      | ✅ Yes         |
| **Resolution Control** | ❌ Fixed    | ✅ User Choice |
| **Credit Cost**        | 1 credit    | 2-3 credits    |
| **Use Case**           | Quick edits | Professional   |

---

## 🔧 API Integration Analysis

> **✅ UPDATED: API Documentation Received for fal-ai/nano-banana/edit**

### Model Information

#### 1️⃣ fal-ai/nano-banana/edit (Basic Model)
**Endpoint:** `fal-ai/nano-banana/edit`
**Purpose:** Multi-image editing with aspect ratio control
**Status:** ✅ Documented

**Request Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `prompt` | string | ✅ Yes | - | The prompt for image editing |
| `image_urls` | string[] | ✅ Yes | - | URLs of images (max 2 in examples) |
| `num_images` | integer | ❌ No | 1 | Number of images to generate |
| `aspect_ratio` | enum | ❌ No | "auto" | Output aspect ratio |
| `output_format` | enum | ❌ No | "png" | Output format (jpeg, png, webp) |
| `sync_mode` | boolean | ❌ No | false | Return as data URI |
| `limit_generations` | boolean | ❌ No | false | Limit to 1 generation |

**Aspect Ratio Options:**
```
auto, 21:9, 16:9, 3:2, 4:3, 5:4, 1:1, 4:5, 3:4, 2:3, 9:16
```

**Output Format Options:**
```
jpeg, png, webp
```

**Response Structure:**
```json
{
  "images": [
    {
      "url": "https://...",
      "content_type": "image/png",
      "file_name": "nano-banana-multi-edit-output.png",
      "file_size": 123456,
      "width": 1024,
      "height": 1024
    }
  ],
  "description": "Generated image description"
}
```

**Example Request:**
```typescript
const result = await fal.subscribe(
  "fal-ai/nano-banana/edit",
  {
    input: {
      prompt: "make a photo of the man driving the car",
      image_urls: [
        "https://example.com/image1.png",
        "https://example.com/image2.png"
      ],
      aspect_ratio: "16:9",
      output_format: "png",
      num_images: 1
    }
  }
);
```

---

#### 2️⃣ fal-ai/nano-banana-pro/edit (Pro Model)
**Endpoint:** `fal-ai/nano-banana-pro/edit`
**Purpose:** Professional multi-image editing with resolution control
**Status:** ✅ Documented
**Key Difference:** ⭐ **Has `resolution` parameter (1K, 2K, 4K)** ⭐

**Request Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `prompt` | string | ✅ Yes | - | The prompt for image editing |
| `image_urls` | string[] | ✅ Yes | - | URLs of images (max 2 in examples) |
| `num_images` | integer | ❌ No | 1 | Number of images to generate |
| `aspect_ratio` | enum | ❌ No | "auto" | Output aspect ratio |
| `output_format` | enum | ❌ No | "png" | Output format (jpeg, png, webp) |
| `sync_mode` | boolean | ❌ No | false | Return as data URI |
| **`resolution`** | **enum** | ❌ No | **"1K"** | **Resolution tier (1K, 2K, 4K)** ⭐ |

**Aspect Ratio Options:**
```
auto, 21:9, 16:9, 3:2, 4:3, 5:4, 1:1, 4:5, 3:4, 2:3, 9:16
```

**Output Format Options:**
```
jpeg, png, webp
```

**Resolution Options:** ⭐ **NEW in Pro Model**
```
1K, 2K, 4K
```

**Response Structure:**
```json
{
  "images": [
    {
      "url": "https://...",
      "content_type": "image/png",
      "file_name": "nano-banana-multi-edit-output.png",
      "file_size": 123456,
      "width": 2048,  // Higher resolution for 2K/4K
      "height": 2048
    }
  ],
  "description": "Generated image description"
}
```

**Example Request:**
```typescript
const result = await fal.subscribe(
  "fal-ai/nano-banana-pro/edit",
  {
    input: {
      prompt: "make a photo of the man driving the car",
      image_urls: [
        "https://example.com/image1.png",
        "https://example.com/image2.png"
      ],
      aspect_ratio: "16:9",
      output_format: "png",
      resolution: "2K",  // ⭐ Pro-exclusive parameter
      num_images: 1
    }
  }
);
```

---

### 🆚 Model Comparison

| Feature | nano-banana/edit | nano-banana-pro/edit | Notes |
|---------|------------------|----------------------|-------|
| **Endpoint** | `fal-ai/nano-banana/edit` | `fal-ai/nano-banana-pro/edit` | Different models |
| **Multi-Image** | ✅ Yes (2 images) | ✅ Yes (2 images) | Same |
| **Aspect Ratio** | ✅ 11 options | ✅ 11 options | Same |
| **Output Format** | ✅ 3 formats | ✅ 3 formats | Same |
| **Resolution Control** | ❌ No | ✅ **Yes (1K/2K/4K)** | ⭐ **Pro exclusive** |
| **Image Quality** | Standard | Higher (with 2K/4K) | Pro advantage |
| **Processing Time** | Faster | Slower (higher res) | Trade-off |
| **Suggested Credit Cost** | 1 credit | 2-4 credits (by resolution) | Pricing model |

---

### ✅ Key Findings

1. ✅ **Two distinct models confirmed**: Basic and Pro with different endpoints
2. ✅ **Resolution control available**: Pro model has 1K/2K/4K options
3. ✅ **Multi-image support**: Both models support up to 2 images
4. ✅ **Same aspect ratios**: Both have 11 aspect ratio options
5. ✅ **Same output formats**: Both support jpeg, png, webp
6. ✅ **Clear differentiation**: Pro model justified by resolution tiers

---

### 💡 Recommended Implementation Strategy

**✅ APPROVED STRATEGY: Dual Model System with Resolution Tiers**

```
┌─────────────────────────────────────────────────────────────┐
│ BASIC MODEL: fal-ai/nano-banana/edit                        │
├─────────────────────────────────────────────────────────────┤
│ Credit Cost: 1 credit (flat rate)                           │
│ Max Images: 1-2 images                                      │
│ Aspect Ratios: All 11 options (auto, 1:1, 16:9, etc.)      │
│ Output Formats: jpeg, png, webp                            │
│ Resolution: Auto (no user control)                          │
│ Use Case: Quick edits, standard quality                     │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ PRO MODEL: fal-ai/nano-banana-pro/edit                      │
├─────────────────────────────────────────────────────────────┤
│ Credit Cost:                                                │
│   • 1K Resolution: 2 credits                                │
│   • 2K Resolution: 3 credits  ⭐ RECOMMENDED DEFAULT        │
│   • 4K Resolution: 4 credits                                │
│ Max Images: 1-2 images                                      │
│ Aspect Ratios: All 11 options (auto, 1:1, 16:9, etc.)      │
│ Output Formats: jpeg, png, webp                            │
│ Resolution: User-selectable (1K/2K/4K)                      │
│ Use Case: Professional quality, high-res outputs            │
└─────────────────────────────────────────────────────────────┘
```

---

### 🎯 API Parameter Mapping (Finalized)

| UI Parameter | Basic Model | Pro Model | Valid Values | Notes |
|--------------|-------------|-----------|--------------|-------|
| **Model Type** | `fal-ai/nano-banana/edit` | `fal-ai/nano-banana-pro/edit` | N/A | Different endpoints |
| **Images (1-2)** | `image_urls` | `image_urls` | string[] | Same parameter |
| **Prompt** | `prompt` | `prompt` | string | Same parameter |
| **Aspect Ratio** | `aspect_ratio` | `aspect_ratio` | auto, 21:9, 16:9, 3:2, 4:3, 5:4, 1:1, 4:5, 3:4, 2:3, 9:16 | Same parameter |
| **Output Format** | `output_format` | `output_format` | jpeg, png, webp | Same parameter |
| **Resolution** | ❌ Not available | `resolution` | 1K, 2K, 4K | ⭐ **Pro exclusive** |
| **Num Images** | `num_images` | `num_images` | integer (default: 1) | Same parameter |

---

### 📊 Credit Pricing Logic

```typescript
function calculateCreditCost(modelType: ModelType, resolution?: Resolution): number {
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

  return 1; // Default fallback
}
```

---

### 🎨 UI Flow (Finalized)

```
User selects theme on Home
    ↓
Processing View Opens
    ↓
┌─────────────────────────────────────┐
│ Step 1: Upload Images (1-2)        │
│   [Image 1] [Image 2]               │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│ Step 2: Select Model                │
│   ○ Nano Banana (1 credit)          │
│   ● Nano Banana Pro (2-4 credits)   │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│ Step 3: Enter Prompt                │
│   "Add sunglasses..."               │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│ ▼ Additional Settings (toggle)      │
│                                     │
│   Aspect Ratio:                     │
│   [1:1] [16:9] [9:16] [4:3]        │
│                                     │
│   Output Format:                    │
│   [JPEG] [PNG] [WEBP]              │
│                                     │
│   Resolution: (Pro only) ⭐         │
│   [1K: 2 credits]                   │
│   [2K: 3 credits] ← selected        │
│   [4K: 4 credits]                   │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│ 💰 This will cost 3 credits         │
│    (Nano Banana Pro @ 2K)           │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│   [Process Image] ← 10 credits     │
└─────────────────────────────────────┘
    ↓
Result View (processed image)
```

---

### ✅ Updated Feature Matrix

| Feature | Implementation Status | Notes |
|---------|----------------------|-------|
| Dual model system | ✅ Ready to implement | Basic + Pro endpoints |
| Multi-image (2 images) | ✅ Ready to implement | Both models support |
| Aspect ratio selection | ✅ Ready to implement | 11 options for both |
| Output format | ✅ Ready to implement | 3 formats for both |
| Resolution control | ✅ Ready to implement | Pro model only (1K/2K/4K) |
| Dynamic credit pricing | ✅ Ready to implement | 1 credit basic, 2-4 credits pro |
| Custom prompts | ✅ Ready to implement | Both models |

---

### 🚀 Next Steps - READY TO IMPLEMENT!

**✅ All API documentation received and analyzed**
**✅ Model strategy finalized (dual model with resolution tiers)**
**✅ Credit pricing strategy defined**
**✅ Parameter mapping complete**

**We can now proceed with implementation in this order:**
1. Phase 2: Database changes (add resolution enum, pricing table)
2. Phase 3: Backend implementation (Edge Function with both endpoints)
3. Phase 4-6: iOS implementation (models, ViewModels, UI)
4. Phase 7-10: Testing, polish, documentation

**Ready to start? Say the word and I'll begin with Phase 2! 🎯**

---

## 💾 Database Schema Changes

### Migration 091: Add Model System Support

```sql
-- =====================================================
-- Migration 091: Nano Banana Model System
-- Created: 2025-11-20
-- Purpose: Add dual model support with flexible configs
-- =====================================================

-- Step 1: Add model configuration fields to themes table
ALTER TABLE themes
ADD COLUMN IF NOT EXISTS model_type TEXT DEFAULT 'nano-banana'
  CHECK (model_type IN ('nano-banana', 'nano-banana-pro')),
ADD COLUMN IF NOT EXISTS credit_cost INTEGER DEFAULT 1
  CHECK (credit_cost > 0),
ADD COLUMN IF NOT EXISTS supports_multi_image BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS max_images INTEGER DEFAULT 1
  CHECK (max_images >= 1 AND max_images <= 2),
ADD COLUMN IF NOT EXISTS supported_aspect_ratios TEXT[] DEFAULT ARRAY['1:1'],
ADD COLUMN IF NOT EXISTS supported_output_formats TEXT[] DEFAULT ARRAY['jpeg', 'png'],
ADD COLUMN IF NOT EXISTS supports_resolution_picker BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS available_resolutions JSONB DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS default_resolution JSONB DEFAULT NULL;

-- Step 2: Add pricing configuration table
CREATE TABLE IF NOT EXISTS model_pricing (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  model_type TEXT NOT NULL,
  resolution_tier TEXT NOT NULL, -- 'standard', 'high', 'ultra'
  width INTEGER NOT NULL,
  height INTEGER NOT NULL,
  credit_cost INTEGER NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(model_type, resolution_tier)
);

-- Step 3: Add RLS policies for model_pricing
ALTER TABLE model_pricing ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read model pricing"
  ON model_pricing FOR SELECT
  USING (true);

-- Step 4: Insert default pricing
INSERT INTO model_pricing (model_type, resolution_tier, width, height, credit_cost) VALUES
('nano-banana', 'standard', 1024, 1024, 1),
('nano-banana-pro', 'standard', 1024, 1024, 2),
('nano-banana-pro', 'high', 1536, 1536, 3),
('nano-banana-pro', 'ultra', 2048, 2048, 4)
ON CONFLICT (model_type, resolution_tier) DO NOTHING;

-- Step 5: Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_themes_model_type ON themes(model_type);
CREATE INDEX IF NOT EXISTS idx_model_pricing_type ON model_pricing(model_type);

-- Step 6: Update existing themes with new fields
UPDATE themes
SET
  model_type = 'nano-banana',
  credit_cost = 1,
  supports_multi_image = false,
  max_images = 1,
  supported_aspect_ratios = ARRAY['1:1', '16:9', '9:16', '4:3'],
  supported_output_formats = ARRAY['jpeg', 'png', 'webp'],
  supports_resolution_picker = false
WHERE model_type IS NULL;

-- Step 7: Create function to calculate credit cost
CREATE OR REPLACE FUNCTION calculate_processing_cost(
  p_model_type TEXT,
  p_resolution_width INTEGER DEFAULT NULL,
  p_resolution_height INTEGER DEFAULT NULL
) RETURNS INTEGER AS $$
DECLARE
  v_cost INTEGER;
  v_resolution_tier TEXT;
BEGIN
  -- For nano-banana (no resolution picker)
  IF p_model_type = 'nano-banana' THEN
    RETURN 1;
  END IF;

  -- For nano-banana-pro, determine tier based on resolution
  IF p_resolution_width IS NULL OR p_resolution_height IS NULL THEN
    -- Default to standard tier
    SELECT credit_cost INTO v_cost
    FROM model_pricing
    WHERE model_type = p_model_type AND resolution_tier = 'standard';
    RETURN COALESCE(v_cost, 2);
  END IF;

  -- Determine resolution tier
  IF p_resolution_width <= 1024 AND p_resolution_height <= 1024 THEN
    v_resolution_tier := 'standard';
  ELSIF p_resolution_width <= 1536 AND p_resolution_height <= 1536 THEN
    v_resolution_tier := 'high';
  ELSE
    v_resolution_tier := 'ultra';
  END IF;

  -- Get cost for tier
  SELECT credit_cost INTO v_cost
  FROM model_pricing
  WHERE model_type = p_model_type AND resolution_tier = v_resolution_tier;

  RETURN COALESCE(v_cost, 2);
END;
$$ LANGUAGE plpgsql STABLE;

-- Step 8: Create function to validate processing request
CREATE OR REPLACE FUNCTION validate_processing_request(
  p_theme_id UUID,
  p_num_images INTEGER,
  p_aspect_ratio TEXT,
  p_output_format TEXT,
  p_resolution_width INTEGER DEFAULT NULL,
  p_resolution_height INTEGER DEFAULT NULL
) RETURNS TABLE(
  is_valid BOOLEAN,
  error_message TEXT,
  estimated_cost INTEGER
) AS $$
DECLARE
  v_theme RECORD;
  v_cost INTEGER;
BEGIN
  -- Get theme configuration
  SELECT * INTO v_theme FROM themes WHERE id = p_theme_id;

  IF NOT FOUND THEN
    RETURN QUERY SELECT false, 'Theme not found', 0;
    RETURN;
  END IF;

  -- Validate number of images
  IF p_num_images > v_theme.max_images THEN
    RETURN QUERY SELECT false,
      format('Max %s images allowed for this theme', v_theme.max_images),
      0;
    RETURN;
  END IF;

  -- Validate aspect ratio
  IF NOT (p_aspect_ratio = ANY(v_theme.supported_aspect_ratios)) THEN
    RETURN QUERY SELECT false,
      format('Aspect ratio %s not supported', p_aspect_ratio),
      0;
    RETURN;
  END IF;

  -- Validate output format
  IF NOT (p_output_format = ANY(v_theme.supported_output_formats)) THEN
    RETURN QUERY SELECT false,
      format('Output format %s not supported', p_output_format),
      0;
    RETURN;
  END IF;

  -- Validate resolution (if picker is supported)
  IF v_theme.supports_resolution_picker THEN
    IF p_resolution_width IS NULL OR p_resolution_height IS NULL THEN
      RETURN QUERY SELECT false,
        'Resolution must be specified for this model',
        0;
      RETURN;
    END IF;
  END IF;

  -- Calculate cost
  v_cost := calculate_processing_cost(
    v_theme.model_type,
    p_resolution_width,
    p_resolution_height
  );

  -- All validations passed
  RETURN QUERY SELECT true, NULL::TEXT, v_cost;
END;
$$ LANGUAGE plpgsql STABLE;

-- Step 9: Add comments for documentation
COMMENT ON COLUMN themes.model_type IS 'AI model to use: nano-banana or nano-banana-pro';
COMMENT ON COLUMN themes.credit_cost IS 'Base credit cost for this theme (may vary with resolution)';
COMMENT ON COLUMN themes.supports_multi_image IS 'Whether theme supports uploading 2 images';
COMMENT ON COLUMN themes.max_images IS 'Maximum number of images allowed (1 or 2)';
COMMENT ON COLUMN themes.supported_aspect_ratios IS 'Array of supported aspect ratios (e.g., 1:1, 16:9)';
COMMENT ON COLUMN themes.supported_output_formats IS 'Array of supported output formats (jpeg, png, webp)';
COMMENT ON COLUMN themes.supports_resolution_picker IS 'Whether user can select resolution (pro model only)';
COMMENT ON COLUMN themes.available_resolutions IS 'JSONB array of resolution options for picker';

COMMENT ON FUNCTION calculate_processing_cost IS 'Calculate credit cost based on model type and resolution';
COMMENT ON FUNCTION validate_processing_request IS 'Validate processing parameters and return estimated cost';
```

### Rollback Script

```sql
-- Rollback migration 091
DROP FUNCTION IF EXISTS validate_processing_request;
DROP FUNCTION IF EXISTS calculate_processing_cost;
DROP TABLE IF EXISTS model_pricing;

ALTER TABLE themes
DROP COLUMN IF EXISTS model_type,
DROP COLUMN IF EXISTS credit_cost,
DROP COLUMN IF EXISTS supports_multi_image,
DROP COLUMN IF EXISTS max_images,
DROP COLUMN IF EXISTS supported_aspect_ratios,
DROP COLUMN IF EXISTS supported_output_formats,
DROP COLUMN IF EXISTS supports_resolution_picker,
DROP COLUMN IF EXISTS available_resolutions,
DROP COLUMN IF EXISTS default_resolution;
```

---

## 🔌 Backend Implementation

### 1. Update submit-job Edge Function

**File:** `supabase/functions/submit-job/index.ts`

#### Changes Required:

```typescript
// =====================================================
// SECTION 1: Add Type Definitions
// =====================================================

interface ProcessingRequest {
  theme_id: string;
  user_id: string;
  device_id?: string;
  prompt: string;
  image_data_urls: string[]; // Array of 1-2 images
  model_type: 'nano-banana' | 'nano-banana-pro';
  aspect_ratio: '1:1' | '16:9' | '9:16' | '4:3';
  output_format: 'jpeg' | 'png' | 'webp';
  resolution?: {
    width: number;
    height: number;
  };
}

interface FalAINanoBananaRequest {
  // [TO BE FILLED AFTER API DOCS RECEIVED]
  image?: string;
  images?: string[];
  prompt: string;
  aspect_ratio?: string;
  output_format?: string;
  // ... other parameters from API docs
}

interface FalAINanoBananaProRequest {
  // [TO BE FILLED AFTER API DOCS RECEIVED]
  image_1?: string;
  image_2?: string;
  images?: string[];
  prompt: string;
  aspect_ratio?: string;
  resolution?: {
    width: number;
    height: number;
  };
  output_format?: string;
  // ... other parameters from API docs
}

// =====================================================
// SECTION 2: Add Request Builder Functions
// =====================================================

function buildNanoBananaRequest(
  request: ProcessingRequest
): FalAINanoBananaRequest {
  // [TO BE IMPLEMENTED AFTER API DOCS]
  return {
    image: request.image_data_urls[0], // Assuming single image field
    prompt: request.prompt,
    aspect_ratio: request.aspect_ratio,
    output_format: request.output_format,
    // Map other parameters based on API docs
  };
}

function buildNanoBananaProRequest(
  request: ProcessingRequest
): FalAINanoBananaProRequest {
  // [TO BE IMPLEMENTED AFTER API DOCS]
  return {
    images: request.image_data_urls, // Or separate image_1, image_2 fields
    prompt: request.prompt,
    aspect_ratio: request.aspect_ratio,
    resolution: request.resolution,
    output_format: request.output_format,
    // Map other parameters based on API docs
  };
}

// =====================================================
// SECTION 3: Add Model Endpoint Resolver
// =====================================================

function getModelEndpoint(modelType: string): string {
  const endpoints = {
    'nano-banana': 'fal-ai/nano-banana',
    'nano-banana-pro': 'fal-ai/nano-banana-pro',
  };
  return endpoints[modelType] || 'fal-ai/nano-banana';
}

// =====================================================
// SECTION 4: Update Main Handler
// =====================================================

serve(async (req) => {
  try {
    // Parse request
    const body: ProcessingRequest = await req.json();
    const {
      theme_id,
      user_id,
      device_id,
      prompt,
      image_data_urls,
      model_type,
      aspect_ratio,
      output_format,
      resolution,
    } = body;

    // Validate request
    console.log('🔍 Validating processing request:', {
      theme_id,
      model_type,
      num_images: image_data_urls.length,
      aspect_ratio,
      resolution,
    });

    // Call database validation function
    const { data: validation, error: validationError } = await supabase
      .rpc('validate_processing_request', {
        p_theme_id: theme_id,
        p_num_images: image_data_urls.length,
        p_aspect_ratio: aspect_ratio,
        p_output_format: output_format,
        p_resolution_width: resolution?.width,
        p_resolution_height: resolution?.height,
      });

    if (validationError || !validation[0]?.is_valid) {
      console.error('❌ Validation failed:', validation[0]?.error_message);
      return new Response(
        JSON.stringify({
          error: validation[0]?.error_message || 'Invalid request parameters',
        }),
        { status: 400, headers: corsHeaders }
      );
    }

    const estimated_cost = validation[0].estimated_cost;

    console.log('✅ Validation passed. Estimated cost:', estimated_cost);

    // Deduct credits atomically
    const { data: creditResult, error: creditError } = await supabase
      .rpc('deduct_credits_atomic', {
        p_user_id: user_id,
        p_device_id: device_id,
        p_amount: estimated_cost,
        p_reason: `${model_type}_processing`,
      });

    if (creditError || !creditResult) {
      console.error('❌ Credit deduction failed:', creditError);
      return new Response(
        JSON.stringify({ error: 'Insufficient credits' }),
        { status: 402, headers: corsHeaders }
      );
    }

    console.log('💳 Credits deducted:', estimated_cost);

    // Build model-specific request
    let falRequest;
    if (model_type === 'nano-banana') {
      falRequest = buildNanoBananaRequest(body);
    } else {
      falRequest = buildNanoBananaProRequest(body);
    }

    // Get model endpoint
    const endpoint = getModelEndpoint(model_type);

    console.log('🚀 Submitting to fal.ai:', endpoint);

    // Submit to fal.ai
    const result = await fal.subscribe(endpoint, {
      input: falRequest,
      logs: true,
      onQueueUpdate: (update) => {
        console.log('📊 Queue update:', update);
      },
    });

    console.log('✅ fal.ai processing complete');

    // Store result in database
    const { data: jobData, error: jobError } = await supabase
      .from('job_results')
      .insert({
        user_id,
        device_id,
        theme_id,
        model_type,
        aspect_ratio,
        resolution: resolution ? JSON.stringify(resolution) : null,
        output_format,
        credit_cost: estimated_cost,
        result_url: result.data?.image_url || result.data?.images?.[0]?.url,
        status: 'completed',
        metadata: JSON.stringify(result.data),
      })
      .select()
      .single();

    if (jobError) {
      console.error('❌ Failed to store result:', jobError);
      // Rollback credits
      await supabase.rpc('add_credits_atomic', {
        p_user_id: user_id,
        p_device_id: device_id,
        p_amount: estimated_cost,
        p_reason: 'rollback_failed_job',
      });
      throw jobError;
    }

    console.log('✅ Job result stored');

    return new Response(
      JSON.stringify({
        success: true,
        job_id: jobData.id,
        result_url: jobData.result_url,
        credits_remaining: creditResult.new_balance,
        cost: estimated_cost,
      }),
      { status: 200, headers: corsHeaders }
    );
  } catch (error) {
    console.error('❌ Error in submit-job:', error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: corsHeaders }
    );
  }
});
```

#### Key Changes:
1. ✅ Accept multiple images (array)
2. ✅ Accept model_type parameter
3. ✅ Accept aspect_ratio, resolution, output_format
4. ✅ Validate request with database function
5. ✅ Calculate cost dynamically
6. ✅ Build model-specific requests
7. ✅ Use correct fal.ai endpoint
8. ✅ Store enhanced metadata

### 2. Update job_results Table Schema

```sql
-- Add new fields to job_results table
ALTER TABLE job_results
ADD COLUMN IF NOT EXISTS model_type TEXT,
ADD COLUMN IF NOT EXISTS aspect_ratio TEXT,
ADD COLUMN IF NOT EXISTS resolution JSONB,
ADD COLUMN IF NOT EXISTS output_format TEXT,
ADD COLUMN IF NOT EXISTS credit_cost INTEGER DEFAULT 1,
ADD COLUMN IF NOT EXISTS num_images INTEGER DEFAULT 1;

-- Add index for filtering
CREATE INDEX IF NOT EXISTS idx_job_results_model_type ON job_results(model_type);
CREATE INDEX IF NOT EXISTS idx_job_results_user_created ON job_results(user_id, created_at DESC);
```

---

## 📱 iOS Implementation

### File Structure

```
BananaUniverse/
└── Features/
    ├── ImageProcessing/                    (NEW - replaces Chat/)
    │   ├── Views/
    │   │   ├── ProcessingView.swift               ⭐ Main view
    │   │   ├── ImagePickerSection.swift           ⭐ Multi-image upload
    │   │   ├── ModelSelectorSection.swift         ⭐ nano-banana selector
    │   │   ├── AdditionalSettingsSection.swift    ⭐ Collapsible settings
    │   │   │   ├── AspectRatioPicker.swift        ⭐ Aspect ratio grid
    │   │   │   ├── ResolutionPicker.swift         ⭐ Resolution options
    │   │   │   └── OutputFormatPicker.swift       ⭐ Format selector
    │   │   ├── CreditCostBanner.swift             ⭐ Cost display
    │   │   └── ResultView.swift                   ⭐ Result page
    │   ├── ViewModels/
    │   │   ├── ProcessingViewModel.swift          ⭐ Main logic
    │   │   └── CreditCostCalculator.swift         ⭐ Cost calculation
    │   └── Models/
    │       ├── ProcessingConfig.swift             ⭐ Settings model
    │       ├── ModelType.swift                    ⭐ Model enum
    │       ├── AspectRatio.swift                  ⭐ Aspect ratio enum
    │       ├── Resolution.swift                   ⭐ Resolution struct
    │       └── OutputFormat.swift                 ⭐ Format enum
    └── Home/
        └── Views/
            └── HomeView.swift                     🔧 Update navigation
```

### 1. Data Models

#### File: `Features/ImageProcessing/Models/ModelType.swift`

```swift
import Foundation

/// Represents the AI model type for image processing
enum ModelType: String, CaseIterable, Identifiable {
    case nanoBanana = "nano-banana"
    case nanoBananaPro = "nano-banana-pro"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .nanoBanana:
            return "Nano Banana"
        case .nanoBananaPro:
            return "Nano Banana Pro"
        }
    }

    var description: String {
        switch self {
        case .nanoBanana:
            return "Fast, standard quality processing"
        case .nanoBananaPro:
            return "Professional quality with more control"
        }
    }

    var maxImages: Int {
        switch self {
        case .nanoBanana:
            return 2
        case .nanoBananaPro:
            return 2
        }
    }

    var supportsResolutionPicker: Bool {
        switch self {
        case .nanoBanana:
            return false
        case .nanoBananaPro:
            return true
        }
    }

    var baseCost: Int {
        switch self {
        case .nanoBanana:
            return 1
        case .nanoBananaPro:
            return 2
        }
    }

    func cost(for resolution: Resolution?) -> Int {
        switch self {
        case .nanoBanana:
            return baseCost
        case .nanoBananaPro:
            guard let resolution = resolution else { return baseCost }
            // Calculate cost based on resolution tier
            if resolution.width > 1536 || resolution.height > 1536 {
                return 4 // Ultra
            } else if resolution.width > 1024 || resolution.height > 1024 {
                return 3 // High
            } else {
                return 2 // Standard
            }
        }
    }
}
```

#### File: `Features/ImageProcessing/Models/AspectRatio.swift`

```swift
import Foundation

/// Represents aspect ratio options for image generation
enum AspectRatio: String, CaseIterable, Identifiable {
    case square = "1:1"
    case landscape = "16:9"
    case portrait = "9:16"
    case standard = "4:3"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .square:
            return "Square"
        case .landscape:
            return "Landscape"
        case .portrait:
            return "Portrait"
        case .standard:
            return "Standard"
        }
    }

    var icon: String {
        switch self {
        case .square:
            return "square"
        case .landscape:
            return "rectangle"
        case .portrait:
            return "rectangle.portrait"
        case .standard:
            return "rectangle.ratio.4.to.3"
        }
    }

    var aspectValue: CGFloat {
        switch self {
        case .square:
            return 1.0
        case .landscape:
            return 16.0 / 9.0
        case .portrait:
            return 9.0 / 16.0
        case .standard:
            return 4.0 / 3.0
        }
    }
}
```

#### File: `Features/ImageProcessing/Models/Resolution.swift`

```swift
import Foundation

/// Represents resolution options for pro model
struct Resolution: Identifiable, Hashable {
    let id = UUID()
    let width: Int
    let height: Int
    let tier: Tier

    enum Tier: String {
        case standard = "Standard"
        case high = "High"
        case ultra = "Ultra"
    }

    var displayName: String {
        "\(width) × \(height)"
    }

    var tierName: String {
        tier.rawValue
    }

    var creditCost: Int {
        switch tier {
        case .standard:
            return 2
        case .high:
            return 3
        case .ultra:
            return 4
        }
    }

    // Predefined resolutions for nano-banana-pro
    static let standardResolutions: [Resolution] = [
        Resolution(width: 512, height: 512, tier: .standard),
        Resolution(width: 768, height: 768, tier: .standard),
        Resolution(width: 1024, height: 1024, tier: .standard),
        Resolution(width: 1536, height: 1536, tier: .high),
        Resolution(width: 2048, height: 2048, tier: .ultra),
    ]

    // Landscape resolutions
    static let landscapeResolutions: [Resolution] = [
        Resolution(width: 1024, height: 576, tier: .standard),
        Resolution(width: 1536, height: 864, tier: .high),
        Resolution(width: 2048, height: 1152, tier: .ultra),
    ]

    // Portrait resolutions
    static let portraitResolutions: [Resolution] = [
        Resolution(width: 576, height: 1024, tier: .standard),
        Resolution(width: 864, height: 1536, tier: .high),
        Resolution(width: 1152, height: 2048, tier: .ultra),
    ]

    static func resolutions(for aspectRatio: AspectRatio) -> [Resolution] {
        switch aspectRatio {
        case .square, .standard:
            return standardResolutions
        case .landscape:
            return landscapeResolutions
        case .portrait:
            return portraitResolutions
        }
    }
}
```

#### File: `Features/ImageProcessing/Models/OutputFormat.swift`

```swift
import Foundation

/// Represents output format options
enum OutputFormat: String, CaseIterable, Identifiable {
    case jpeg = "jpeg"
    case png = "png"
    case webp = "webp"

    var id: String { rawValue }

    var displayName: String {
        rawValue.uppercased()
    }

    var fileExtension: String {
        ".\(rawValue)"
    }

    var description: String {
        switch self {
        case .jpeg:
            return "Compressed, smaller file size"
        case .png:
            return "Lossless, supports transparency"
        case .webp:
            return "Modern format, best quality/size"
        }
    }

    var icon: String {
        switch self {
        case .jpeg:
            return "photo"
        case .png:
            return "photo.stack"
        case .webp:
            return "photo.badge.checkmark"
        }
    }
}
```

#### File: `Features/ImageProcessing/Models/ProcessingConfig.swift`

```swift
import UIKit

/// Complete configuration for image processing request
struct ProcessingConfig {
    // Required
    var theme: Theme
    var images: [UIImage] = []
    var prompt: String = ""

    // Model selection
    var modelType: ModelType = .nanoBanana

    // Processing options
    var aspectRatio: AspectRatio = .square
    var outputFormat: OutputFormat = .jpeg
    var resolution: Resolution?

    // UI state
    var showAdditionalSettings: Bool = false

    // Validation
    var isValid: Bool {
        !images.isEmpty &&
        !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        images.count <= modelType.maxImages &&
        (modelType.supportsResolutionPicker ? resolution != nil : true)
    }

    var validationError: String? {
        if images.isEmpty {
            return "Please add at least one image"
        }
        if images.count > modelType.maxImages {
            return "Maximum \(modelType.maxImages) images allowed"
        }
        if prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Please enter a prompt"
        }
        if modelType.supportsResolutionPicker && resolution == nil {
            return "Please select a resolution"
        }
        return nil
    }

    // Cost calculation
    var estimatedCost: Int {
        modelType.cost(for: resolution)
    }

    // API request payload
    func toAPIPayload(userId: String, deviceId: String?) -> [String: Any] {
        var payload: [String: Any] = [
            "theme_id": theme.id.uuidString,
            "user_id": userId,
            "prompt": prompt,
            "model_type": modelType.rawValue,
            "aspect_ratio": aspectRatio.rawValue,
            "output_format": outputFormat.rawValue,
            "num_images": images.count,
        ]

        if let deviceId = deviceId {
            payload["device_id"] = deviceId
        }

        if let resolution = resolution {
            payload["resolution"] = [
                "width": resolution.width,
                "height": resolution.height,
            ]
        }

        return payload
    }
}
```

### 2. ViewModels

#### File: `Features/ImageProcessing/ViewModels/CreditCostCalculator.swift`

```swift
import Foundation
import Combine

/// Calculates real-time credit costs based on processing configuration
@MainActor
class CreditCostCalculator: ObservableObject {
    @Published var estimatedCost: Int = 1

    private var cancellables = Set<AnyCancellable>()

    func calculate(config: ProcessingConfig) {
        estimatedCost = config.estimatedCost
    }

    func subscribeTo(config: Published<ProcessingConfig>.Publisher) {
        config
            .map { $0.estimatedCost }
            .removeDuplicates()
            .assign(to: &$estimatedCost)
    }
}
```

#### File: `Features/ImageProcessing/ViewModels/ProcessingViewModel.swift`

```swift
import SwiftUI
import Combine

@MainActor
class ProcessingViewModel: ObservableObject {
    // MARK: - Dependencies
    private let supabaseService = SupabaseService.shared
    private let creditManager = CreditManager.shared

    // MARK: - Published State
    @Published var config: ProcessingConfig
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var processedResult: ProcessedImage?

    // MARK: - Cost Calculator
    let costCalculator = CreditCostCalculator()

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init(theme: Theme) {
        self.config = ProcessingConfig(theme: theme)

        // Subscribe cost calculator to config changes
        costCalculator.subscribeTo(config: $config)
    }

    // MARK: - Image Management
    func addImage(_ image: UIImage) {
        guard config.images.count < config.modelType.maxImages else {
            errorMessage = "Maximum \(config.modelType.maxImages) images allowed"
            return
        }
        config.images.append(image)
    }

    func removeImage(at index: Int) {
        guard config.images.indices.contains(index) else { return }
        config.images.remove(at: index)
    }

    // MARK: - Model Selection
    func selectModel(_ modelType: ModelType) {
        config.modelType = modelType

        // Reset resolution if switching from pro to basic
        if !modelType.supportsResolutionPicker {
            config.resolution = nil
        } else if config.resolution == nil {
            // Set default resolution for pro model
            config.resolution = Resolution.standardResolutions.first
        }

        // Validate image count
        if config.images.count > modelType.maxImages {
            config.images = Array(config.images.prefix(modelType.maxImages))
        }
    }

    // MARK: - Settings Management
    func selectAspectRatio(_ ratio: AspectRatio) {
        config.aspectRatio = ratio

        // Update resolution options if pro model
        if config.modelType.supportsResolutionPicker {
            let newResolutions = Resolution.resolutions(for: ratio)
            // Keep same tier if possible
            if let currentTier = config.resolution?.tier {
                config.resolution = newResolutions.first { $0.tier == currentTier }
                    ?? newResolutions.first
            } else {
                config.resolution = newResolutions.first
            }
        }
    }

    func selectResolution(_ resolution: Resolution) {
        config.resolution = resolution
    }

    func selectOutputFormat(_ format: OutputFormat) {
        config.outputFormat = format
    }

    func toggleAdditionalSettings() {
        config.showAdditionalSettings.toggle()
    }

    // MARK: - Validation
    var canProcess: Bool {
        config.isValid && !isProcessing && hasEnoughCredits
    }

    var hasEnoughCredits: Bool {
        creditManager.credits >= config.estimatedCost
    }

    // MARK: - Processing
    func processImages() async {
        guard canProcess else {
            if let error = config.validationError {
                errorMessage = error
            } else if !hasEnoughCredits {
                errorMessage = "Insufficient credits. Need \(config.estimatedCost), have \(creditManager.credits)"
            }
            return
        }

        isProcessing = true
        errorMessage = nil

        do {
            print("🎨 Starting image processing with config:", config)

            // Convert images to data URLs
            let imageDataURLs = try config.images.map { image -> String in
                guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
                    throw ProcessingError.imageConversionFailed
                }
                let base64 = jpegData.base64EncodedString()
                return "data:image/jpeg;base64,\(base64)"
            }

            // Get user/device ID
            let userId = await supabaseService.getCurrentUserId()
            let deviceId = await supabaseService.getDeviceId()

            // Build API payload
            var payload = config.toAPIPayload(userId: userId, deviceId: deviceId)
            payload["image_data_urls"] = imageDataURLs

            print("📤 Submitting job to Edge Function")

            // Call submit-job Edge Function
            let response: ProcessingResponse = try await supabaseService.functions
                .invoke("submit-job", options: FunctionInvokeOptions(
                    body: payload
                ))

            print("✅ Processing complete:", response)

            // Update credits
            await creditManager.setCredits(response.creditsRemaining)

            // Store result
            processedResult = ProcessedImage(
                id: response.jobId,
                url: response.resultUrl,
                themeId: config.theme.id,
                modelType: config.modelType,
                aspectRatio: config.aspectRatio,
                resolution: config.resolution,
                creditCost: response.cost,
                createdAt: Date()
            )

        } catch {
            print("❌ Processing failed:", error)
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }

    // MARK: - Reset
    func reset() {
        config.images = []
        config.prompt = ""
        config.showAdditionalSettings = false
        processedResult = nil
        errorMessage = nil
    }
}

// MARK: - Supporting Types

enum ProcessingError: LocalizedError {
    case imageConversionFailed
    case insufficientCredits
    case invalidConfiguration

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to convert image"
        case .insufficientCredits:
            return "Not enough credits"
        case .invalidConfiguration:
            return "Invalid processing configuration"
        }
    }
}

struct ProcessingResponse: Codable {
    let success: Bool
    let jobId: String
    let resultUrl: String
    let creditsRemaining: Int
    let cost: Int

    enum CodingKeys: String, CodingKey {
        case success
        case jobId = "job_id"
        case resultUrl = "result_url"
        case creditsRemaining = "credits_remaining"
        case cost
    }
}

struct ProcessedImage: Identifiable {
    let id: String
    let url: String
    let themeId: UUID
    let modelType: ModelType
    let aspectRatio: AspectRatio
    let resolution: Resolution?
    let creditCost: Int
    let createdAt: Date
}
```

### 3. UI Components

> [Due to length constraints, the complete UI component implementations will be in a separate section]

Key UI components to be implemented:
1. `ProcessingView.swift` - Main container view
2. `ImagePickerSection.swift` - Multi-image upload
3. `ModelSelectorSection.swift` - Model toggle
4. `AdditionalSettingsSection.swift` - Collapsible settings panel
5. `AspectRatioPicker.swift` - Aspect ratio grid
6. `ResolutionPicker.swift` - Resolution selector
7. `OutputFormatPicker.swift` - Format picker
8. `CreditCostBanner.swift` - Cost display banner
9. `ResultView.swift` - Result display page

---

## 🧪 Testing Strategy

### 1. API Testing

```bash
# Test nano-banana endpoint
curl -X POST "https://[project-ref].supabase.co/functions/v1/submit-job" \
  -H "Authorization: Bearer [anon-key]" \
  -H "Content-Type: application/json" \
  -d '{
    "theme_id": "...",
    "user_id": "...",
    "prompt": "Add sunglasses",
    "image_data_urls": ["data:image/jpeg;base64,..."],
    "model_type": "nano-banana",
    "aspect_ratio": "1:1",
    "output_format": "jpeg"
  }'

# Test nano-banana-pro endpoint
curl -X POST "https://[project-ref].supabase.co/functions/v1/submit-job" \
  -H "Authorization: Bearer [anon-key]" \
  -H "Content-Type: application/json" \
  -d '{
    "theme_id": "...",
    "user_id": "...",
    "prompt": "Combine these images",
    "image_data_urls": ["data:image/jpeg;base64,...", "data:image/jpeg;base64,..."],
    "model_type": "nano-banana-pro",
    "aspect_ratio": "16:9",
    "resolution": {"width": 1536, "height": 864},
    "output_format": "png"
  }'
```

### 2. iOS Unit Tests

```swift
// Test credit cost calculation
func testCreditCostCalculation() {
    let config = ProcessingConfig(theme: mockTheme)

    // nano-banana should always be 1 credit
    config.modelType = .nanoBanana
    XCTAssertEqual(config.estimatedCost, 1)

    // nano-banana-pro varies by resolution
    config.modelType = .nanoBananaPro
    config.resolution = Resolution(width: 1024, height: 1024, tier: .standard)
    XCTAssertEqual(config.estimatedCost, 2)

    config.resolution = Resolution(width: 1536, height: 1536, tier: .high)
    XCTAssertEqual(config.estimatedCost, 3)

    config.resolution = Resolution(width: 2048, height: 2048, tier: .ultra)
    XCTAssertEqual(config.estimatedCost, 4)
}

// Test validation
func testConfigValidation() {
    var config = ProcessingConfig(theme: mockTheme)

    // Invalid: no images
    XCTAssertFalse(config.isValid)
    XCTAssertEqual(config.validationError, "Please add at least one image")

    // Invalid: no prompt
    config.images = [mockImage]
    XCTAssertFalse(config.isValid)

    // Valid
    config.prompt = "Test prompt"
    XCTAssertTrue(config.isValid)
    XCTAssertNil(config.validationError)
}
```

### 3. Integration Tests

- [ ] Test full flow: upload → select model → configure → process
- [ ] Test credit deduction for both models
- [ ] Test error handling (insufficient credits, invalid params)
- [ ] Test result storage in database
- [ ] Test rollback on failures

---

## 📋 Implementation Checklist

### Phase 1: API Documentation & Planning (CURRENT)
- [x] Create implementation plan document
- [ ] Receive fal-ai/nano-banana API docs
- [ ] Receive fal-ai/nano-banana-pro API docs
- [ ] Complete API parameter mapping
- [ ] Update implementation plan with API specifics

### Phase 2: Database Changes (1 hour)
- [ ] Create migration 091 file
- [ ] Add model_type and related fields to themes table
- [ ] Create model_pricing table
- [ ] Create calculate_processing_cost function
- [ ] Create validate_processing_request function
- [ ] Test migration locally with `supabase db reset`
- [ ] Test rollback script
- [ ] Deploy migration to production

### Phase 3: Backend Implementation (2 hours)
- [ ] Update submit-job/index.ts with new types
- [ ] Implement buildNanoBananaRequest()
- [ ] Implement buildNanoBananaProRequest()
- [ ] Add model endpoint resolver
- [ ] Update main handler with validation
- [ ] Update credit deduction logic
- [ ] Add enhanced metadata storage
- [ ] Test with curl scripts
- [ ] Deploy Edge Function

### Phase 4: iOS Models (1 hour)
- [ ] Create ModelType.swift
- [ ] Create AspectRatio.swift
- [ ] Create Resolution.swift
- [ ] Create OutputFormat.swift
- [ ] Create ProcessingConfig.swift
- [ ] Add unit tests for models

### Phase 5: iOS ViewModels (1 hour)
- [ ] Create CreditCostCalculator.swift
- [ ] Create ProcessingViewModel.swift
- [ ] Implement image management logic
- [ ] Implement model selection logic
- [ ] Implement processing logic
- [ ] Add unit tests for ViewModels

### Phase 6: iOS UI Components (6 hours)
- [ ] Create ProcessingView.swift (main container)
- [ ] Create ImagePickerSection.swift
  - [ ] Multi-image upload
  - [ ] Image preview grid
  - [ ] Remove image functionality
- [ ] Create ModelSelectorSection.swift
  - [ ] Segmented control
  - [ ] Model descriptions
- [ ] Create AdditionalSettingsSection.swift
  - [ ] Collapsible toggle
  - [ ] Settings container
- [ ] Create AspectRatioPicker.swift
  - [ ] Grid layout
  - [ ] Visual icons
- [ ] Create ResolutionPicker.swift
  - [ ] Resolution list
  - [ ] Tier indicators
  - [ ] Credit cost per option
- [ ] Create OutputFormatPicker.swift
  - [ ] Format options
  - [ ] Format descriptions
- [ ] Create CreditCostBanner.swift
  - [ ] Real-time cost display
  - [ ] Warning states
- [ ] Create ResultView.swift
  - [ ] Image display
  - [ ] Download/share actions
  - [ ] Metadata display

### Phase 7: Navigation & Integration (1 hour)
- [ ] Update HomeView navigation
- [ ] Add ProcessingView to navigation stack
- [ ] Update ContentView if needed
- [ ] Test navigation flow
- [ ] Test deep linking if applicable

### Phase 8: Testing (2 hours)
- [ ] Test nano-banana model end-to-end
- [ ] Test nano-banana-pro model end-to-end
- [ ] Test multi-image upload (2 images)
- [ ] Test aspect ratio changes
- [ ] Test resolution selection (pro)
- [ ] Test output format selection
- [ ] Test credit cost calculation
- [ ] Test credit deduction
- [ ] Test insufficient credits handling
- [ ] Test error states
- [ ] Test result display
- [ ] Test on physical device

### Phase 9: Polish & QA (1 hour)
- [ ] Add loading animations
- [ ] Add haptic feedback
- [ ] Add accessibility labels
- [ ] Test dark mode
- [ ] Test iPad layout
- [ ] Test different screen sizes
- [ ] Fix any UI bugs
- [ ] Performance optimization

### Phase 10: Documentation (30 minutes)
- [ ] Update CLAUDE.md with new flow
- [ ] Document new API endpoints
- [ ] Update credit system docs
- [ ] Add troubleshooting guide

---

## 📊 Success Metrics

Track these metrics after implementation:

| Metric | Target | How to Measure |
|--------|--------|----------------|
| Feature adoption | > 50% of users try new models | Analytics |
| Pro model usage | > 20% choose pro over basic | Database queries |
| Error rate | < 2% failed requests | Error logs |
| Credit deduction accuracy | 100% correct | Audit trail |
| Average processing time | < 30 seconds | Performance logs |
| User satisfaction | > 4.0/5.0 | App Store reviews |

---

## 🚨 Risk Assessment

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| API changes | High | Medium | Version locking, fallback to old model |
| Credit calculation errors | Critical | Low | Extensive testing, audit logging |
| UI/UX confusion | Medium | Medium | User testing, tooltips, help text |
| Performance issues | Medium | Low | Image compression, loading states |
| Backend costs | High | Medium | Rate limiting, usage monitoring |

---

## 🔄 Rollback Plan

If implementation causes issues:

1. **Database Rollback**
   ```sql
   -- Run rollback script from migration 091
   ```

2. **Edge Function Rollback**
   ```bash
   # Revert to previous version
   git revert [commit-hash]
   supabase functions deploy submit-job
   ```

3. **iOS Rollback**
   - Feature flag to disable new flow
   - Revert to ChatView if needed
   - Deploy hotfix via TestFlight

---

## 📞 Next Steps

**IMMEDIATE:**
1. ✅ Implementation plan created
2. ⏳ **WAITING FOR: API documentation for both models**
3. Once received: Complete API parameter mapping section
4. Once mapping complete: Begin Phase 2 (Database Changes)

**After API Docs Received:**
- Update this document with exact API parameters
- Create detailed curl test scripts
- Update iOS models to match API exactly
- Begin implementation with full confidence

---

## 📝 Notes

- This plan assumes both models accept similar parameters
- Actual implementation may vary based on API documentation
- All code snippets are templates pending API docs
- Credit costs may need adjustment based on actual usage
- Consider A/B testing pro model pricing

---

**Status:** ⏳ Waiting for API Documentation
**Next Action:** Receive and analyze fal.ai API docs for both models
**Estimated Total Time:** 13-15 hours (once API docs received)

---

*Document will be updated as API documentation is received and implementation progresses.*
