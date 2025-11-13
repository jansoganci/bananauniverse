# Phase 2: iOS Migration - Webhook Architecture (CORRECTED)

**CRITICAL CHANGE**: We are pivoting from polling to **webhooks** for massive cost savings (80-90% reduction).

**Problem with original plan**: Polling costs $400-500/month. Webhooks cost $50-100/month.

**Solution**: Use fal.ai webhooks → Supabase Edge Function → Database → iOS fetches result.

---

## Architecture Comparison

### ❌ OLD (Polling - Expensive):
```
iOS → submit-job → fal.ai
iOS → check-status (every 2s) → fal.ai
iOS → check-status (every 3s) → fal.ai
iOS → check-status (every 4.5s) → fal.ai
...repeat 5-10 times...
```
**Cost**: 5-10 Edge Function calls per job = $400/month at scale

### ✅ NEW (Webhooks - Cheap):
```
iOS → submit-job (with webhookUrl) → fal.ai
fal.ai processes...
fal.ai → webhook-handler → Database stores result
iOS → get-result (once) → Database
```
**Cost**: 2-3 Edge Function calls per job = $50/month at scale

---

## Task Breakdown (12 Tasks → 10 Tasks)

### ~~Task 1-5: DISCARD (Polling-related)~~
- ~~Create polling models~~
- ~~Add polling methods~~
- ~~Add polling config~~

### NEW Task 1: Create Webhook Models (15 min, Zero Risk)

**What to create**:
1. `BananaUniverse/Core/Models/SubmitJobResponse.swift` (~30 lines)
2. `BananaUniverse/Core/Models/GetResultResponse.swift` (~25 lines)

**SubmitJobResponse**:
```swift
struct SubmitJobResponse: Decodable {
    let success: Bool
    let jobId: String        // fal.ai request_id
    let estimatedTime: Int?  // Estimated completion time (seconds)
    let quotaInfo: QuotaInfo?
    let error: String?
}
```

**GetResultResponse**:
```swift
struct GetResultResponse: Decodable {
    let success: Bool
    let status: String       // pending | completed | failed
    let imageURL: String?    // When completed
    let error: String?
}
```

---

### NEW Task 2: Add Backend Methods to SupabaseService (30 min, Low Risk)

**What to add**:
1. `submitImageJob(imageURL:prompt:) async throws -> SubmitJobResponse`
   - Calls Edge Function `submit-job-webhook`
   - Edge Function submits to fal.ai WITH webhookUrl parameter

2. `getJobResult(jobId:) async throws -> GetResultResponse`
   - Calls Edge Function `get-result`
   - Checks database for completed result

**No polling methods needed!**

---

### NEW Task 3: Create Backend Webhook Handler (Backend, 1 hour)

**Create**: `supabase/functions/webhook-handler/index.ts`

**What it does**:
1. Receives POST from fal.ai when job completes
2. Validates webhook signature (security)
3. Downloads processed image from fal.ai
4. Uploads to Supabase Storage
5. Stores result in `job_results` table:
   ```sql
   CREATE TABLE job_results (
       fal_job_id TEXT PRIMARY KEY,
       status TEXT,
       image_url TEXT,
       error TEXT,
       completed_at TIMESTAMPTZ
   );
   ```

**fal.ai calls**:
```
POST https://jiorfutbmahpfgplkats.supabase.co/functions/v1/webhook-handler
Body: {
  "request_id": "abc-123",
  "status": "COMPLETED",
  "images": [{"url": "https://fal.ai/result.jpg"}]
}
```

---

### NEW Task 4: Update submit-job to Use Webhooks (Backend, 30 min)

**Modify**: `supabase/functions/submit-job/index.ts`

**Add webhookUrl parameter**:
```typescript
const falResponse = await fetch('https://queue.fal.run/fal-ai/nano-banana/edit', {
  method: 'POST',
  headers: {
    'Authorization': `Key ${falAIKey}`,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    prompt: prompt,
    image_urls: [image_url],
    num_images: 1,
    output_format: 'jpeg',
    // NEW: Tell fal.ai where to send result
    webhook_url: `${SUPABASE_URL}/functions/v1/webhook-handler`
  }),
});
```

**That's it!** fal.ai will call our webhook when done.

---

### NEW Task 5: Create get-result Edge Function (Backend, 30 min)

**Create**: `supabase/functions/get-result/index.ts`

**What it does**:
```typescript
// Check database for completed result
const { data, error } = await supabase
  .from('job_results')
  .select('*')
  .eq('fal_job_id', jobId)
  .single();

if (data?.status === 'completed') {
  return { success: true, status: 'completed', imageURL: data.image_url };
} else if (data?.status === 'failed') {
  return { success: true, status: 'failed', error: data.error };
} else {
  return { success: true, status: 'pending' };
}
```

---

### Task 6: Add Feature Flag (5 min, Zero Risk)

**Same as before** - Add to `Config.swift`:
```swift
static let useAsyncWebhooks: Bool = false
```

---

### Task 7: Add processImageAsync (Webhook Version) (30 min, Low Risk)

