# 🎬 Video App Transition Audit
## From Image Processing to AI Video Generation

**Date**: 2025-11-02  
**Source System**: BananaUniverse (Image Processing)  
**Target System**: Video Generation App  
**Purpose**: Architectural advisory for transitioning from image-based AI processing to video generation (text-to-video, image-to-video, hybrid)

---

## 📋 Executive Summary

This audit analyzes the existing BananaUniverse image processing architecture and provides a comprehensive roadmap for transitioning to an AI video generation app. The system will support text-to-video, image-to-video animation, and image+text hybrid generation while maintaining the same modular, scalable foundation.

**Key Transition Points**:
- **Reuse**: 70% of architecture (auth, quota, storage patterns, edge functions)
- **Evolve**: 20% of architecture (async job tracking, file handling, progress UI)
- **New**: 10% of architecture (video-specific services, encoding, CDN)

---

## ♻️ Reused Components

### **1. Authentication & User Management**

**Status**: ✅ **100% Reusable**

**What Works**:
- HybridAuthService (anonymous + authenticated users)
- JWT token management
- Session persistence
- User state synchronization

**No Changes Needed**: Video generation uses the same authentication patterns.

---

### **2. Quota Management System**

**Status**: ✅ **90% Reusable** (requires metric adjustment)

**What Works**:
- Database quota tracking (`consume_quota()` function)
- Idempotency protection (request_id)
- Server-side premium validation
- Quota consumption/refund logic

**What Needs Evolution**:
```
Current: Image count (e.g., "3 images per day")
New: Video minutes (e.g., "10 video minutes per day")

Conversion Examples:
- 1 video minute = 5-10 credits (depending on resolution)
- 30-second video = 0.5 minutes
- 2-minute video = 2 minutes
```

**Migration Strategy**:
- Add `video_minutes` column to quota table
- Convert existing credits to minutes (or maintain both)
- Update quota consumption to track minutes instead of counts

---

### **3. Storage Service Pattern**

**Status**: ✅ **80% Reusable** (requires large file handling)

**What Works**:
- Supabase Storage integration
- Signed URL generation
- Path organization (`uploads/{user_id}/{filename}`)
- Storage cleanup functions

**What Needs Evolution**:
- **File Size**: Images (1-10MB) → Videos (50-500MB+)
- **Upload Strategy**: Single upload → Multipart/resumable uploads
- **Storage Tiers**: Add temporary storage for processing, permanent for final output
- **CDN Integration**: Critical for video delivery (range requests, streaming)

---

### **4. Edge Function Orchestration**

**Status**: ✅ **70% Reusable** (requires async pattern)

**What Works**:
- Edge Function structure (Deno, TypeScript)
- Authentication handling
- Quota consumption
- Error handling patterns

**What Needs Evolution**:
```
Current: Synchronous (image processing ~5-30 seconds)
New: Asynchronous (video generation ~2-10 minutes)

Required Changes:
1. Job queue system (background processing)
2. Status polling endpoints
3. Webhook notifications (optional)
4. Progress tracking
5. Cancel/resume functionality
```

---

### **5. Error Handling & Retry Logic**

**Status**: ✅ **90% Reusable**

**What Works**:
- Error taxonomy (hierarchical errors)
- User-friendly error messages
- Network monitoring
- Retry logic patterns

**What Needs Evolution**:
- **Longer Timeouts**: Image (30s) → Video (10+ minutes)
- **Partial Failure Recovery**: Resume failed video jobs
- **Progress Preservation**: Save progress for resume
- **Cancellation Support**: Allow users to cancel long-running jobs

---

### **6. Progress Tracking System**

**Status**: ✅ **60% Reusable** (needs enhancement)

**What Works**:
- `ProcessingJobStatus` enum
- Elapsed time tracking
- Progress callbacks

**What Needs Evolution**:
```
Current: Simple progress (0.0 - 1.0)
New: Granular video progress stages:

1. Upload (0-10%)
2. Queued (10-15%)
3. Processing (15-90%)
   ├── Frame generation (15-60%)
   ├── Encoding (60-85%)
   └── Finalization (85-90%)
4. Complete (90-100%)
```

---

## 🆕 New Required Systems

### **1. Video Generation Service**

**Purpose**: Orchestrate video generation pipeline across multiple AI providers.

**Architecture**:
```
VideoGenerationService (iOS)
  ↓
Edge Function: generate-video
  ├── Job Queue (Redis/BullMQ or Supabase)
  ├── AI Provider Selection (fal.ai, Runway, Pika, etc.)
  ├── Progress Tracking
  ├── Error Recovery
  └── Result Storage
```

**Key Responsibilities**:
- Route requests to appropriate AI provider
- Handle provider failures (fallback)
- Track generation progress
- Manage job lifecycle (create, queue, process, complete, cancel)

