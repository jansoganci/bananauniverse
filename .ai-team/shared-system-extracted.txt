# Shared Systems Documentation

**Generated:** 2025-11-11
**Project:** Video Generation Platform
**Version:** 1.0

---

## Table of Contents

1. [Authentication System](#1-authentication-system)
2. [Credit / Quota System](#2-credit--quota-system)
3. [AI Request System](#3-ai-request-system)
4. [External API Integrations](#4-external-api-integrations)
5. [File Upload System](#5-file-upload-system)
6. [Configuration System](#6-configuration-system)
7. [Error Monitoring / Logging](#7-error-monitoring--logging)
8. [Shared Utilities](#8-shared-utilities)
9. [Database Schema](#9-database-schema)
10. [Risk Assessment](#10-risk-assessment)

---

## 1. Authentication System

### Overview
The platform uses a **device-based guest authentication** system with optional Apple Sign-In upgrade. This allows users to start using the app immediately without registration, then optionally upgrade to a full account.

### How It Works

#### Step-by-Step Flow

1. **App Launch - Device Check**
   - App generates device token using Apple DeviceCheck API
   - Sends device_id and device_token to backend
   - Backend verifies with Apple and creates/fetches user

2. **Guest User Creation**
   - First-time users automatically get guest account
   - User identified by device_id (UUID)
   - Receives initial credit grant

3. **Apple Sign-In (Optional Upgrade)**
   - User can upgrade guest account to Apple account
   - Guest account merges with Apple ID
   - Credits and history preserved

4. **Session Management**
   - Device credentials stored locally
   - No explicit login required on subsequent launches
   - Backend validates device_id on each request

### Flow Diagram

```
┌──────────┐
│  User    │
│ Launches │
│   App    │
└────┬─────┘
     │
     v
┌────────────────────────────────────┐
│ iOS: Generate DeviceCheck Token   │
│ (Apple API validates real device)  │
└────────────┬───────────────────────┘
             │
             v
┌─────────────────────────────────────┐
│ POST /device-check                  │
│ Body: {device_id, device_token}     │
└─────────────┬───────────────────────┘
              │
              v
┌──────────────────────────────────────┐
│ Backend: Verify with Apple           │
│ - Check token validity               │
│ - Lookup user by device_id           │
└──────────────┬───────────────────────┘
               │
         ┌─────┴──────┐
         │            │
     NEW USER     EXISTING USER
         │            │
         v            v
┌─────────────┐  ┌──────────────┐
│ Create User │  │ Return User  │
│ - device_id │  │ - user_id    │
│ - 10 credits│  │ - credits    │
│ - is_guest  │  │ - settings   │
└─────┬───────┘  └──────┬───────┘
      │                 │
      └────────┬────────┘
               │
               v
      ┌────────────────┐
      │  User Stored   │
      │  Locally       │
      └────────────────┘

Optional Apple Sign-In Flow:
┌──────────────────┐
│  User Taps       │
│ "Sign In Apple"  │
└────────┬─────────┘
         │
         v
┌─────────────────────────┐
│ iOS: Apple Auth Dialog  │
│ - User authorizes       │
│ - Returns apple_sub     │
└────────┬────────────────┘
         │
         v
┌──────────────────────────┐
│ Call merge-guest-to-user │
│ {device_id, apple_sub}   │
└────────┬─────────────────┘
         │
         v
┌────────────────────────┐
│ Backend: Merge Accounts│
│ - Preserve credits     │
│ - Update is_guest=false│
│ - Link apple_sub       │
└────────────────────────┘
```

### Key Files

**iOS Client:**
- `AuthService.swift` - Handles Apple Sign-In flow
- `OnboardingService.swift` - Device check and user creation
- `DeviceCheckService.swift` - Apple DeviceCheck token generation

**Backend:**
- `supabase/functions/device-check/index.ts` - Device verification endpoint

### Dependencies

- **Apple DeviceCheck API** - Device validation
- **Apple Sign-In** - Optional account upgrade
- **Supabase Auth** - Session management (not fully implemented yet)
- **iOS Keychain** - Secure credential storage (planned)

### Security Considerations

**Current Implementation:**
- Device validation through Apple DeviceCheck
- Unique device_id per installation
- Apple sub verification on sign-in

**Missing/Risky:**
- No Keychain implementation yet (credentials in UserDefaults)
- No session expiration mechanism
- Merge endpoint not fully implemented (marked Phase 2)
- No rate limiting on device-check endpoint
- Device tokens not rotated

---

## 2. Credit / Quota System

### Overview
A prepaid credit system where users spend credits to generate videos. Credits are managed atomically to prevent race conditions and double-spending.

### How It Works

#### Step-by-Step Flow

1. **Credit Balance Check**
   - User balance stored in `users.credits_remaining`
   - Frontend fetches balance before operations
   - Backend enforces balance before deduction

2. **Credit Deduction (Atomic)**
   - Uses PostgreSQL stored procedure `deduct_credits`
   - Row-level locking prevents race conditions
   - All-or-nothing operation

3. **Credit Addition**
   - From IAP purchase verification
   - From admin grants
   - From refunds on failures

4. **Audit Trail**
   - All transactions logged in `quota_log` table
   - Includes balance_after for verification
   - Transaction IDs prevent duplicates

### Flow Diagram

```
Video Generation Request:
┌──────────────────────┐
│ User Submits Request │
│ (prompt, settings)   │
└──────────┬───────────┘
           │
           v
┌────────────────────────────┐
│ Calculate Cost             │
│ - Based on model pricing   │
│ - Duration multiplier      │
│ - Base price + variables   │
└────────────┬───────────────┘
             │
             v
┌─────────────────────────────────────┐
│ Call RPC: generate_video_atomic     │
│ - Check credits >= cost             │
│ - Deduct credits (WITH LOCK)        │
│ - Create video job                  │
│ - Log transaction                   │
│ - Store idempotency record          │
│ ALL IN ONE TRANSACTION              │
└─────────────┬───────────────────────┘
              │
        ┌─────┴──────┐
        │            │
    SUCCESS      INSUFFICIENT
        │            │
        v            v
┌───────────┐  ┌─────────────┐
│ Credits   │  │ Return 402  │
│ Deducted  │  │ Error       │
│ Job       │  │ No Deduction│
│ Created   │  └─────────────┘
└─────┬─────┘
      │
      v
┌──────────────────┐
│ Submit to AI     │
│ Provider         │
└─────┬────────────┘
      │
  ┌───┴────┐
  │        │
SUCCESS  FAIL
  │        │
  v        v
┌───┐  ┌────────────┐
│OK │  │ REFUND     │
└───┘  │ Credits    │
       │ Back       │
       └────────────┘

IAP Purchase Flow:
┌────────────────────┐
│ User Buys Credits  │
│ (iOS In-App)       │
└──────────┬─────────┘
           │
           v
┌──────────────────────────┐
│ iOS: Purchase Complete   │
│ - Returns transaction_id │
└──────────┬───────────────┘
           │
           v
┌────────────────────────────────┐
│ POST /update-credits           │
│ {transaction_id, product_id}   │
└────────────┬───────────────────┘
             │
             v
┌─────────────────────────────────┐
│ Verify with Apple               │
│ - Check transaction validity    │
│ - Get product_id from Apple     │
│ - Map to credit amount          │
└─────────────┬───────────────────┘
              │
              v
┌──────────────────────────────────┐
│ Call RPC: add_credits            │
│ - Check transaction_id uniqueness│
│ - Add to credits_remaining       │
│ - Add to credits_total           │
│ - Log with transaction_id        │
└──────────────────────────────────┘
```

### Key Files

**iOS Client:**
- `CreditService.swift` - Fetch and check credits
- `StoreKitManager.swift` - IAP purchase handling

**Backend:**
- `generate-video/credit-service.ts` - Deduct/refund operations
- `update-credits/index.ts` - IAP credit grants
- `migrations/20251105000002_create_stored_procedures.sql` - Atomic operations

**Database:**
- `deduct_credits(user_id, amount, reason)` - Stored procedure
- `add_credits(user_id, amount, reason, transaction_id)` - Stored procedure

### Dependencies

- PostgreSQL row-level locking (`SELECT FOR UPDATE`)
- Supabase RPC functions
- Apple IAP verification (planned)

### Pricing Model

**Pricing Types:**
1. **Fixed** - Same cost regardless of settings
2. **Duration-based** - Cost scales with video length
3. **Variable** - Complex pricing based on multiple factors

**Example Calculation:**
```
Model: Sora 2 (duration-based)
Base Price: $0.40
Duration: 8 seconds
Cost = $0.40 * (8/4) = $0.80
Credits = 8 (at $0.10 per credit)
```

### Security Considerations

**Current Implementation:**
- Atomic operations prevent double-spending
- Row-level locking prevents race conditions
- Transaction IDs prevent duplicate IAP credits
- Idempotency keys prevent duplicate generations

**Missing/Risky:**
- IAP verification uses mock data (Phase 0.5 incomplete)
- No rate limiting on credit operations
- No fraud detection for suspicious patterns
- No maximum credit limit
- Credits never expire (could be exploited)

---

## 3. AI Request System

### Overview
Orchestrates video generation requests to external AI providers (currently FalAI). Handles job submission, status polling, and result retrieval.

### How It Works

#### Step-by-Step Flow

1. **Request Validation**
   - Validate required fields (prompt, settings)
   - Check model requirements
   - Verify idempotency key

2. **Cost Calculation**
   - Calculate based on model pricing
   - Apply duration multiplier
   - Convert to credits

3. **Atomic Operation**
   - Deduct credits
   - Create job record
   - Store idempotency

4. **Provider Submission**
   - Submit to FalAI queue API
   - Store provider_job_id
   - Update job status

5. **Status Polling**
   - Client polls /get-video-status
   - Backend checks FalAI status
   - Updates local job status

6. **Result Retrieval**
   - When complete, fetch video URL
   - Store in job record
   - Return to client

### Flow Diagram

```
Complete Video Generation Flow:
┌─────────────────────────────────────────────┐
│ 1. CLIENT: POST /generate-video             │
│    Headers: Idempotency-Key                 │
│    Body: {user_id, theme_id, prompt,        │
│           image_url, settings}              │
└────────────────┬────────────────────────────┘
                 │
                 v
┌─────────────────────────────────────────────┐
│ 2. BACKEND: Validate Request                │
│    - Check HTTP method                      │
│    - Validate idempotency key (UUID)        │
│    - Parse JSON body                        │
│    - Validate required fields               │
└────────────────┬────────────────────────────┘
                 │
                 v
┌─────────────────────────────────────────────┐
│ 3. BACKEND: Check Idempotency               │
│    - Query idempotency_log table            │
│    - If found: Return cached response       │
│    - If not found: Continue                 │
└────────────────┬────────────────────────────┘
                 │
                 v
┌─────────────────────────────────────────────┐
│ 4. BACKEND: Fetch Model & Theme             │
│    - Get active model from DB               │
│    - Get theme details                      │
│    - Validate model requirements            │
│      (prompt? image? settings?)             │
└────────────────┬────────────────────────────┘
                 │
                 v
┌─────────────────────────────────────────────┐
│ 5. BACKEND: Build Settings & Calculate Cost│
│    - Merge user settings + model defaults   │
│    - Calculate cost based on pricing_type   │
│      * Fixed: base_price                    │
│      * Duration: base * (duration/4)        │
│    - Convert dollars to credits ($0.10/cr)  │
└────────────────┬────────────────────────────┘
                 │
                 v
┌─────────────────────────────────────────────┐
│ 6. BACKEND: Atomic Operation                │
│    RPC: generate_video_atomic               │
│    - Lock user row                          │
│    - Check credits >= cost                  │
│    - Deduct credits                         │
│    - Create video_jobs row                  │
│    - Create quota_log entry                 │
│    - Create idempotency_log entry           │
│    COMMIT (all or nothing)                  │
└────────────────┬────────────────────────────┘
                 │
                 v
┌─────────────────────────────────────────────┐
│ 7. BACKEND: Submit to FalAI                 │
│    POST https://queue.fal.run/{model_id}    │
│    Headers: Authorization: Key {api_key}    │
│    Body: {prompt, image_url, resolution,    │
│           aspect_ratio, duration}           │
│    Returns: {request_id, status}            │
└────────────────┬────────────────────────────┘
                 │
            ┌────┴─────┐
            │          │
        SUCCESS      FAIL
            │          │
            v          v
   ┌────────────┐  ┌──────────────────┐
   │ Update Job │  │ Mark Job Failed  │
   │ - provider │  │ - error_message  │
   │   _job_id  │  │ - status=failed  │
   │ - status=  │  │ REFUND Credits   │
   │   process  │  │ Return 502       │
   └─────┬──────┘  └──────────────────┘
         │
         v
┌─────────────────────────────────────────────┐
│ 8. BACKEND: Return Response                 │
│    {job_id, status: "pending",              │
│     credits_used}                           │
└────────────────┬────────────────────────────┘
                 │
                 v
┌─────────────────────────────────────────────┐
│ 9. CLIENT: Poll Status                      │
│    Loop every 3-5 seconds:                  │
│    GET /get-video-status?job_id={uuid}      │
└────────────────┬────────────────────────────┘
                 │
                 v
┌─────────────────────────────────────────────┐
│ 10. BACKEND: Check FalAI Status             │
│     GET https://queue.fal.run/{model}/      │
│         requests/{request_id}/status        │
│     Parse response:                         │
│     - IN_QUEUE → status: processing         │
│     - IN_PROGRESS → status: processing      │
│     - COMPLETED → fetch video URL           │
│     - FAILED → mark failed                  │
└────────────────┬────────────────────────────┘
                 │
          ┌──────┴──────┐
          │             │
      COMPLETED    PROCESSING/FAILED
          │             │
          v             │
┌──────────────────┐    │
│ Get Final Result │    │
│ - video.url      │    │
│ - video metadata │    │
│ Update job:      │    │
│ - video_url      │    │
│ - status=        │    │
│   completed      │    │
└────────┬─────────┘    │
         │              │
         └──────┬───────┘
                │
                v
┌─────────────────────────────────────────────┐
│ 11. CLIENT: Receive Status                  │
│     If completed: Show video                │
│     If processing: Continue polling         │
│     If failed: Show error                   │
└─────────────────────────────────────────────┘
```

### Key Files

**iOS Client:**
- `VideoGenerationService.swift` - Submit generation request
- `ResultService.swift` - Poll status
- `HistoryService.swift` - Fetch job history

**Backend:**
- `generate-video/index.ts` - Main orchestration
- `generate-video/provider-service.ts` - Provider abstraction
- `generate-video/cost-calculator.ts` - Pricing logic
- `get-video-status/index.ts` - Status polling endpoint
- `_shared/falai-adapter.ts` - FalAI API wrapper

### Dependencies

- **FalAI Queue API** - Video generation provider
- **Supabase Database** - Job storage and status
- **Idempotency System** - Prevent duplicate submissions

### AI Provider Integration

**Currently Supported:**
- FalAI (Sora 2 model)

**API Endpoints:**
1. Submit: `POST https://queue.fal.run/{model_id}`
2. Status: `GET https://queue.fal.run/{model}/requests/{id}/status`
3. Result: `GET https://queue.fal.run/{model}/requests/{id}/response`

**Request Format:**
```json
{
  "prompt": "video description",
  "image_url": "https://...",
  "resolution": "auto" | "720p",
  "aspect_ratio": "auto" | "9:16" | "16:9",
  "duration": 4 | 8 | 12
}
```

**Status Mapping:**
- FalAI `IN_QUEUE` → Internal `processing`
- FalAI `IN_PROGRESS` → Internal `processing`
- FalAI `COMPLETED` → Internal `completed`
- FalAI `FAILED` → Internal `failed`

### Settings System

**Resolution:**
- `auto` - Provider chooses
- `720p` - Standard definition

**Aspect Ratio:**
- `auto` - Based on input image
- `9:16` - Portrait (mobile)
- `16:9` - Landscape (desktop)

**Duration:**
- 4 seconds - Cheapest
- 8 seconds - Medium
- 12 seconds - Most expensive

### Security Considerations

**Current Implementation:**
- Idempotency prevents duplicate submissions
- Atomic credit deduction
- Provider job ID tracking
- Request validation

**Missing/Risky:**
- No timeout on long-running jobs
- No automatic cleanup of stale jobs
- API key stored in plain env variable
- No rate limiting per user
- No content moderation on prompts
- Video URLs not secured (public FalAI URLs)
- No webhook validation if provider supports callbacks

---

## 4. External API Integrations

### Overview
The platform integrates with three main external services: FalAI (video generation), Apple IAP (payments), and Apple DeviceCheck (device validation).

### 4.1 FalAI Integration

**Purpose:** AI video generation provider

**Endpoints Used:**
- Submit Job: `POST https://queue.fal.run/{model_id}`
- Check Status: `GET https://queue.fal.run/{model}/requests/{id}/status`
- Get Result: `GET https://queue.fal.run/{model}/requests/{id}/response`

**Authentication:**
```typescript
Headers: {
  'Authorization': 'Key {FALAI_API_KEY}',
  'Content-Type': 'application/json'
}
```

**Error Handling:**
- Network errors → Refund credits
- Invalid model → 404 error
- Rate limits → Not handled yet

**Configuration:**
```env
FALAI_API_KEY=GET_FROM_FAL_AI_DASHBOARD
```

### 4.2 Apple IAP Integration

**Purpose:** In-app purchase verification

**Current Status:** Mock implementation (Phase 0.5 incomplete)

**Planned Implementation:**
- Apple App Store Server API v2
- JWS signature verification
- Transaction status validation
- Product ID extraction

**Product Configuration:**
```typescript
PRODUCT_CONFIG = {
  'com.rendio.credits.10': 10,
  'com.rendio.credits.50': 50,
  'com.rendio.credits.100': 100
}
```

**Configuration Needed:**
```env
APPLE_BUNDLE_ID=com.rendioai.app
APPLE_TEAM_ID=GET_FROM_APPLE_DEVELOPER
APPLE_KEY_ID=GET_FROM_APPLE_DEVELOPER
APPLE_ISSUER_ID=GET_FROM_APPLE_DEVELOPER
APPLE_PRIVATE_KEY=GET_FROM_APPLE_DEVELOPER
```

### 4.3 Apple DeviceCheck Integration

**Purpose:** Device fraud prevention

**How It Works:**
1. iOS app generates device token
2. Backend sends token to Apple
3. Apple validates device authenticity
4. Backend trusts device

**Configuration Needed:**
```env
APPLE_DEVICECHECK_KEY_ID=GET_FROM_APPLE_DEVELOPER
APPLE_DEVICECHECK_PRIVATE_KEY=GET_FROM_APPLE_DEVELOPER
```

### Integration Flow Diagram

```
┌─────────────┐
│   Client    │
│   (iOS)     │
└──────┬──────┘
       │
       │ 1. Generate Video Request
       v
┌──────────────────────────┐
│   Backend               │
│   (Supabase Functions)   │
└──────┬───────────────────┘
       │
       │ 2. Submit to FalAI
       v
┌──────────────────────┐     ┌────────────────┐
│   FalAI Queue API    │────>│  Sora 2 Model  │
│   queue.fal.run      │<────│  (Generates)   │
└──────┬───────────────┘     └────────────────┘
       │ 3. Return request_id
       v
┌──────────────────────────┐
│   Backend               │
│   Stores provider_job_id │
└──────┬───────────────────┘
       │
       │ 4. Poll Status
       v
┌──────────────────────┐
│   FalAI Status API   │
│   Returns: processing│
│   or completed       │
└──────────────────────┘

Parallel: IAP Purchase Flow
┌─────────────┐
│   Client    │
│ (StoreKit)  │
└──────┬──────┘
       │ 1. Purchase
       v
┌──────────────────────┐
│   Apple App Store    │
│   Returns: trans_id  │
└──────┬───────────────┘
       │ 2. Verify
       v
┌──────────────────────────┐
│   Backend               │
│   (Planned: Call Apple)  │
└──────┬───────────────────┘
       │ 3. Grant Credits
       v
┌──────────────────────────┐
│   Database              │
│   add_credits()         │
└─────────────────────────┘

Parallel: Device Check Flow
┌─────────────┐
│   Client    │
│ (DeviceCheck)│
└──────┬──────┘
       │ 1. Generate Token
       v
┌──────────────────────────┐
│   Backend               │
└──────┬───────────────────┘
       │ 2. Verify Token
       v
┌──────────────────────┐
│  Apple DeviceCheck   │
│  API (Validates)     │
└──────────────────────┘
```

### API Rate Limits

**FalAI:**
- Not documented in code
- Should implement retry with backoff

**Apple:**
- DeviceCheck: Not specified
- IAP Verification: Should cache results

### Error Handling

**Network Errors:**
```typescript
try {
  const result = await fetch(url)
} catch (error) {
  // Log error
  // Refund credits if applicable
  // Return user-friendly message
}
```

**API Errors:**
- 4xx → User error (invalid request)
- 5xx → Provider error (retry?)
- Timeout → No handling yet

### Security Considerations

**Current Issues:**
- API keys in plain environment variables
- No key rotation mechanism
- FalAI responses not validated for tampering
- Video URLs publicly accessible
- No webhook signature verification

**Recommendations:**
- Use secrets manager (e.g., Supabase Vault)
- Implement webhook signatures
- Add response validation
- Proxy video URLs through own CDN
- Implement retry with exponential backoff

---

## 5. File Upload System

### Overview
Handles image uploads for image-to-video generation. Uses Supabase Storage with public bucket access.

### How It Works

#### Step-by-Step Flow

1. **User Selects Image**
   - iOS picker or camera
   - Image loaded into memory

2. **Image Preparation**
   - Convert to JPEG format
   - Compress to 80% quality
   - Generate unique filename

3. **Upload to Storage**
   - POST to Supabase Storage API
   - Path: `thumbnails/{user_id}/{filename}.jpg`
   - Returns storage path

4. **Generate Public URL**
   - Construct public URL
   - Return to caller

5. **Use in Generation**
   - Pass URL to video generation
   - Provider fetches from public URL

### Flow Diagram

```
┌────────────────────┐
│ User Picks Image   │
│ (UIImagePicker)    │
└─────────┬──────────┘
          │
          v
┌─────────────────────────────┐
│ Convert to JPEG             │
│ - Compression: 0.8          │
│ - Format: image/jpeg        │
└─────────┬───────────────────┘
          │
          v
┌─────────────────────────────┐
│ Generate Filename           │
│ input_{UUID}.jpg            │
│ Path: {user_id}/{filename}  │
└─────────┬───────────────────┘
          │
          v
┌─────────────────────────────────────────┐
│ POST {supabase}/storage/v1/object/      │
│      thumbnails/{user_id}/{filename}    │
│ Headers:                                │
│   - Authorization: Bearer {anon_key}    │
│   - apikey: {anon_key}                  │
│   - Content-Type: image/jpeg            │
│ Body: {image_data}                      │
└─────────┬───────────────────────────────┘
          │
          v
┌─────────────────────────────┐
│ Storage: Save File          │
│ Bucket: thumbnails          │
│ Path: user_id/filename      │
└─────────┬───────────────────┘
          │
          v
┌─────────────────────────────────────────┐
│ Construct Public URL                    │
│ {supabase}/storage/v1/object/public/    │
│ thumbnails/{user_id}/{filename}         │
└─────────┬───────────────────────────────┘
          │
          v
┌─────────────────────────────┐
│ Return URL to Client        │
│ https://...supabase.co/...  │
└─────────┬───────────────────┘
          │
          v
┌─────────────────────────────┐
│ Store URL in Request        │
│ (used by video generation)  │
└─────────────────────────────┘
```

### Key Files

**iOS Client:**
- `ImageUploadService.swift` - Upload implementation

**Backend:**
- `migrations/20251105000004_create_storage_buckets.sql` - Bucket setup
- `migrations/20251106000007_allow_anonymous_image_uploads.sql` - Permissions

### Storage Configuration

**Bucket:** `thumbnails`

**Access Policy:**
- Public read (anyone can view)
- Authenticated write (anon key required)
- No file size limit set
- No file type restrictions

**File Naming:**
```
Format: input_{UUID}.jpg
Example: input_a1b2c3d4-e5f6-7890-abcd-ef1234567890.jpg
Path: {user_id}/input_{UUID}.jpg
```

### Compression Settings

```swift
let imageData = image.jpegData(compressionQuality: 0.8)
```

**Why 0.8?**
- Balance between quality and size
- Typical 5MB image → ~500KB
- Fast upload over cellular

### Security Considerations

**Current Implementation:**
- Public read access (necessary for AI provider)
- Anonymous uploads allowed
- User ID namespace prevents collisions

**Missing/Risky:**
- No file size limit (could be abused)
- No image validation (could upload anything)
- No content moderation (NSFW check)
- No virus scanning
- Files never deleted (storage cost grows)
- No rate limiting on uploads
- Public URLs never expire
- No compression on server side

**Recommendations:**
- Add file size limit (e.g., 10MB)
- Validate image format server-side
- Implement content moderation API
- Add cleanup job for old uploads
- Consider CDN for faster access
- Add rate limiting per user

---

## 6. Configuration System

### Overview
Centralized configuration management for both iOS client and backend services. Uses environment variables and platform-specific config files.

### iOS Configuration

#### AppConfig.swift

**Purpose:** Central configuration for iOS app

**Features:**
- Environment detection (dev/staging/prod)
- Info.plist value reading
- Fallback values
- Validation at startup

**Configuration Sources:**
1. Info.plist (from .xcconfig files)
2. Build configuration (#if DEBUG)
3. Hardcoded fallbacks

**Key Values:**
```swift
AppConfig.supabaseURL          // Backend URL
AppConfig.supabaseAnonKey      // Public API key
AppConfig.apiTimeout           // Request timeout
AppConfig.maxRetryAttempts     // Retry logic
AppConfig.enableLogging        // Debug logs
AppConfig.enableDebugMode      // Debug features
AppConfig.isDevelopment        // Environment check
```

**Environment Detection:**
```swift
enum AppEnvironment {
    case development  // DEBUG builds
    case staging      // TestFlight
    case production   // App Store
}
```

**Validation:**
```swift
AppConfig.validate()  // Call at app launch
// Throws error if:
// - supabaseURL missing
// - supabaseAnonKey missing
// - URL not HTTPS
```

### Backend Configuration

#### .env File

**Location:** `RendioAI/.env` (gitignored)

**Template:** `RendioAI/.env.example`

**Categories:**

1. **Supabase Configuration**
```env
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGc...
SUPABASE_SERVICE_ROLE_KEY=eyJhbGc...
```

2. **Apple Credentials**
```env
APPLE_BUNDLE_ID=com.rendioai.app
APPLE_TEAM_ID=XXXXXXXXXX
APPLE_KEY_ID=XXXXXXXXXX
APPLE_ISSUER_ID=xxx-xxx-xxx
APPLE_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----\n...
APPLE_DEVICECHECK_KEY_ID=XXXXXXXXXX
APPLE_DEVICECHECK_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----\n...
```

3. **AI Provider API Keys**
```env
FALAI_API_KEY=xxx
RUNWAY_API_KEY=xxx  # Optional
PIKA_API_KEY=xxx    # Optional
```

4. **Environment Settings**
```env
ENVIRONMENT=development
DEBUG=true
WEBHOOK_SECRET=xxx
```

5. **Feature Flags**
```env
ENABLE_WEBHOOKS=false
ENABLE_RATE_LIMITING=false
ENABLE_ADMIN_TOOLS=false
```

### Configuration Flow

```
Development:
┌──────────────┐
│ Developer    │
└──────┬───────┘
       │
       v
┌─────────────────────┐
│ .env.example        │
│ (Template in repo)  │
└──────┬──────────────┘
       │ Copy & fill
       v
┌─────────────────────┐
│ .env                │
│ (Local, gitignored) │
└──────┬──────────────┘
       │
       v
┌─────────────────────┐
│ Supabase CLI        │
│ (Reads .env)        │
└──────┬──────────────┘
       │
       v
┌─────────────────────┐
│ Edge Functions      │
│ Deno.env.get(...)   │
└─────────────────────┘

Production:
┌──────────────┐
│ Supabase     │
│ Dashboard    │
└──────┬───────┘
       │ Set secrets
       v
┌─────────────────────┐
│ Environment         │
│ Variables (Secured) │
└──────┬──────────────┘
       │
       v
┌─────────────────────┐
│ Edge Functions      │
│ Deno.env.get(...)   │
└─────────────────────┘
```

### Usage in Code

**Backend (TypeScript):**
```typescript
const apiKey = Deno.env.get('FALAI_API_KEY')
const environment = Deno.env.get('ENVIRONMENT') || 'development'
const debug = Deno.env.get('DEBUG') === 'true'
```

**iOS (Swift):**
```swift
let url = AppConfig.supabaseURL
let key = AppConfig.supabaseAnonKey
let timeout = AppConfig.apiTimeout
```

### Security Considerations

**Current Implementation:**
- .env file gitignored
- Separate keys for anon vs service role
- Private keys stored as env variables

**Missing/Risky:**
- No secrets rotation mechanism
- Private keys in plain text
- No key expiration
- Service role key very powerful
- No environment-specific keys
- Hardcoded fallbacks in AppConfig (security risk)

**Recommendations:**
- Use Supabase Vault for secrets
- Implement key rotation
- Remove hardcoded fallbacks
- Use different keys per environment
- Add secrets scanning in CI/CD
- Encrypt sensitive values at rest

---

## 7. Error Monitoring / Logging

### Overview
Structured logging system for tracking events, errors, and debugging. Uses JSON format for easy parsing and analysis.

### Logging System

#### Backend Logger

**File:** `_shared/logger.ts`

**Purpose:** Structured event logging for Edge Functions

**Features:**
- JSON formatted output
- Log levels (info, warn, error)
- Timestamp inclusion
- Environment tagging
- Key-value data structure

**Usage:**
```typescript
import { logEvent } from '../_shared/logger.ts'

logEvent('video_generation_started', {
  user_id: 'xxx',
  job_id: 'yyy',
  model_id: 'zzz'
}, 'info')

logEvent('provider_api_error', {
  error: 'Connection timeout',
  provider: 'fal'
}, 'error')
```

**Output Format:**
```json
{
  "timestamp": "2025-11-11T10:30:45.123Z",
  "level": "info",
  "event": "video_generation_started",
  "user_id": "xxx",
  "job_id": "yyy",
  "model_id": "zzz",
  "environment": "development"
}
```

### iOS Error Handling

**File:** `AppError.swift`

**Error Types:**
```swift
enum AppError: LocalizedError {
    case networkFailure
    case networkTimeout
    case invalidResponse
    case insufficientCredits
    case unauthorized
    case invalidDevice
    case userNotFound
    case networkError(String)
    case unknown(String)
}
```

**Usage:**
```swift
throw AppError.insufficientCredits
throw AppError.networkError("Connection failed")
```

**Localization:**
- Error keys mapped to localized strings
- Format: `"error.category.type"`
- Example: `"error.network.timeout"`

### Logging Events

**Common Events:**
- `user_created` - New user registration
- `device_check_success` - Device validation passed
- `device_check_failed` - Device validation failed
- `video_generation_started` - Job submitted
- `falai_job_submitted` - Provider accepted job
- `video_generation_completed` - Job finished
- `video_generation_failed` - Job failed
- `idempotent_replay` - Duplicate request detected
- `generate_video_insufficient_credits` - Not enough credits
- `provider_api_error` - External API error

### Flow Diagram

```
Application Event:
┌─────────────────┐
│ Event Occurs    │
│ (e.g., API call)│
└────────┬────────┘
         │
         v
┌─────────────────────────┐
│ logEvent() Called       │
│ - event type            │
│ - data object           │
│ - level                 │
└────────┬────────────────┘
         │
         v
┌─────────────────────────┐
│ Build Log Entry         │
│ {timestamp, level,      │
│  event, data,           │
│  environment}           │
└────────┬────────────────┘
         │
         v
┌─────────────────────────┐
│ console.log(JSON)       │
│ (Deno stdout)           │
└────────┬────────────────┘
         │
         v
┌─────────────────────────┐
│ Supabase Logs           │
│ (Dashboard → Logs)      │
└─────────────────────────┘

Error Handling:
┌─────────────────┐
│ Error Occurs    │
│ (try/catch)     │
└────────┬────────┘
         │
         v
┌─────────────────────────┐
│ Log Error               │
│ logEvent(..., 'error')  │
└────────┬────────────────┘
         │
         v
┌─────────────────────────┐
│ Return Error Response   │
│ {error: "message"}      │
│ HTTP 4xx/5xx            │
└────────┬────────────────┘
         │
         v
┌─────────────────────────┐
│ Client Receives Error   │
│ - Shows user message    │
│ - Logs locally (iOS)    │
└─────────────────────────┘
```

### Log Analysis

**Current Viewing:**
- Supabase Dashboard → Logs tab
- Filter by function
- Search by text
- Time range selection

**No Advanced Analytics:**
- No log aggregation
- No alerting system
- No error tracking service
- No performance monitoring
- No user session tracking

### Security Considerations

**Current Implementation:**
- Logs include user_id for tracking
- Error messages sanitized
- No sensitive data logged

**Missing/Risky:**
- Logs may contain PII
- No log retention policy
- No log encryption
- No access control on logs
- API keys might leak in errors
- No anomaly detection

**Recommendations:**
- Integrate error tracking (e.g., Sentry)
- Add PII filtering
- Implement log retention
- Set up alerts for critical errors
- Add performance monitoring (APM)
- Track user flows for debugging

---

## 8. Shared Utilities

### Overview
Reusable code components used across the application.

### Backend Utilities

#### 8.1 Idempotency Service

**File:** `generate-video/idempotency-service.ts`

**Purpose:** Prevent duplicate operations

**Functions:**
- `checkIdempotency()` - Check if request seen before
- `storeIdempotencyRecord()` - Cache response

**How It Works:**
1. Client sends `Idempotency-Key` header (UUID)
2. Backend checks `idempotency_log` table
3. If found: Return cached response
4. If not found: Process and store result

**TTL:** 24 hours (automatic cleanup)

#### 8.2 Cost Calculator

**File:** `generate-video/cost-calculator.ts`

**Purpose:** Calculate video generation cost

**Pricing Types:**
- Fixed: Same cost always
- Duration-based: Cost * (duration / 4)
- Variable: Complex formula

**Output:**
```typescript
{
  costInDollars: 0.80,
  creditsToDeduct: 8,
  duration: 8
}
```

#### 8.3 Validators

**File:** `generate-video/validators.ts`

**Functions:**
- `validateHttpMethod()` - Only allow POST
- `validateIdempotencyKey()` - UUID format check
- `validateRequiredFields()` - Presence check
- `validateModelRequirements()` - Model-specific validation

#### 8.4 Database Service

**File:** `generate-video/database-service.ts`

**Functions:**
- `fetchActiveModel()` - Get current active AI model
- `fetchTheme()` - Get theme settings
- `createVideoJob()` - Insert job record
- `updateVideoJob()` - Update job status

### iOS Utilities

#### 8.5 UserDefaultsManager

**File:** `UserDefaultsManager.swift`

**Purpose:** Local storage wrapper

**Stored Data:**
- `currentUserId` - Active user UUID
- User preferences
- App settings

**Usage:**
```swift
UserDefaultsManager.shared.currentUserId = "xxx"
let userId = UserDefaultsManager.shared.currentUserId
```

#### 8.6 StorageService

**File:** `StorageService.swift`

**Purpose:** Persistent data storage (likely file system)

#### 8.7 LocalizationManager

**File:** `LocalizationManager.swift`

**Purpose:** Multi-language support

**Supported Languages:**
- English (en)
- Turkish (tr)
- Spanish (es)

### Shared Components (iOS UI)

#### 8.8 PrimaryButton

**File:** `PrimaryButton.swift`

**Purpose:** Reusable styled button

#### 8.9 UI Extensions

**File:** `UIApplication+Extensions.swift`

**Purpose:** Helper methods for UIApplication

### Utility Flow

```
Request Processing Flow:
┌────────────────────┐
│ Request Arrives    │
└──────┬─────────────┘
       │
       v
┌────────────────────┐
│ Validators         │
│ - HTTP method      │
│ - Idempotency key  │
│ - Required fields  │
└──────┬─────────────┘
       │
       v
┌────────────────────┐
│ Idempotency Check  │
│ - Query DB         │
│ - Return if cached │
└──────┬─────────────┘
       │
       v
┌────────────────────┐
│ Database Service   │
│ - Fetch model      │
│ - Fetch theme      │
└──────┬─────────────┘
       │
       v
┌────────────────────┐
│ Cost Calculator    │
│ - Pricing logic    │
│ - Convert to $     │
└──────┬─────────────┘
       │
       v
┌────────────────────┐
│ Process Request    │
└────────────────────┘
```

### Security Considerations

**Current Implementation:**
- Input validation before processing
- Idempotency prevents duplicates
- Database functions encapsulate queries

**Missing/Risky:**
- No input sanitization (SQL injection risk low due to parameterized queries)
- No rate limiting utilities
- No request size limits
- UserDefaults not encrypted (iOS)
- No data migration utilities

---

## 9. Database Schema

### Overview
PostgreSQL database schema with 5 main tables plus utility tables.

### Tables

#### 9.1 users
**Purpose:** User accounts and credits

**Fields:**
- `id` (UUID, PK) - User identifier
- `email` (TEXT, nullable) - For registered users
- `device_id` (TEXT, nullable) - For guest users
- `apple_sub` (TEXT, nullable) - Apple Sign-In ID
- `is_guest` (BOOLEAN) - Guest vs registered
- `tier` (TEXT) - free | premium
- `credits_remaining` (INTEGER) - Current balance
- `credits_total` (INTEGER) - Lifetime total
- `initial_grant_claimed` (BOOLEAN) - First-time bonus
- `language` (TEXT) - en | tr | es
- `theme_preference` (TEXT) - system | light | dark
- `is_admin` (BOOLEAN) - Admin flag
- `created_at` (TIMESTAMPTZ)
- `updated_at` (TIMESTAMPTZ)

**Constraints:**
- Unique: `device_id` (if not null)
- Unique: `apple_sub` (if not null)
- Check: email OR device_id must exist

**Indexes:**
- `idx_users_device_id` - Fast device lookup
- `idx_users_apple_sub` - Fast Apple ID lookup

#### 9.2 models
**Purpose:** AI model configurations

**Fields:**
- `id` (UUID, PK)
- `name` (TEXT) - Display name
- `category` (TEXT) - Model category
- `description` (TEXT)
- `cost_per_generation` (INTEGER) - Legacy field
- `provider` (TEXT) - fal | runway | pika
- `provider_model_id` (TEXT) - External model ID
- `is_featured` (BOOLEAN)
- `is_available` (BOOLEAN)
- `thumbnail_url` (TEXT)
- `pricing_type` (TEXT) - fixed | duration | variable
- `base_price` (NUMERIC) - Base cost in dollars
- `required_fields` (JSONB) - Model requirements
- `created_at` (TIMESTAMPTZ)

**Constraints:**
- Check: provider in allowed list

**Indexes:**
- `idx_models_provider`
- `idx_models_featured`
- `idx_models_available`

#### 9.3 video_jobs
**Purpose:** Video generation job tracking

**Fields:**
- `job_id` (UUID, PK)
- `user_id` (UUID, FK→users)
- `model_id` (UUID, FK→models)
- `prompt` (TEXT)
- `settings` (JSONB) - Generation settings
- `status` (TEXT) - pending | processing | completed | failed
- `video_url` (TEXT)
- `thumbnail_url` (TEXT)
- `credits_used` (INTEGER)
- `error_message` (TEXT)
- `provider_job_id` (TEXT) - External job ID
- `created_at` (TIMESTAMPTZ)
- `completed_at` (TIMESTAMPTZ)

**Constraints:**
- Check: status in allowed list
- FK: CASCADE delete on user
- FK: RESTRICT delete on model

**Indexes:**
- `idx_video_jobs_user` - User's jobs by date
- `idx_video_jobs_status` - Jobs by status
- `idx_video_jobs_provider` - Lookup by provider ID

#### 9.4 quota_log
**Purpose:** Credit transaction audit trail

**Fields:**
- `id` (UUID, PK)
- `user_id` (UUID, FK→users)
- `job_id` (UUID, FK→video_jobs, nullable)
- `change` (INTEGER) - Positive or negative
- `reason` (TEXT) - Description
- `transaction_id` (TEXT, nullable) - IAP transaction
- `balance_after` (INTEGER) - Balance after transaction
- `created_at` (TIMESTAMPTZ)

**Constraints:**
- Unique: `transaction_id` (if not null) - Prevent duplicate IAP
- FK: CASCADE delete on user
- FK: SET NULL on job delete

**Indexes:**
- `idx_quota_log_user` - User's transactions by date
- `idx_quota_log_transaction` - Lookup by IAP transaction

#### 9.5 idempotency_log
**Purpose:** Prevent duplicate requests

**Fields:**
- `idempotency_key` (UUID, PK)
- `user_id` (UUID, FK→users)
- `job_id` (UUID, FK→video_jobs, nullable)
- `operation_type` (TEXT) - Operation name
- `response_data` (JSONB) - Cached response
- `status_code` (INTEGER) - HTTP status
- `created_at` (TIMESTAMPTZ)
- `expires_at` (TIMESTAMPTZ) - Auto-cleanup after 24h

**Constraints:**
- FK: CASCADE delete on user

**Indexes:**
- `idx_idempotency_user`
- `idx_idempotency_expires` - For cleanup job

#### 9.6 themes
**Purpose:** Predefined generation themes

**Fields:**
- `id` (UUID, PK)
- `name` (TEXT)
- `description` (TEXT)
- `category` (TEXT)
- `default_prompt` (TEXT)
- `default_settings` (JSONB)
- `thumbnail_url` (TEXT)
- `is_available` (BOOLEAN)
- `created_at` (TIMESTAMPTZ)

### Stored Procedures

#### 9.7 deduct_credits
**Purpose:** Atomically deduct credits

**Parameters:**
- `p_user_id` (UUID)
- `p_amount` (INTEGER)
- `p_reason` (TEXT)

**Returns:** JSONB
```json
{
  "success": true,
  "credits_remaining": 42
}
```

**Logic:**
1. Lock user row (`SELECT FOR UPDATE`)
2. Check sufficient credits
3. Deduct amount
4. Insert quota_log entry
5. Return new balance

#### 9.8 add_credits
**Purpose:** Atomically add credits

**Parameters:**
- `p_user_id` (UUID)
- `p_amount` (INTEGER)
- `p_reason` (TEXT)
- `p_transaction_id` (TEXT, optional)

**Returns:** JSONB
```json
{
  "success": true,
  "credits_added": 10,
  "credits_remaining": 52
}
```

**Logic:**
1. Check transaction_id uniqueness (prevent duplicates)
2. Add to credits_remaining and credits_total
3. Insert quota_log entry with transaction_id
4. Return new balance

#### 9.9 generate_video_atomic
**Purpose:** Atomically deduct credits and create job

**Parameters:**
- `p_user_id` (UUID)
- `p_model_id` (UUID)
- `p_prompt` (TEXT)
- `p_settings` (JSONB)
- `p_idempotency_key` (UUID)

**Returns:** JSONB
```json
{
  "job_id": "xxx",
  "credits_used": 8,
  "status": "pending"
}
```

**Logic:** (All in one transaction)
1. Check idempotency
2. Get model cost
3. Lock user row
4. Check credits >= cost
5. Deduct credits
6. Create video_jobs row
7. Create quota_log entry
8. Store idempotency record
9. Return job details

### Storage Buckets

#### 9.10 thumbnails
**Purpose:** User-uploaded images

**Access:**
- Public read
- Authenticated write (anon key)

**Structure:**
```
thumbnails/
  {user_id}/
    input_{uuid}.jpg
    input_{uuid}.jpg
    ...
```

### Relationships

```
users (1) ──< (many) video_jobs
users (1) ──< (many) quota_log
users (1) ──< (many) idempotency_log

models (1) ──< (many) video_jobs

video_jobs (1) ──< (0..1) quota_log
video_jobs (1) ──< (0..1) idempotency_log

themes (1) ──< (many) video_jobs (referenced, not FK)
```

### Database Diagram

```
┌──────────────────────┐
│       users          │
│──────────────────────│
│ id (PK)              │
│ email                │
│ device_id (UNIQUE)   │
│ apple_sub (UNIQUE)   │
│ credits_remaining    │
│ credits_total        │
│ ...                  │
└──────────┬───────────┘
           │
           │ 1:N
           v
┌──────────────────────┐        ┌──────────────────┐
│    video_jobs        │ N:1    │     models       │
│──────────────────────│────────│──────────────────│
│ job_id (PK)          │        │ id (PK)          │
│ user_id (FK)         │        │ name             │
│ model_id (FK)        │        │ provider         │
│ prompt               │        │ base_price       │
│ status               │        │ pricing_type     │
│ video_url            │        │ ...              │
│ provider_job_id      │        └──────────────────┘
│ credits_used         │
│ ...                  │
└──────────┬───────────┘
           │
           │ 1:1
           v
┌──────────────────────┐
│    quota_log         │
│──────────────────────│
│ id (PK)              │
│ user_id (FK)         │
│ job_id (FK)          │
│ change (+/-)         │
│ transaction_id       │
│ balance_after        │
│ ...                  │
└──────────────────────┘

┌──────────────────────┐
│  idempotency_log     │
│──────────────────────│
│ idempotency_key (PK) │
│ user_id (FK)         │
│ job_id (FK)          │
│ response_data        │
│ expires_at           │
└──────────────────────┘

┌──────────────────────┐
│       themes         │
│──────────────────────│
│ id (PK)              │
│ name                 │
│ default_prompt       │
│ default_settings     │
│ ...                  │
└──────────────────────┘
```

### Migration Files

**Order:**
1. `20251105000001_create_tables.sql` - Core tables
2. `20251105000002_create_stored_procedures.sql` - RPC functions
3. `20251105000003_enable_rls_policies.sql` - Row Level Security
4. `20251105000004_create_storage_buckets.sql` - File storage
5. `20251105000005_fix_users_constraints.sql` - Data integrity
6. `20251106000003_create_themes_table.sql` - Themes table
7. `20251108000002_create_atomic_generate_video.sql` - Atomic RPC
8. `20251108000003_enable_realtime_subscriptions.sql` - Realtime

### Security Considerations

**Current Implementation:**
- Row Level Security (RLS) policies
- Foreign key constraints
- Check constraints
- Unique constraints
- Stored procedures with SECURITY DEFINER
- Row-level locking for credits

**Missing/Risky:**
- No audit logging (who changed what)
- No soft deletes (data permanently lost)
- No data encryption at rest
- Service role key bypasses RLS
- No field-level permissions
- Credits never expire
- No maximum credit limit
- Jobs never archived

**Recommendations:**
- Implement audit trigger on sensitive tables
- Add soft delete with deleted_at column
- Enable database encryption
- Review RLS policies regularly
- Add job archival after 90 days
- Implement credit expiration
- Add maximum balance limits

---

## 10. Risk Assessment

### Critical Issues

#### 1. Apple IAP Verification Not Implemented
**Risk Level:** HIGH

**Issue:**
- IAP verification uses mock data
- Anyone can claim credits without paying
- Transaction validation bypassed

**Impact:**
- Revenue loss
- Fraud vulnerability
- No payment audit trail

**Recommendation:**
- Implement Apple App Store Server API v2
- Verify JWS signatures
- Validate transaction status
- Test with sandbox environment

**Priority:** IMMEDIATE

---

#### 2. No Keychain Implementation
**Risk Level:** MEDIUM-HIGH

**Issue:**
- Credentials stored in UserDefaults
- Device ID in plain text
- Apple tokens not secured

**Impact:**
- Device jailbreak exposes credentials
- User account hijacking possible
- Violation of security best practices

**Recommendation:**
- Migrate to iOS Keychain
- Use kSecAttrAccessibleAfterFirstUnlock
- Implement proper error handling

**Priority:** HIGH

---

#### 3. Public Storage with No Validation
**Risk Level:** MEDIUM-HIGH

**Issue:**
- No file size limits
- No content type validation
- No NSFW filtering
- Files never deleted

**Impact:**
- Storage cost explosion
- Inappropriate content hosted
- Malware distribution possible
- Bandwidth abuse

**Recommendation:**
- Add 10MB file size limit
- Validate image format server-side
- Implement content moderation
- Add cleanup job for old files

**Priority:** HIGH

---

#### 4. No Rate Limiting
**Risk Level:** MEDIUM

**Issue:**
- No request throttling
- No per-user limits
- No API abuse prevention

**Impact:**
- DDoS vulnerability
- Cost explosion from FalAI calls
- Service degradation
- Credit farming attacks

**Recommendation:**
- Implement rate limiting middleware
- Add per-user quotas (e.g., 10 req/min)
- Add per-IP limits
- Monitor unusual patterns

**Priority:** MEDIUM-HIGH

---

#### 5. Hardcoded Configuration
**Risk Level:** MEDIUM

**Issue:**
- Supabase URL/keys hardcoded
- Fallback values in code
- No secrets rotation

**Impact:**
- Keys exposed in app binary
- No environment separation
- Key leakage if decompiled

**Recommendation:**
- Remove hardcoded values
- Use Supabase Vault for secrets
- Implement key rotation
- Separate keys per environment

**Priority:** MEDIUM

---

### Security Best Practices Missing

#### 1. Error Monitoring
**Issue:** No centralized error tracking
**Recommendation:** Integrate Sentry or similar

#### 2. Content Moderation
**Issue:** No prompt or image filtering
**Recommendation:** Add OpenAI Moderation API

#### 3. Webhook Security
**Issue:** No webhook signature verification
**Recommendation:** Implement HMAC validation

#### 4. Job Timeouts
**Issue:** Jobs can hang indefinitely
**Recommendation:** Add 10-minute timeout

#### 5. Data Retention
**Issue:** Data never deleted
**Recommendation:** GDPR compliance, 90-day archival

---

### Performance Concerns

#### 1. No Caching
**Issue:** Repeated DB queries for same data
**Recommendation:** Add Redis/Memcached

#### 2. No CDN
**Issue:** Video URLs served directly from FalAI
**Recommendation:** Proxy through CloudFront/Cloudflare

#### 3. No Query Optimization
**Issue:** Some queries could be optimized
**Recommendation:** Add database indexes, query analysis

---

### Code Quality Issues

#### 1. Mock Implementations
**Locations:**
- `AuthService.swift` - Phase 2 placeholders
- `apple-iap-verifier.ts` - Mock verification
- `OnboardingService.swift` - Commented TODOs

**Recommendation:** Complete Phase 2 implementations

#### 2. Error Handling Inconsistencies
**Issue:** Mix of throws and error returns
**Recommendation:** Standardize error handling

#### 3. No Unit Tests
**Issue:** No test coverage visible
**Recommendation:** Add unit and integration tests

---

### Dependencies

**External Services:**
1. FalAI (video generation) - Single point of failure
2. Apple Services (auth, IAP, DeviceCheck) - Required
3. Supabase (database, storage, functions) - Critical

**Risks:**
- No fallback provider for video generation
- FalAI downtime stops all generations
- No cost monitoring for FalAI usage

**Recommendation:**
- Add provider abstraction (multi-provider support)
- Implement circuit breaker pattern
- Add cost alerts

---

### Compliance Concerns

#### 1. GDPR
**Issues:**
- No data deletion mechanism
- No user data export
- No privacy policy endpoint

**Recommendation:**
- Add user data deletion API
- Implement data export
- Privacy policy in app

#### 2. PCI DSS
**Issue:** IAP handling (Apple handles payments, but verify compliance)
**Recommendation:** Document payment flow

#### 3. Terms of Service
**Issue:** No TOS acceptance tracking
**Recommendation:** Add TOS version field to users table

---

### Summary

**System Health:** MODERATE - Core functionality works but lacks production hardening

**Critical Gaps:**
1. IAP verification (revenue risk)
2. Keychain security (data exposure)
3. Rate limiting (abuse/cost)
4. File validation (security/cost)

**Next Steps:**
1. Complete Apple IAP implementation (Phase 0.5)
2. Add rate limiting across all endpoints
3. Implement Keychain for iOS credentials
4. Add file size and type validation
5. Set up error monitoring (Sentry)
6. Add comprehensive logging
7. Implement job timeouts
8. Add data retention policies

**Estimated Effort:**
- Critical issues: 2-3 weeks
- Medium issues: 1-2 weeks
- Nice-to-have: Ongoing

---

## Appendix: Key Technical Decisions

### Why Device-Based Auth?
- Frictionless onboarding
- No password management
- Fast time-to-value
- Optional upgrade path

### Why Atomic Stored Procedures?
- Prevent race conditions
- Ensure credit consistency
- Audit trail integrity
- Simplify client code

### Why Idempotency Keys?
- Prevent double-charging
- Handle network retries safely
- Improve reliability

### Why FalAI?
- Sora 2 model access
- Queue-based API
- Reasonable pricing
- Image-to-video support

### Why Supabase?
- PostgreSQL database
- Built-in auth
- Storage included
- Edge Functions (Deno)
- Real-time subscriptions

---

**End of Documentation**