**Add to ChatViewModel**:
```swift
private func processImageAsync(_ image: UIImage) async {
    do {
        // Step 1: Upload image
        let imageURL = try await supabaseService.uploadImageToStorage(imageData: imageData)

        // Step 2: Submit job (fal.ai will call webhook when done)
        let submitResult = try await supabaseService.submitImageJob(
            imageURL: imageURL,
            prompt: prompt
        )

        currentJobID = submitResult.jobId
        let estimatedTime = submitResult.estimatedTime ?? 20

        // Step 3: Wait estimated time, then check result
        try await Task.sleep(nanoseconds: UInt64(estimatedTime * 1_000_000_000))

        // Step 4: Get result from database (webhook should have stored it)
        let result = try await supabaseService.getJobResult(jobId: submitResult.jobId)

        if result.status == "completed", let imageURL = result.imageURL {
            // Download and display image
            let (imageData, _) = try await URLSession.shared.data(from: URL(string: imageURL)!)
            processedImage = UIImage(data: imageData)
        } else if result.status == "pending" {
            // Webhook hasn't fired yet, check again in 5s (fallback)
            try await Task.sleep(nanoseconds: 5_000_000_000)
            let retryResult = try await supabaseService.getJobResult(jobId: submitResult.jobId)
            // Handle retry...
        }
    } catch {
        // Error handling
    }
}
```

**No polling loop!** Just wait → check once → done.

---

### Task 8: Route with Feature Flag (10 min)

**Same as before**:
```swift
private func processImage(_ image: UIImage) async {
    if Config.useAsyncWebhooks {
        await processImageAsync(image)
        return
    }
    // Old synchronous code...
}
```

---

### Task 9: Local Testing (2 hours)

**Test with ngrok** (for local webhook testing):
```bash
# Terminal 1: Start Supabase
supabase start

# Terminal 2: Expose webhook to internet
ngrok http 54321

# Use ngrok URL for webhookUrl in submit-job
webhook_url: "https://abc123.ngrok.io/functions/v1/webhook-handler"
```

**Test flow**:
1. Set `useAsyncWebhooks = true`
2. Submit job
3. Wait for webhook to fire
4. Fetch result
5. Verify image displays

---

### Task 10: Deploy to Production (30 min)

**Deploy all three functions**:
```bash
supabase functions deploy submit-job
supabase functions deploy webhook-handler
supabase functions deploy get-result
```

**Set environment variables**:
```bash
FAL_AI_API_KEY=your-key
ENABLE_JOB_HISTORY=true
```

---

### Task 11: TestFlight with Flag OFF (30 min)

**Deploy iOS with `useAsyncWebhooks = false`**
- Old code runs
- New code is present but disabled
- Safe rollout

---

### Task 12: Enable Webhooks Gradually

**10% rollout**:
```swift
static var useAsyncWebhooks: Bool {
    let userId = AuthService.shared.currentUser?.id ?? ""
    let hash = abs(userId.hashValue) % 100
    return hash < 10  // 10% get webhooks
}
```

**Monitor for 48 hours**, then 100% if stable.

---

## Cost Comparison

### Polling (What We Almost Built):
- 100 jobs/day
- 5-10 polls per job = 500-1,000 invocations
- **$400-500/month** at 1M+ invocations

### Webhooks (What We're Building):
- 100 jobs/day
- 1 submit + 1 webhook + 1 get-result = 300 invocations
- **$50-100/month** at 300k invocations

**Savings: $350-400/month (80-90% reduction)**

---

## Summary of Changes

| Old Plan (Polling) | New Plan (Webhooks) |
|-------------------|---------------------|
| iOS polls every 2-10s | fal.ai calls webhook |
| 5-10 Edge Function calls | 2-3 Edge Function calls |
| Complex exponential backoff | Simple: wait → check once |
| $400/month | $50/month |
| ~~PollingConfig~~ | No config needed |
| ~~pollJobStatus~~ | Just getJobResult |
| ~~CheckStatusResponse~~ | GetResultResponse |

---

## Architecture Diagram

```
┌─────────┐
│   iOS   │
└────┬────┘
     │ 1. Submit job (with webhook URL)
     ▼
┌─────────────────┐
│  submit-job     │
│  Edge Function  │
└────┬────────────┘
     │ 2. POST to fal.ai queue (with webhookUrl)
     ▼
┌─────────────────┐
│    fal.ai       │ 3. Processes image (20-30s)
└────┬────────────┘
     │ 4. POST to webhook when done
     ▼
┌─────────────────┐
│ webhook-handler │ 5. Store result in database
│  Edge Function  │
└────┬────────────┘
     │
     ▼
┌─────────────────┐
│   job_results   │
│   (Database)    │
└────┬────────────┘
     │
     ▼
┌─────────────────┐
│   get-result    │ 6. iOS fetches result (once)
│  Edge Function  │
└─────────────────┘
```

---

## What to Delete (Polling Code)

After pivot is complete, delete:
- ❌ `PollingConfig.swift`
- ❌ `JobStatusResult.swift`
- ❌ `CheckStatusResponse.swift`
- ❌ `pollJobStatus()` method
- ❌ `checkJobStatus()` in SupabaseService
- ❌ `check-status` Edge Function

---

## Next Steps

1. **Stop current work** - Don't continue with polling
2. **Read this updated plan** - Understand webhook flow
3. **Start Task 1** - Create webhook models
4. **Continue sequentially** - Tasks 1-12

**Ready to pivot to webhooks?** This will save you $350+/month and is simpler to implement. 🚀