**Integration Pattern**:
```typescript
// Edge Function: generate-video
async function generateVideo(request: VideoGenerationRequest) {
  // 1. Consume quota (video minutes)
  const quotaResult = await consumeQuota(userId, request.durationMinutes)
  
  // 2. Create job record
  const jobId = await createJob({
    type: request.type,  // text-to-video, image-to-video, hybrid
    status: 'queued',
    parameters: request.parameters
  })
  
  // 3. Queue for processing
  await queueJob(jobId, request)
  
  // 4. Return job ID (not result - async!)
  return { jobId, estimatedTime: '5-10 minutes' }
}
```

---

### **2. Video Rendering Queue**

**Purpose**: Background job processing with priority and concurrency management.

**Architecture Options**:

**Option A: Supabase + Edge Functions (Recommended for Start)**
```
Supabase Jobs Table
  ├── status: queued, processing, completed, failed
  ├── priority: high, normal, low
  ├── worker_id: which edge function is processing
  └── retry_count: for failed jobs

Edge Function: process-video-queue
  ├── Polls for queued jobs
  ├── Processes with concurrency limit (max 3 per user, 10 global)
  └── Updates status and progress
```

**Option B: Dedicated Queue Service (Scale Later)**
```
Redis/BullMQ
  ├── Job queues (high-priority, normal, low-priority)
  ├── Worker pool (multiple edge functions)
  ├── Rate limiting (per user, per tier)
  └── Dead letter queue (failed jobs)
```

**Key Features**:
- **Priority Queues**: Premium users get priority
- **Concurrency Limits**: Max 3 concurrent jobs per user
- **Retry Logic**: Exponential backoff for failures
- **Cancellation**: Allow users to cancel queued jobs
- **Progress Updates**: Real-time progress to database

---

### **3. Preview & Thumbnail Extraction**

**Purpose**: Generate preview frames and thumbnails for video browsing.

**Implementation**:
```swift
// iOS: Extract thumbnail from video
func extractThumbnail(from videoURL: URL) -> UIImage? {
    let asset = AVAsset(url: videoURL)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    
    // Extract frame at 0.5 seconds
    let time = CMTime(seconds: 0.5, preferredTimescale: 600)
    guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else {
        return nil
    }
    
    return UIImage(cgImage: cgImage)
}

// Server: Generate frame grid (4-9 frames)
func generateFrameGrid(videoURL: String, frameCount: Int = 9) -> [String] {
    // Extract frames at intervals
    // Upload to storage
    // Return URLs
}
```

**Use Cases**:
- Video library thumbnails
- Progress preview (show first few generated frames)
- Share card generation
- Frame-by-frame editing interface

---

### **4. Compression & Encoding Service**

**Purpose**: Optimize video files for storage and delivery.

**Architecture**:
```
Raw Video (from AI provider)
  ├── High-quality MP4 (original, for storage)
  ├── Medium-quality MP4 (for streaming, 1080p)
  ├── Low-quality MP4 (for preview, 720p)
  └── Thumbnail/Poster (for UI)
```

**Implementation Options**:

**Option A: Cloud Encoding (Recommended)**
```
AI Provider Output → Cloud Encoding Service (Mux, Cloudflare Stream, AWS MediaConvert)
  ├── Automatic format negotiation (MP4/WebM based on client)
  ├── Adaptive bitrate streaming (HLS/DASH)
  └── CDN delivery
```

**Option B: Edge Function Encoding (Complex)**
```
FFmpeg in Edge Function (Deno)
  ├── Requires FFmpeg WASM
  ├── Limited by edge function timeout
  └── Not recommended for production
```

**Recommended Approach**:
- Use AI provider's encoding (if available)
- Store original + optimized versions
- Serve via CDN with range requests

---

### **5. CDN & Caching for Large Video Assets**

**Purpose**: Fast, cost-effective video delivery.

**Architecture**:
```
Supabase Storage (Primary)
  ├── Original videos (long retention)
  └── Optimized videos (CDN-cached)

CDN (Cloudflare R2, AWS CloudFront, or Supabase CDN)
  ├── Cached videos (7-30 day TTL)
  ├── Range request support (for streaming)
  └── Geographic distribution
```

**Key Features**:
- **Signed URLs**: Time-limited access (7-30 days)
- **Range Requests**: Support video seeking/streaming
- **Cache Headers**: `Cache-Control: public, max-age=604800`
- **Automatic Format**: Serve MP4 for iOS, WebM for web
- **Bandwidth Optimization**: Adaptive bitrate based on connection

---

### **6. Video Metadata Model**

**Purpose**: Store video properties for queries and UI display.

**Database Schema** (Conceptual):
```sql
CREATE TABLE video_generations (
    id UUID PRIMARY KEY,
    user_id UUID,
    device_id TEXT,
    
    -- Generation parameters
    type TEXT,  -- 'text-to-video', 'image-to-video', 'hybrid'
    prompt TEXT,
    input_image_url TEXT,  -- For image-to-video
    
    -- Video properties
    duration_seconds INTEGER,
    fps INTEGER,  -- 24, 30, 60
    resolution TEXT,  -- '720p', '1080p', '4k'
    format TEXT,  -- 'mp4', 'webm', 'mov'
    file_size_bytes BIGINT,
    
    -- Storage paths
    original_video_url TEXT,
    optimized_video_url TEXT,
    thumbnail_url TEXT,
    frame_grid_urls TEXT[],  -- Array of frame URLs
    
    -- Job tracking
    status TEXT,  -- 'queued', 'processing', 'completed', 'failed'
    progress_percentage INTEGER,
    estimated_time_remaining INTEGER,  -- seconds
    error_message TEXT,
    
    -- Timestamps
    created_at TIMESTAMPTZ,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    
    -- Cost tracking
    credits_consumed INTEGER,
    ai_provider TEXT,  -- 'fal.ai', 'runway', 'pika'
    model_name TEXT
);
```

