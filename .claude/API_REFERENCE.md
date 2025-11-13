# API Reference

Complete documentation of all API endpoints, request/response formats, and integration patterns.

## Edge Functions

### `process-image`

Main AI image processing endpoint. Handles all image transformations using fal.ai models.

**Endpoint:** `POST /functions/v1/process-image`

**Authentication:**
- Authenticated users: `Authorization: Bearer <jwt_token>`
- Anonymous users: `Authorization: Bearer <anon_key>` + `device-id: <device_id>` header

**Request Body:**
```typescript
{
  image_url: string;           // Required: URL of image to process
  prompt: string;              // Required: Processing prompt/instruction
  device_id?: string;          // Optional: For anonymous users
  user_id?: string;            // Optional: For authenticated users (auto-extracted from JWT)
  is_premium?: boolean;       // Optional: Premium status (server validates)
  client_request_id?: string; // Optional: For idempotency (auto-generated if not provided)
}
```

**Response:**
```typescript
{
  success: boolean;
  processed_image_url?: string;  // URL of processed image
  job_id?: string;              // Database job ID for tracking
  error?: string;               // Error message if failed
  quota_info?: {
    credits: number;
    quota_used: number;
    quota_limit: number;
    quota_remaining: number;
    is_premium: boolean;
  };
}
```

**Error Codes:**
- `400`: Missing required fields (image_url, prompt)
- `401`: Authentication failed
- `403`: Quota exceeded
- `429`: Rate limit exceeded
- `500`: Server error (processing failed, database error)

**Processing Flow:**
1. Validate request (image_url, prompt)
2. Authenticate user (JWT or anonymous)
3. Check quota (5/day free, 3/day premium)
4. Call fal.ai API with model
5. Upload result to Supabase Storage
6. Save to `processed_images` table
7. Update quota usage
8. Return processed image URL

**Idempotency:**
- Uses `client_request_id` to prevent duplicate processing
- Same request ID returns cached result (if available)
- Auto-generates UUID if not provided

**Timeout:**
- Maximum processing time: 60 seconds
- fal.ai API timeout: 35 seconds
- Returns error if timeout exceeded

---

## Supabase Client APIs

### Authentication

**Sign In:**
```swift
func signIn(email: String, password: String) async throws
```

**Sign Up:**
```swift
func signUp(email: String, password: String) async throws
```

**Sign Out:**
```swift
func signOut() async throws
```

**Get Current User:**
```swift
func getCurrentUser() -> User?
```

**Get Current Session:**
```swift
func getCurrentSession() async throws -> Session?
```

### Storage

**Upload Image:**
```swift
func uploadImageToStorage(
    imageData: Data, 
    fileName: String? = nil
) async throws -> String
```
Returns: Public URL of uploaded image

**Download Image:**
```swift
func downloadImage(path: String) async throws -> Data
```

**Delete Image:**
```swift
func deleteImage(path: String) async throws
```

### Database Queries

**Get Quota:**
```swift
func getQuota(userId: String) async throws -> QuotaInfo
```

**Get Processed Images:**
```swift
func getProcessedImages(
    limit: Int = 50,
    offset: Int = 0
) async throws -> [ProcessedImage]
```

**Get User Profile:**
```swift
func getUserProfile() async throws -> UserProfile?
```

---

## Subscription APIs

### StoreKit 2 (Native iOS)

**Load Products:**
```swift
func loadProducts() async throws -> [Product]
```

**Purchase Product:**
```swift
func purchase(_ product: Product) async throws -> Transaction
```

**Check Subscription Status:**
```swift
func checkSubscriptionStatus() async throws -> SubscriptionStatus
```

**Restore Purchases:**
```swift
func restorePurchases() async throws
```

### Adapty (Analytics)

**Get Profile:**
```swift
func getProfile() async throws -> AdaptyProfile
```

**Sync Subscription:**
- Automatic via webhook
- Edge function: `sync-subscription`
- Updates `subscriptions` table

---

## Request/Response Examples

### Process Image (Authenticated)

**Request:**
```bash
curl -X POST https://your-project.supabase.co/functions/v1/process-image \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "image_url": "https://example.com/image.jpg",
    "prompt": "Remove background cleanly",
    "client_request_id": "unique-request-id-123"
  }'
```

**Response:**
```json
{
  "success": true,
  "processed_image_url": "https://your-project.supabase.co/storage/v1/object/public/noname-banana-images-prod/user123/processed_abc123.jpg",
  "job_id": "550e8400-e29b-41d4-a716-446655440000",
  "quota_info": {
    "credits": 0,
    "quota_used": 1,
    "quota_limit": 5,
    "quota_remaining": 4,
    "is_premium": false
  }
}
```

### Process Image (Anonymous)

**Request:**
```bash
curl -X POST https://your-project.supabase.co/functions/v1/process-image \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "device-id: device-uuid-123" \
  -H "Content-Type: application/json" \
  -d '{
    "image_url": "https://example.com/image.jpg",
    "prompt": "Upscale image 2x"
  }'
```

---

## Rate Limiting

### Free Users
- **Limit:** 5 requests per day
- **Reset:** Midnight UTC
- **Tracking:** `daily_quota` table

### Premium Users
- **Limit:** 3 requests per day (temporary)
- **Reset:** Midnight UTC
- **Tracking:** `daily_quota` table with `is_premium = true`

### Anonymous Users
- **Limit:** 5 requests per day
- **Tracking:** `device_id` in `daily_quota` table
- **Reset:** Midnight UTC

---

## Error Handling

### Client-Side Error Handling

```swift
do {
    let result = try await supabaseService.processImage(
        imageURL: imageURL,
        prompt: prompt,
        toolID: toolID
    )
    // Handle success
} catch SupabaseError.quotaExceeded {
    // Show paywall
} catch SupabaseError.networkError {
    // Retry logic
} catch {
    // Generic error handling
}
```

### Server-Side Error Handling

```typescript
try {
    // Processing logic
} catch (error) {
    console.error('Processing error:', error);
    return new Response(
        JSON.stringify({ 
            success: false, 
            error: error.message 
        }),
        { status: 500, headers: corsHeaders }
    );
}
```

---

## Webhooks

### Adapty Webhook

**Endpoint:** `POST /functions/v1/sync-subscription`

**Payload:**
```json
{
  "event": "subscription_updated",
  "profile_id": "adapty_profile_id",
  "subscription": {
    "status": "active",
    "expires_at": "2024-12-31T23:59:59Z",
    "product_id": "weekly_pro",
    "original_transaction_id": "apple_transaction_id"
  }
}
```

**Action:** Updates `subscriptions` table with latest subscription status

---

## CORS Configuration

All Edge Functions support CORS with the following headers:

```
Access-Control-Allow-Origin: *
Access-Control-Allow-Headers: authorization, x-client-info, apikey, content-type, device-id
Access-Control-Allow-Methods: POST, OPTIONS
```

---

## Environment Variables

**Required in Edge Functions:**
- `SUPABASE_URL`: Supabase project URL
- `SUPABASE_SERVICE_ROLE_KEY`: Service role key (for admin operations)
- `FAL_KEY`: fal.ai API key

**Set via CLI:**
```bash
supabase secrets set FAL_KEY=your-fal-key
supabase secrets set SUPABASE_URL=your-url
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your-service-key
```