---

### **7. Async Progress Notifications**

**Purpose**: Real-time updates during long video generation.

**Implementation Options**:

**Option A: Polling (Recommended for Start)**
```swift
// iOS: Poll every 3-5 seconds
func pollVideoStatus(jobId: String) async throws -> VideoStatus {
    let status = try await supabaseService.getVideoJobStatus(jobId)
    
    // Update UI
    updateProgress(status.progressPercentage)
    updateEstimatedTime(status.estimatedTimeRemaining)
    
    if status.status == .completed {
        return status
    }
    
    // Continue polling
    try await Task.sleep(seconds: 3)
    return try await pollVideoStatus(jobId)
}
```

**Option B: WebSockets (Scale Later)**
```
Supabase Realtime
  ├── Subscribe to job status changes
  ├── Real-time progress updates
  └── Push notifications (optional)
```

**Option C: Push Notifications (Best UX)**
```
iOS Push Notifications
  ├── "Your video is ready!"
  ├── "Processing 50% complete"
  └── "Video generation failed"
```

**Recommended Approach**:
- Start with polling (simpler, works immediately)
- Add push notifications for "completed" status
- Consider WebSockets for real-time progress (later)

---

### **8. Error Recovery for Long Jobs**

**Purpose**: Handle failures gracefully during 5-10 minute video generation.

**Recovery Strategies**:

**1. Checkpoint System**:
```
Save progress at key stages:
- Frame generation complete (60%)
- Encoding started (70%)
- Finalization started (90%)

On failure, resume from last checkpoint
```

**2. Partial Result Delivery**:
```
If generation fails at 80%:
- Return partial video (first 80% of frames)
- Allow user to retry or regenerate remaining
```

**3. Automatic Retry**:
```
Failed jobs automatically retry:
- Max 3 retries
- Exponential backoff (5min, 10min, 20min)
- Refund quota if all retries fail
```

**4. Manual Retry**:
```
User can manually retry failed jobs:
- Resume from last checkpoint
- Or start fresh (with new quota)
```

---

### **9. Post-Processing Pipeline**

**Purpose**: Enhance videos with watermarks, captions, soundtracks.

**Pipeline Stages**:
```
1. Watermarking
   ├── Add logo/branding
   ├── Position (bottom-right, corner)
   └── Opacity control

2. Caption Overlay
   ├── Text-to-speech (if needed)
   ├── Subtitle generation
   └── Style customization

3. Soundtrack Merging
   ├── Background music library
   ├── Audio mixing
   └── Volume normalization

4. Color Grading
   ├── Apply filters
   ├── Adjust brightness/contrast
   └── Style presets
```

**Implementation**:
- Use cloud video processing (Mux, Cloudflare Stream, or FFmpeg cloud service)
- Or client-side processing (AVFoundation) for simple operations

---

## 🤖 AI Model Layer

### **Recommended Models & APIs**

#### **1. Text-to-Video**

**Provider Options**:

**A. fal.ai** (Current Provider - Recommended to Start)
- **Model**: `fal-ai/stable-video-diffusion` or `fal-ai/kling-ai`
- **Pros**: 
  - Already integrated
  - Good API documentation
  - Reasonable pricing
- **Cons**: 
  - Limited video length (typically 4-5 seconds)
  - May not support longer videos

**B. Runway Gen-2** (Premium Option)
- **Model**: `runway/gen-2`
- **Pros**:
  - High quality
  - Longer videos (up to 18 seconds)
  - Good motion control
- **Cons**:
  - Expensive ($0.05-0.10 per second)
  - Requires API access

**C. Pika Labs** (Emerging)
- **Model**: `pika/pika-1.5`
- **Pros**:
  - Good quality
  - Competitive pricing
  - Active development
- **Cons**:
  - API may be limited
  - Newer platform

**D. Kling AI** (High Quality)
- **Model**: `fal-ai/kling-ai` or direct API
- **Pros**:
  - Excellent quality
  - Good motion understanding
- **Cons**:
  - May require waitlist
  - Limited API access

**E. Google Veo** (Future)
- **Model**: `google/veo-2` (when available)
- **Pros**:
  - Google infrastructure
  - High quality
- **Cons**:
  - Not yet publicly available
  - May require Google Cloud setup

**Recommendation**: Start with **fal.ai** (already integrated), then add **Runway** as premium option.

---

#### **2. Image-to-Video**

**Provider Options**:

**A. fal.ai** (Recommended)
- **Model**: `fal-ai/stable-video-diffusion`
- **Pros**: 
  - Supports image input
  - Good motion transfer
  - Already integrated
- **Cons**: 
  - Limited duration (4-5 seconds)

**B. Runway Gen-2** (Premium)
- **Model**: `runway/gen-2` with image input
- **Pros**:
  - High quality motion
  - Longer videos
- **Cons**:
  - Expensive

**C. AnimateDiff** (Open Source)
- **Model**: `fal-ai/animatediff`
- **Pros**:
  - Good for character animation
  - Cost-effective
- **Cons**:
  - May require fine-tuning

**Recommendation**: Use **fal.ai** for image-to-video initially, upgrade to **Runway** for premium users.

---

#### **3. Image + Text Hybrid**

**Approach**: Use image-to-video with prompt conditioning.

**Implementation**:
```
Input:
  - Image (base frame)
  - Text prompt (style, motion, narrative)

Processing:
  1. Generate video from image (image-to-video)
  2. Apply text prompt as style guide
  3. Refine motion based on prompt

Output:
  - Stylized video matching both image and text
```

**Provider**: Use **Runway Gen-2** or **fal.ai** with prompt conditioning.

---

### **Model Latency & GPU Cost**

**Typical Latency**:
- **Text-to-Video**: 2-10 minutes (depending on length, resolution)
- **Image-to-Video**: 1-5 minutes (faster, less computation)
- **Hybrid**: 3-12 minutes (more complex)

**Cost Estimates** (per video minute):
- **fal.ai**: $0.01-0.05 per second (~$0.60-3.00 per minute)
- **Runway**: $0.05-0.10 per second (~$3.00-6.00 per minute)
- **Pika**: $0.02-0.04 per second (~$1.20-2.40 per minute)

**Optimization Strategies**:
1. **Caching**: Cache similar prompts (reuse generated videos)
2. **Preview Mode**: Generate low-quality preview first (faster, cheaper)
3. **Tiered Quality**: Free users get 720p, Premium get 1080p/4K
4. **Batch Processing**: Process multiple videos in parallel (for premium)

---

### **Model Caching Strategy**

**Prompt-Based Caching**:
```
Hash user prompt + parameters
If cached video exists:
  - Return immediately (no generation cost)
  - Update quota (minimal, for storage)
Else:
  - Generate new video
  - Cache result
  - Return to user
```

**Benefits**:
- Reduce costs for common prompts
- Faster results for popular requests
- Better user experience

---

## 🎨 Frontend & UX Adjustments

### **1. Progress Indicators**

**Current (Image)**: Simple progress bar (0-100%)

**New (Video)**: Multi-stage progress with time estimates

**UI Design**:
```
┌─────────────────────────────────────┐
│  🎬 Generating Your Video           │
│                                     │
│  Stage: Frame Generation (60%)     │
│  ████████████████░░░░░░░░░░░░░░░   │
│                                     │
│  Estimated time: 3 minutes         │
│  Elapsed: 2m 15s                   │
│                                     │
│  [Cancel] [Background]              │
└─────────────────────────────────────┘
```

**Stages**:
1. **Upload** (0-10%): "Uploading input..."
2. **Queued** (10-15%): "Waiting in queue (position: 3)"
3. **Processing** (15-90%):
   - Frame generation (15-60%)
   - Encoding (60-85%)
   - Finalization (85-90%)
4. **Complete** (90-100%): "Video ready!"

---

### **2. Queue Indicators**

**UI Component**:
```
┌─────────────────────────────────────┐
│  📋 Generation Queue                │
│                                     │
│  1. "A mystical forest" (Processing)│
│  2. "Coffee reading" (Queued)      │
│  3. "Palm reading" (Queued)         │
│                                     │
│  Max 3 concurrent generations     │
└─────────────────────────────────────┘
```

**Features**:
- Show queue position
- Estimated wait time
- Cancel option
- Reorder priority (premium)

---

### **3. Video Preview UI**

**Components Needed**:

**A. Video Player**:
```swift
import AVKit

struct VideoPlayerView: View {
    let videoURL: URL
    
    var body: some View {
        VideoPlayer(player: AVPlayer(url: videoURL))
            .frame(height: 400)
            .cornerRadius(12)
    }
}
```

**B. Scrubber with Thumbnails**:
```
┌─────────────────────────────────────┐
│  [Video Preview]                    │
│                                     │
│  [Play Button]                      │
│                                     │
│  ━━━━━●━━━━━━━━━━━━━━━━━━━━━━━━   │
│  0:00          0:30          1:00  │
│                                     │
│  [Thumbnail Grid]                  │
│  [Frame 1] [Frame 2] [Frame 3] ...  │
└─────────────────────────────────────┘
```

**C. Frame-by-Frame Editing** (Advanced):
- Select frames to regenerate
- Adjust individual frames
- Remove unwanted frames

---

### **4. Parameter Panel**

**UI Design**:
```
┌─────────────────────────────────────┐
│  ⚙️ Video Settings                  │
│                                     │
│  Duration: [15s] [30s] [60s] [2min]│
│                                     │
│  Resolution:                        │
│  ○ 720p (Fast)                     │
│  ● 1080p (Recommended)             │
│  ○ 4K (Premium)                    │
│                                     │
│  FPS: [24] [30] [60]               │
│                                     │
│  Style: [Dropdown]                 │
│  └─ Mystical, Cinematic, ...       │
│                                     │
│  [Advanced Options ▼]              │
│  └─ Motion strength, Seed, ...     │
└─────────────────────────────────────┘
```

**Parameters**:
- **Duration**: 5s, 15s, 30s, 60s, 120s (tier-based)
- **Resolution**: 720p (free), 1080p (standard), 4K (premium)
- **FPS**: 24 (cinematic), 30 (standard), 60 (smooth)
- **Style**: Preset styles (mystical, cinematic, etc.)
- **Motion Strength**: Low, Medium, High
- **Seed**: For reproducibility

---

### **5. Safe User Messaging**

**Long Render Times**:
```
"Video generation typically takes 5-10 minutes. 
We'll notify you when it's ready!"

[Generate in Background] [Stay on Screen]
```

**Queue Wait Times**:
```
"Your video is queued (position 3 of 5).
Estimated wait: 8 minutes."

[Cancel] [Upgrade to Skip Queue]
```

**Failure Handling**:
```
"Video generation failed. This can happen due to:
- Complex prompts
- Network issues
- Service limits

[Retry] [Try Different Prompt] [Contact Support]"
```

---

### **6. Quota Display Adjustment**

**Current (Image)**: "3 images remaining today"

**New (Video)**: "10 video minutes remaining today"

**UI Design**:
```
┌─────────────────────────────────────┐
│  🎬 Video Minutes                   │
│                                     │
│  Used: 3.5 / 10 minutes             │
│  ████████░░░░░░░░░░░░░░░░░░░░░░░░░ │
│                                     │
│  Recent:                            │
│  • "Mystical forest" (30s)          │
│  • "Coffee reading" (15s)           │
│  • "Palm reading" (60s)             │
│                                     │
│  [Upgrade for Unlimited]            │
└─────────────────────────────────────┘
```

**Conversion Examples**:
- 1 video minute = 5-10 credits (depending on resolution)
- 30-second video = 0.5 minutes
- 2-minute video = 2 minutes
- Premium: Unlimited minutes (or 100+ minutes/day)

---

## 💾 Backend & Storage

### **1. Handling Large Uploads/Downloads**

**Current (Image)**: 1-10MB files, single upload

**New (Video)**: 50-500MB+ files, multipart uploads

**Multipart Upload Strategy**:
```
1. Initialize upload (get upload ID)
2. Split file into chunks (5-10MB each)
3. Upload chunks in parallel
4. Complete upload (combine chunks)
5. Verify integrity (checksum)
```

**Implementation**:
```swift
// iOS: Multipart upload
func uploadLargeVideo(data: Data) async throws -> String {
    let chunkSize = 10_000_000  // 10MB
    let chunks = data.chunked(into: chunkSize)
    
    let uploadId = try await initializeMultipartUpload()
    
    var partETags: [String] = []
    for (index, chunk) in chunks.enumerated() {
        let etag = try await uploadChunk(uploadId, partNumber: index + 1, data: chunk)
        partETags.append(etag)
    }
    
    return try await completeMultipartUpload(uploadId, parts: partETags)
}
```

---

### **2. Resumable Transfers**

**Purpose**: Resume failed uploads/downloads.

**Implementation**:
```swift
// Checkpoint system
struct UploadCheckpoint {
    let uploadId: String
    let completedChunks: [Int]
    let totalChunks: Int
}

// Resume upload
func resumeUpload(checkpoint: UploadCheckpoint) async throws {
    // Only upload remaining chunks
    for chunkIndex in checkpoint.completedChunks.count..<checkpoint.totalChunks {
        // Upload chunk
    }
}
```

---

### **3. CDN Configuration**

**Signed URLs** (Time-limited access):
```typescript
// Generate signed URL (7-30 days)
const signedURL = await supabase.storage
  .from('videos')
  .createSignedURL(path, expiresIn: 604800)  // 7 days
```

**Range Requests** (Video streaming):
```http
GET /videos/abc123.mp4
Range: bytes=0-1048576

Response:
Content-Range: bytes 0-1048576/52428800
Content-Length: 1048577
```

**CDN Headers**:
```typescript
{
  'Cache-Control': 'public, max-age=604800',  // 7 days
  'Content-Type': 'video/mp4',
  'Accept-Ranges': 'bytes',
  'Content-Length': fileSize
}
```

---

### **4. Cleanup Policy**

**Storage Tiers**:
```
1. Temporary Storage (processing)
   - Raw AI output (before encoding)
   - Cleanup: 24 hours

2. Active Storage (user videos)
   - Final videos (permanent, until user deletes)
   - Thumbnails (permanent)
   - Frame grids (30 days)

3. Archive Storage (inactive)
   - Videos not accessed in 90 days
   - Move to cheaper storage (S3 Glacier, etc.)
   - Cleanup: 1 year (or user preference)
```

**Cleanup Function**:
```typescript
// Edge Function: cleanup-videos
async function cleanupOldVideos() {
  // Delete temporary videos (24h+)
  // Archive inactive videos (90d+)
  // Delete archived videos (1y+)
}
```

---

### **5. Scalable Storage Options**

**Option A: Supabase Storage** (Recommended for Start)
- **Pros**: Already integrated, easy to use
- **Cons**: Limited to 50GB per project (free tier)
- **Cost**: $0.021/GB/month

**Option B: Cloudflare R2** (Recommended for Scale)
- **Pros**: No egress fees, S3-compatible
- **Cons**: Requires separate setup
- **Cost**: $0.015/GB/month (no egress)

**Option C: AWS S3** (Enterprise)
- **Pros**: Highly scalable, proven
- **Cons**: Complex pricing, egress fees
- **Cost**: $0.023/GB/month + egress

**Recommendation**: Start with **Supabase Storage**, migrate to **Cloudflare R2** at scale.

---

## ⚡ Performance & Cost Optimization

### **1. Background Queue Architecture**

**Recommended Stack**:
```
Supabase Jobs Table (Primary Queue)
  ├── Status tracking
  ├── Priority management
  └── Progress updates

Edge Function Workers (Polling)
  ├── Poll for queued jobs
  ├── Process with concurrency limits
  └── Update status

Optional: Redis/BullMQ (Scale Later)
  ├── Faster queue operations
  ├── Better rate limiting
  └── Dead letter queue
```

**Concurrency Limits**:
- **Per User**: Max 3 concurrent jobs
- **Global**: Max 10-20 concurrent jobs (depending on infrastructure)
- **Premium Users**: Higher priority, faster processing

---

### **2. Idempotency for Heavy Compute Jobs**

**Pattern** (Same as images):
```
1. Client generates request_id (UUID)
2. Server checks for duplicate
3. If exists → return cached result
4. If new → process and cache
```

**Additional Considerations**:
- **Video Caching**: Cache by prompt hash + parameters
- **Storage Cost**: Cache videos (larger than images)
- **Cache TTL**: 30-90 days (configurable)

---

### **3. Compression Before Storage**

**Strategy**:
```
AI Provider Output (High Quality, Large)
  ├── Original (keep for 30 days, then archive)
  ├── Optimized MP4 (1080p, H.264, ~10-20MB per minute)
  └── Preview MP4 (720p, lower bitrate, ~3-5MB per minute)
```

**Compression Settings**:
- **1080p**: H.264, 5-8 Mbps bitrate
- **720p**: H.264, 2-4 Mbps bitrate
- **Thumbnail**: JPEG, 1920x1080, 85% quality

---

### **4. Automatic Format Negotiation**

**Client Detection**:
```swift
// iOS: Prefer MP4
let preferredFormat = "mp4"

// Web: Prefer WebM (if supported)
let preferredFormat = supportsWebM ? "webm" : "mp4"
```

**Server Response**:
```typescript
// Serve appropriate format
const format = req.headers.accept?.includes('webm') ? 'webm' : 'mp4'
const videoURL = getVideoURL(videoId, format)
```

---

### **5. Re-encoding for Lower Bitrate Previews**

**Preview Pipeline**:
```
1. Generate full video (high quality)
2. Re-encode preview (lower bitrate, 720p)
3. Serve preview immediately (faster download)
4. Allow user to download full quality later
```

**Benefits**:
- Faster initial playback
- Lower bandwidth costs
- Better user experience (instant preview)

---

## 💰 Monetization & Analytics

### **1. Track Generation Metrics**

**Metrics to Track**:
```typescript
interface VideoGenerationMetrics {
    jobId: string
    userId: string
    type: 'text-to-video' | 'image-to-video' | 'hybrid'
    durationSeconds: number
    resolution: string
    fps: number
    aiProvider: string
    modelName: string
    generationTimeSeconds: number
    creditsConsumed: number
    costUsd: number
    status: 'completed' | 'failed' | 'cancelled'
    errorMessage?: string
}
```

**Analytics Dashboard**:
- Total videos generated (daily/weekly/monthly)
- Average generation time
- Success rate
- Cost per video
- Popular prompts/styles
- User retention

---

### **2. Tiered Credit System**

**Credit Conversion**:
```
Free Tier:
- 5 video minutes per day
- 720p resolution
- 24 FPS
- Standard quality

Premium Tier:
- 50+ video minutes per day (or unlimited)
- 1080p/4K resolution
- 30/60 FPS
- High quality
- Priority queue
- Faster processing
```

**Credit Calculation**:
```
Base: 1 minute = 1 credit
Resolution multiplier:
- 720p: 1x
- 1080p: 1.5x
- 4K: 3x

FPS multiplier:
- 24 FPS: 1x
- 30 FPS: 1.2x
- 60 FPS: 1.5x

Total credits = duration * resolution_mult * fps_mult
```

---

### **3. Adapty/StoreKit Integration**

**Pricing Model** (Minute-based):
```
Weekly Plan:
- $4.99/week
- 30 video minutes/week
- Premium features

Monthly Plan:
- $9.99/month
- 100 video minutes/month
- Premium features

Yearly Plan:
- $79.99/year
- Unlimited minutes
- Premium features
```

**StoreKit Integration**:
```swift
// Track video minutes consumed
func consumeVideoMinutes(minutes: Double) {
    // Update quota
    // Track usage
    // Trigger paywall if needed
}
```

---

### **4. Usage Reports**

**User Dashboard**:
```
┌─────────────────────────────────────┐
│  📊 Video Generation Stats          │
│                                     │
│  This Month:                        │
│  • Videos Generated: 12            │
│  • Total Minutes: 8.5               │
│  • Remaining: 1.5 / 10 minutes     │
│                                     │
│  Most Used Style: Mystical          │
│  Average Length: 42 seconds         │
│                                     │
│  [View Full History]               │
└─────────────────────────────────────┘
```

---

## 🚀 Advanced Suggestions (Critical for Y)

### **1. Sound Design Integration**

**Purpose**: Add background music, sound effects, or text-to-speech narration.

**Implementation**:
```
Video Generation
  ├── Generate video (silent)
  ├── Add soundtrack (optional)
  │   ├── Background music library
  │   ├── Sound effects (mystical, cinematic)
  │   └── Text-to-speech narration
  └── Mix audio (normalize volume)
```

**Features**:
- **Music Library**: Royalty-free tracks (mystical, ambient, cinematic)
- **Sound Effects**: Magical sounds, ambient noise
- **TTS Narration**: Read fortune/tarot results aloud
- **Volume Control**: Adjust music vs. narration balance

**Integration Points**:
- Post-processing pipeline (after video generation)
- User selection in parameter panel
- Automatic selection based on video style

---

### **2. Storyboard / Timeline Editor**

**Purpose**: Create multi-scene videos with transitions.

**Implementation**:
```
Timeline View:
┌─────────────────────────────────────┐
│  Scene 1  |  Scene 2  |  Scene 3   │
│  [5s]     |  [10s]    |  [15s]     │
│                                     │
│  [Add Scene] [Transition] [Preview] │
└─────────────────────────────────────┘
```

**Features**:
- **Multi-Scene Generation**: Generate multiple video clips
- **Transitions**: Fade, dissolve, slide between scenes
- **Timeline Editing**: Drag to reorder, trim, adjust
- **Preview**: Preview full timeline before final render

**Use Cases**:
- Fortune telling narrative (multiple scenes)
- Tarot reading progression (card reveals)
- Coffee reading story (multiple symbols)

---

### **3. In-App Editing**

**Purpose**: Edit videos after generation without regenerating.

**Features**:
- **Cut/Trim**: Remove unwanted sections
- **Caption Overlay**: Add text captions
- **Color Grading**: Apply filters, adjust brightness/contrast
- **Frame Selection**: Remove or regenerate specific frames
- **Speed Control**: Slow down or speed up playback

**Implementation**:
```swift
// iOS: AVFoundation editing
func editVideo(
    videoURL: URL,
    edits: VideoEdits
) async throws -> URL {
    let composition = AVMutableComposition()
    // Apply edits (trim, add captions, color grade)
    return try await exportVideo(composition)
}
```

---

### **4. Collaborative Sharing & Remixing**

**Purpose**: Share videos with others, allow remixing.

**Features**:
- **Share Links**: Generate shareable links (private/public)
- **Remix Mode**: Others can use your video as input
- **Collaborative Editing**: Multiple users edit same video
- **Template Library**: Save and share video templates

**Implementation**:
```
Share Flow:
1. Generate video
2. Create share link (with permissions)
3. Others can view, remix, or edit
4. Track views and remixes
```

---

### **5. Rendering Presets for Social Platforms**

**Purpose**: Optimize videos for specific platforms.

**Presets**:
```
Instagram:
- Resolution: 1080x1080 (square)
- Duration: 15-60 seconds
- Format: MP4, H.264
- Aspect ratio: 1:1

TikTok:
- Resolution: 1080x1920 (vertical)
- Duration: 15-60 seconds
- Format: MP4, H.264
- Aspect ratio: 9:16

YouTube Shorts:
- Resolution: 1080x1920 (vertical)
- Duration: 15-60 seconds
- Format: MP4, H.264
- Aspect ratio: 9:16

Twitter/X:
- Resolution: 1280x720 (horizontal)
- Duration: Up to 140 seconds
- Format: MP4, H.264
- Aspect ratio: 16:9
```

**UI**:
```
┌─────────────────────────────────────┐
│  🎬 Export Preset                   │
│                                     │
│  [Instagram] [TikTok] [YouTube]    │
│  [Twitter] [Custom]                │
│                                     │
│  Selected: Instagram                │
│  • 1080x1080, 15-60s, MP4          │
│                                     │
│  [Export] [Preview]                │
└─────────────────────────────────────┘
```

---

### **6. Real-Time Preview Generation**

**Purpose**: Show low-quality preview while generating full video.

**Implementation**:
```
1. Generate preview (low res, 5-10 seconds, fast)
2. Show preview to user immediately
3. Continue generating full video in background
4. Notify when full video ready
```

**Benefits**:
- Immediate feedback
- User can cancel if preview looks wrong
- Better UX (no waiting)

---

### **7. Prompt Library & Templates**

**Purpose**: Pre-configured prompts for common video types.

**Templates**:
```
Fortune Telling:
- "A mystical tarot card reading with golden symbols"
- "Coffee cup reading with mystical patterns"
- "Palm reading with glowing lines"

Mystical:
- "Ethereal forest with magical creatures"
- "Cosmic starfield with mystical symbols"
- "Ancient temple with glowing artifacts"

Cinematic:
- "Cinematic landscape with dramatic lighting"
- "Epic mountain vista with clouds"
- "Urban cityscape at golden hour"
```

**UI**:
```
┌─────────────────────────────────────┐
│  📚 Prompt Library                  │
│                                     │
│  [Fortune] [Mystical] [Cinematic]   │
│                                     │
│  • "Mystical tarot reading"         │
│  • "Coffee cup reading"            │
│  • "Palm reading visualization"     │
│                                     │
│  [Use Template] [Customize]        │
└─────────────────────────────────────┘
```

---

## 📅 Next Steps (90-Day Plan)

### **Phase 1: Foundation (Days 1-30)**

**Week 1-2: Core Infrastructure**
1. ✅ Extend quota system for video minutes
2. ✅ Add video metadata model to database
3. ✅ Implement multipart upload for large files
4. ✅ Set up video storage (Supabase Storage)

**Week 3-4: Basic Video Generation**
1. ✅ Integrate fal.ai video generation API
2. ✅ Implement async job queue (Supabase jobs table)
3. ✅ Create video generation edge function
4. ✅ Add status polling endpoint

**Deliverable**: Basic text-to-video generation working

---

### **Phase 2: UX & Polish (Days 31-60)**

**Week 5-6: Frontend Video UI**
1. ✅ Video player component
2. ✅ Progress tracking UI (multi-stage)
3. ✅ Queue indicator
4. ✅ Parameter panel (duration, resolution, FPS)

**Week 7-8: Enhanced Features**
1. ✅ Thumbnail extraction
2. ✅ Frame grid preview
3. ✅ Video library/history
4. ✅ Share functionality

**Deliverable**: Polished video generation UX

---

### **Phase 3: Advanced Features (Days 61-90)**

**Week 9-10: Image-to-Video & Hybrid**
1. ✅ Image-to-video generation
2. ✅ Image + text hybrid generation
3. ✅ Multiple AI provider support (Runway, Pika)

**Week 11-12: Post-Processing & Optimization**
1. ✅ Video compression pipeline
2. ✅ CDN integration
3. ✅ Watermarking
4. ✅ Social platform presets

**Deliverable**: Production-ready video generation app

---

## 📊 Summary

### **Reused Components (70%)**

✅ **Authentication**: 100% reusable  
✅ **Quota Management**: 90% reusable (needs metric adjustment)  
✅ **Storage Patterns**: 80% reusable (needs large file handling)  
✅ **Edge Functions**: 70% reusable (needs async pattern)  
✅ **Error Handling**: 90% reusable  
✅ **Progress Tracking**: 60% reusable (needs enhancement)

### **New Required Systems (30%)**

🆕 **Video Generation Service**: Orchestration pipeline  
🆕 **Rendering Queue**: Background job processing  
🆕 **Preview/Thumbnail System**: Frame extraction  
🆕 **Compression/Encoding**: Video optimization  
🆕 **CDN Integration**: Large asset delivery  
🆕 **Video Metadata Model**: Properties storage  
🆕 **Async Notifications**: Progress updates  
🆕 **Error Recovery**: Long job handling  
🆕 **Post-Processing**: Watermarking, captions, soundtracks

### **Key Transition Points**

1. **Synchronous → Asynchronous**: Image (5-30s) → Video (2-10min)
2. **File Size**: Image (1-10MB) → Video (50-500MB+)
3. **Quota Metric**: Image count → Video minutes
4. **Progress UI**: Simple bar → Multi-stage with time estimates
5. **Storage**: Single upload → Multipart/resumable
6. **Delivery**: Direct download → CDN with streaming

### **Recommended Tech Stack**

- **Backend**: Supabase (Storage, Edge Functions, Database)
- **Queue**: Supabase Jobs Table (start) → Redis/BullMQ (scale)
- **CDN**: Cloudflare R2 or Supabase CDN
- **AI Providers**: fal.ai (start) → Runway (premium)
- **Encoding**: Cloud encoding service (Mux, Cloudflare Stream)
- **Frontend**: SwiftUI + AVKit (video player)

---

**End of Audit Report**

*This report provides architectural guidance for transitioning from image processing to video generation. Implementation details should be adapted to your specific infrastructure and requirements.*

