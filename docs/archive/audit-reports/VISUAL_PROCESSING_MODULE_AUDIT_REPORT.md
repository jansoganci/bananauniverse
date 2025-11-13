# 🧪 Visual Processing Module Audit (X → Y)
## Safe Educational Reference for Fortunia Adaptation

**Date**: 2025-11-02  
**Source Company**: External (BananaUniverse)  
**Target Company**: Fortunia  
**Purpose**: Extract reusable visual processing patterns, components, and architecture for iOS-first SwiftUI app

---

## 📋 Executive Summary

This audit analyzes the external source's visual processing module (image upload → AI processing → output delivery) to identify reusable building blocks, patterns, and missed opportunities for Fortunia's iOS app. **No sensitive data** (API keys, endpoints, database schemas) is included.

---

## 🏗️ Pipeline Overview

### **High-Level Architecture**

```
iOS Client (SwiftUI)
  ├── Image Selection (PhotosPicker)
  ├── Pre-Processing (Compression, Validation)
  ├── Upload (Supabase Storage)
  ├── Edge Function Call (process-image)
  ├── AI Processing (External Provider)
  ├── Storage Persistence
  └── Result Delivery (Download, Display, Share)
```

### **Step-by-Step Pipeline**

**1. Image Selection & Validation**
```
PhotosPicker → UIImage → Size Check (10MB limit) → Validation
```

**2. Pre-Processing (Client-Side)**
```
UIImage → Orientation Fix → Compression (Core Image, GPU) → JPEG Data (0.8 quality, 1024px max)
```

**3. Upload**
```
Image Data → Supabase Storage → Unique Path (uploads/{user_id}/{filename}) → Signed URL
```

**4. Processing Request**
```
Edge Function: process-image
  ├── Authentication (JWT or device_id)
  ├── Quota Consumption (with idempotency)
  ├── AI Provider Call (fal.ai)
  ├── Result Storage
  └── Response (processed_image_url)
```

**5. Result Delivery**
```
Signed URL → Download → UIImage → Display → Save/Share
```

### **Separation of Concerns**

| Layer | Responsibility | Location |
|-------|---------------|----------|
| **UI Layer** | Image picker, progress display, result preview | `ChatView.swift` |
| **ViewModel** | State management, orchestration | `ChatViewModel.swift` |
| **Service Layer** | Upload, compression, storage operations | `StorageService.swift`, `SupabaseService.swift` |
| **Edge Function** | Quota, AI processing, persistence | `process-image/index.ts` |
| **External Provider** | AI model execution | fal.ai (external) |

---

## 🧩 Reusable Building Blocks (for Y)

### **1. Image Compression Module**

**Purpose**: Efficient client-side image compression before upload.

**Implementation Pattern**:
```swift
// Core Image-based compression (GPU-accelerated)
func compressImageToData(
    _ image: UIImage,
    maxDimension: CGFloat = 1024,
    quality: CGFloat = 0.8
) -> Data? {
    // 1. Fix orientation (preserve EXIF)
    guard let fixedImage = image.fixedOrientation() else { return nil }
    
    // 2. Core Image context (GPU)
    let ciImage = CIImage(cgImage: fixedImage.cgImage!)
    let context = CIContext(options: [.useSoftwareRenderer: false])
    
    // 3. Calculate scale (maintain aspect ratio)
    let scale = min(maxDimension / width, maxDimension / height)
    
    // 4. Resize transform
    let transform = CGAffineTransform(scaleX: scale, y: scale)
    let resized = ciImage.transformed(by: transform)
    
    // 5. Render and compress
    guard let cgImage = context.createCGImage(resized, from: resized.extent) else { return nil }
    return UIImage(cgImage: cgImage).jpegData(compressionQuality: quality)
}
```

**Key Features**:
- ✅ GPU-accelerated (Core Image)
- ✅ Orientation preservation (EXIF fix)
- ✅ Memory-efficient (autoreleasepool)
- ✅ Configurable quality/dimension

**Integration Notes**:
- Can be extracted to `ImageCompressionService.swift`
- Reusable across image upload flows
- Supports both PhotosPicker and camera capture

---

### **2. Orientation Fix Utility**

**Purpose**: Preserve EXIF orientation data in pixel data.

**Implementation Pattern**:
```swift
extension UIImage {
    func fixedOrientation() -> UIImage? {
        if imageOrientation == .up { return self }
        
        // Calculate transform for rotation/flip
        var transform = CGAffineTransform.identity
        // ... handle all 8 orientations
        
        // Redraw with correct orientation
        guard let cgImage = cgImage,
              let context = CGContext(...) else { return nil }
        
        context.concatenate(transform)
        context.draw(cgImage, in: rect)
        return UIImage(cgImage: context.makeImage()!)
    }
}
```

**Key Features**:
- ✅ Handles all 8 EXIF orientations
- ✅ Preserves image quality
- ✅ Critical for iOS camera images

**Integration Notes**:
- Essential for accurate image processing
- Works with PhotosPicker and camera
- Prevents rotated/upside-down results

---

### **3. Progress Tracking System**

**Purpose**: Real-time progress updates during processing.

**Implementation Pattern**:
```swift
enum ProcessingJobStatus: Equatable {
    case idle
    case submitting
    case processing(elapsedTime: Int)
    case completed
    case failed(error: String)
    
    var displayText: String {
        switch self {
        case .processing(let elapsed):
            if elapsed < 30: return "Processing... (\(elapsed)s)"
            else: return "Processing... (\(elapsed / 60)m \(elapsed % 60)s)"
        // ...
        }
    }
}

@Published var uploadProgress: Double = 0.0  // 0.0 - 1.0
@Published var jobStatus: ProcessingJobStatus = .idle
```

**Key Features**:
- ✅ Granular progress (upload → processing → download)
- ✅ Elapsed time tracking
- ✅ User-friendly status messages
- ✅ Error state handling

**Integration Notes**:
- Reusable status enum
- Can be adapted for batch processing
- Supports polling-based progress (if needed)

---

### **4. Idempotent Request Handler**

**Purpose**: Prevent duplicate processing on network retries.

**Implementation Pattern**:
```swift
// Client generates unique request ID
let clientRequestId = UUID().uuidString

// Server checks for duplicate
if (existingRequest) {
    return cachedResult;  // Return previous result
}

// Process and store result
const result = await processImage(...);
await storeRequestResult(clientRequestId, result);
```

**Key Features**:
- ✅ Client-generated request ID
- ✅ Server-side idempotency check
- ✅ Cached result return
- ✅ Prevents double-charging

**Integration Notes**:
- Critical for quota-based systems
- Works with network retries
- Database-level idempotency (recommended)

---

### **5. Network Connectivity Monitor**

**Purpose**: Proactive error handling for network failures.

**Implementation Pattern**:
```swift
@MainActor
class NetworkMonitor: ObservableObject {
    @Published var isConnected = true
    @Published var connectionType: NWInterface.InterfaceType?
    
    func checkConnectivity() -> Bool {
        return isConnected
    }
    
    var networkErrorMessage: String {
        return isConnected ? "Connected" : "No internet connection..."
    }
}

// Usage in ViewModel
guard NetworkMonitor.shared.checkConnectivity() else {
    errorMessage = NetworkMonitor.shared.networkErrorMessage
    return
}
```

**Key Features**:
- ✅ Real-time connectivity monitoring
- ✅ Connection type detection (WiFi/Cellular)
- ✅ Reactive updates (@Published)
- ✅ User-friendly error messages

**Integration Notes**:
- Singleton pattern (shared instance)
- Prevents unnecessary API calls
- Can trigger retry logic

---

### **6. Image Size Validation**

**Purpose**: Client-side size limits before upload.

**Implementation Pattern**:
```swift
let maxSize = 10_000_000  // 10 MB
if let data = image.jpegData(compressionQuality: 1.0),
   data.count > maxSize {
    errorMessage = "Image too large (\(data.count / 1_000_000) MB). Please select an image under 10 MB."
    return
}
```

**Key Features**:
- ✅ Pre-upload validation
- ✅ User-friendly error messages
- ✅ Prevents wasted quota
- ✅ Configurable limits

**Integration Notes**:
- Can be extracted to validation service
- Supports different limits per user tier
- Works with compression pipeline

---

### **7. Storage Path Organization**

**Purpose**: Organized file structure in cloud storage.

**Implementation Pattern**:
```swift
// Upload path: uploads/{user_id}/{filename}
// Processed path: processed/{user_id}/{timestamp}-result.jpg

let userIdentifier = userState.identifier
let path = "uploads/\(userIdentifier)/\(UUID().uuidString).jpg"
```

**Key Features**:
- ✅ User/device-based organization
- ✅ Unique filenames (UUID)
- ✅ Easy cleanup per user
- ✅ Supports anonymous users

**Integration Notes**:
- Adapt to Fortunia's storage structure
- Consider date-based folders for cleanup
- Supports RLS policies

---

### **8. Error Handling Taxonomy**

**Purpose**: Structured error handling with user-friendly messages.

**Implementation Pattern**:
```swift
enum ChatError: Error {
    case processingFailed
    case invalidResult
    case noImageSelected
    case quotaExceeded
    case networkError
}

enum SupabaseError: Error {
    case notAuthenticated
    case insufficientCredits
    case quotaExceeded
    case processingFailed(String)
    case timeout
    case rateLimitExceeded
}

// User-friendly conversion
var errorDescription: String? {
    switch self {
    case .quotaExceeded:
        return "Daily limit reached. Come back tomorrow or upgrade."
    // ...
    }
}
```

**Key Features**:
- ✅ Hierarchical error types
- ✅ User-friendly messages
- ✅ Technical details (for debugging)
- ✅ Graceful degradation

**Integration Notes**:
- Extract to `AppError` enum
- Supports localization
- Can trigger retry logic

---

## 🎨 Parameterization & Prompting Model

### **Current Prompt Structure**

**Simple Prompt Pattern**:
```swift
// User-provided prompt (free-form text)
let prompt: String = "Enhance this image"

// Default fallback
let defaultPrompt = "Enhance this image"

// Tool-specific prompts (from Tool model)
let toolPrompt = Tool.prompt  // e.g., "Remove the selected object naturally..."
```

### **Tool-Based Preset System**

**Implementation Pattern**:
```swift
struct Tool: Identifiable {
    let id: String
    let prompt: String  // Pre-configured prompt
    let modelName: String
    let category: String
}

// Tool categories:
// - main_tools: Photo editing (remove object, background, etc.)
// - pro_looks: Professional photo tools
// - restoration: Enhancement tools
// - seasonal: Holiday/seasonal tools
```

### **Suggested UI-Exposed Settings (for Y)**

#### **Beginner-Friendly Defaults**:
```
✅ Preset Selection (dropdown)
   - "Enhance Image" (default)
   - "Remove Background"
   - "Remove Object"
   - "Upscale Image"
   - Custom...

✅ Quality Level (slider)
   - Fast (default)
   - Balanced
   - High Quality

✅ Output Format (toggle)
   - JPEG (default)
   - PNG (with transparency)
```

#### **Advanced Settings (Collapsible)**:
```
🔧 Advanced Options
   ├── Resolution (1024px, 2048px, Original)
   ├── Creativity Level (0.0 - 1.0)
   ├── Resemblance Level (0.0 - 1.0)
   ├── Upscale Factor (2x, 4x)
   ├── Background Style (transparent, solid, gradient)
   └── Subject Preservation (low, medium, high)
```

### **Prompt Parameterization Pattern**

**Suggested Structure**:
```swift
struct ProcessingParameters {
    let prompt: String
    let creativity: Double  // 0.0 - 1.0
    let resemblance: Double  // 0.0 - 1.0
    let resolution: Int     // 1024, 2048, etc.
    let format: OutputFormat
    let backgroundStyle: BackgroundStyle?
    let subjectPreservation: SubjectPreservation
}

enum OutputFormat {
    case jpeg(quality: Double)
    case png(transparent: Bool)
    case webp
}

enum BackgroundStyle {
    case transparent
    case solid(color: String)
    case gradient(colors: [String])
}

enum SubjectPreservation {
    case low, medium, high
}
```

---

## 🔄 Reliability & Ops

### **Retry Logic**

**Current Implementation**: None (direct processing, no retry)

**Recommended Pattern**:
```swift
func processWithRetry(
    imageURL: String,
    prompt: String,
    maxRetries: Int = 3
) async throws -> ProcessedImage {
    var lastError: Error?
    
    for attempt in 1...maxRetries {
        do {
            return try await processImage(imageURL: imageURL, prompt: prompt)
        } catch {
            lastError = error
            
            // Exponential backoff
            let delay = pow(2.0, Double(attempt - 1)) * 1.0  // 1s, 2s, 4s
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            // Don't retry on certain errors
            if isNonRetryableError(error) {
                throw error
            }
        }
    }
    
    throw lastError ?? ProcessingError.unknown
}

func isNonRetryableError(_ error: Error) -> Bool {
    // Don't retry on:
    // - Quota exceeded (429)
    // - Authentication errors (401)
    // - Invalid input (400)
    return error is QuotaExceededError || 
           error is AuthenticationError ||
           error is InvalidInputError
}
```

### **Idempotency Keys**

**Implementation**:
```swift
// Client generates UUID
let requestId = UUID().uuidString

// Server checks database
if (exists(requestId)) {
    return cachedResult
}

// Process and store
await storeResult(requestId, result)
```

**Key Features**:
- ✅ Client-generated UUID
- ✅ Database-level check
- ✅ Cached result return
- ✅ Prevents duplicate processing

### **Deduplication Patterns**

**Request Deduplication**:
```swift
// Hash-based deduplication (optional)
let imageHash = imageData.sha256()
if (recentlyProcessed(imageHash)) {
    return cachedResult
}
```

**Quota Deduplication**:
```swift
// Database-level idempotency
// Same request_id → same quota consumption
// Refunded requests → allow retry
```

### **Long-Running Job Tracking**

**Current**: Synchronous processing (no polling)

**Alternative Pattern (Async)**:
```swift
// Submit job
let jobId = await submitJob(imageURL: imageURL, prompt: prompt)

// Poll status
while true {
    let status = await getJobStatus(jobId)
    
    switch status.status {
    case .completed:
        return status.result
    case .failed:
        throw ProcessingError.failed(status.error)
    case .processing:
        await Task.sleep(seconds: 3)  // Poll every 3s
    }
}
```

**Polling Strategy**:
- Exponential backoff: 3s → 5s → 8s → 10s (max)
- Max attempts: 120 (10 minutes)
- Progress callbacks: `onProgress(status)`

### **Error Taxonomy**

**Error Hierarchy**:
```
ProcessingError
├── NetworkError
│   ├── Timeout
│   ├── NoConnection
│   └── ConnectionLost
├── QuotaError
│   ├── QuotaExceeded
│   └── InsufficientCredits
├── ValidationError
│   ├── ImageTooLarge
│   ├── InvalidFormat
│   └── InvalidPrompt
├── ProcessingError
│   ├── AIServiceError
│   ├── InvalidResult
│   └── Timeout
└── SystemError
    ├── AuthenticationError
    └── StorageError
```

### **User-Facing Fallbacks**

**Graceful Degradation**:
```swift
// 1. Network error → Show offline message
if !NetworkMonitor.shared.isConnected {
    showError("No internet connection. Please try again when online.")
    return
}

// 2. Quota exceeded → Show paywall
if quotaExceeded {
    showPaywall()
    return
}

// 3. Processing failed → Allow retry
if processingFailed {
    showError("Processing failed. Would you like to try again?")
    showRetryButton()
    return
}

// 4. Timeout → Auto-retry once
if timeout {
    showMessage("Processing taking longer than expected. Retrying...")
    await retry()
}
```

---

## ⚡ Performance & Cost Controls

### **Compression Strategy**

**Pre-Upload Compression**:
```swift
// Client-side (iOS)
- Max dimension: 1024px (configurable)
- Quality: 0.8 (JPEG)
- Format: JPEG (smallest file size)
- Orientation fix: Before compression
```

**Server-Side Resize** (optional):
```typescript
// Edge Function (if needed)
- Resize to max 2048px (if client sends larger)
- Convert to WebP (if supported)
- Cache compressed versions
```

### **Caching Strategy**

**Current**: No caching (direct processing)

**Recommended**:
```swift
// 1. Image hash-based caching
let imageHash = imageData.sha256()
if let cached = cache.get(imageHash, prompt) {
    return cached
}

// 2. CDN caching (signed URLs)
- 7-day expiration
- Public CDN for processed images
- Cache-Control headers

// 3. Local cache (iOS)
- Cache processed images in memory
- Persist to disk (optional)
- Clear on memory pressure
```

### **CDN Headers**

**Recommended Headers**:
```typescript
// Processed image response
{
    'Cache-Control': 'public, max-age=604800',  // 7 days
    'Content-Type': 'image/jpeg',
    'ETag': imageHash,
    'Last-Modified': timestamp
}
```

### **Batching Strategies**

**Current**: Single image processing

**Recommended (for batch)**:
```swift
// Batch processing (future)
func processBatch(images: [UIImage], prompt: String) async throws -> [ProcessedImage] {
    // Process in parallel (max 3 concurrent)
    let semaphore = DispatchSemaphore(value: 3)
    
    return try await withThrowingTaskGroup(of: ProcessedImage.self) { group in
        for image in images {
            group.addTask {
                await semaphore.wait()
                defer { semaphore.signal() }
                return try await processImage(image, prompt: prompt)
            }
        }
        
        return try await group.reduce(into: []) { $0.append($1) }
    }
}
```

### **Concurrency Limits**

**Recommended**:
- Max concurrent requests per user: 3
- Max concurrent requests globally: 10
- Rate limit: 10 requests/minute per user

### **Quota Hooks**

**Integration Points**:
```swift
// Pre-check (client)
guard await creditManager.canProcessImage() else {
    showPaywall()
    return
}

// Server check (edge function)
const quotaResult = await consumeQuota(userId, requestId)
if (!quotaResult.success) {
    return 429  // Quota exceeded
}

// Refund on failure
if (processingFailed) {
    await refundQuota(userId, requestId)
}
```

---

## 🛡️ Quality & Safety Gates

### **Automatic Quality Checks**

**Current**: None (basic validation only)

**Recommended**:
```swift
// 1. Image format validation
func validateImage(_ image: UIImage) -> ValidationResult {
    // Check format (JPEG, PNG, HEIC)
    // Check dimensions (min 100x100, max 10000x10000)
    // Check file size (max 10MB)
    // Check color space (RGB, grayscale)
}

// 2. Face/hand integrity (optional)
func detectFaces(image: UIImage) -> [Face] {
    // Use Vision framework
    // Check for face detection
    // Warn if faces might be distorted
}

// 3. Artifact detection (optional)
func detectArtifacts(image: UIImage) -> [Artifact] {
    // Check for compression artifacts
    // Check for AI generation artifacts
    // Warn if quality is low
}
```

### **Content Moderation**

**Current**: Mentioned in terms (NSFW scanning)

**Recommended Implementation**:
```typescript
// Edge Function (server-side)
async function moderateContent(imageUrl: string): Promise<ModerationResult> {
    // 1. NSFW detection (external service)
    const nsfwResult = await checkNSFW(imageUrl)
    if (nsfwResult.isNSFW) {
        return { allowed: false, reason: 'NSFW content detected' }
    }
    
    // 2. Prompt injection check
    const prompt = sanitizePrompt(userPrompt)
    if (containsInjection(prompt)) {
        return { allowed: false, reason: 'Invalid prompt detected' }
    }
    
    // 3. Violence/hate speech detection
    const safetyResult = await checkSafety(imageUrl, prompt)
    if (!safetyResult.safe) {
        return { allowed: false, reason: safetyResult.reason }
    }
    
    return { allowed: true }
}
```

### **Export Readiness Checks**

**Recommended**:
```swift
func validateExport(image: UIImage, format: ExportFormat) -> ValidationResult {
    switch format {
    case .png:
        // Check transparency support
        // Check color profile (sRGB)
        // Check DPI (72-300)
        
    case .jpeg:
        // Check quality (0.7-1.0)
        // Check color space (RGB)
        // Check dimensions (max 4096x4096)
        
    case .webp:
        // Check browser support
        // Check animation support (if needed)
    }
}
```

### **Human Subject Preservation Rules**

**Recommended**:
```swift
// Detect human subjects
func detectHumanSubjects(image: UIImage) -> [HumanSubject] {
    // Use Vision framework
    // Detect faces, bodies, hands
    // Return bounding boxes
}

// Apply preservation rules
func processWithPreservation(
    image: UIImage,
    prompt: String,
    preservation: SubjectPreservation
) -> UIImage {
    let subjects = detectHumanSubjects(image)
    
    // Low: Allow slight modifications
    // Medium: Preserve facial features
    // High: Preserve all human features
}
```

---

## 📤 Share & Export

### **Current Share Implementation**

**Pattern**:
```swift
func shareImage(_ image: UIImage) -> UIActivityViewController {
    let activityVC = UIActivityViewController(
        activityItems: [image],
        applicationActivities: nil
    )
    return activityVC
}
```

### **Share Card Generation (Missing)**

**Recommended**:
```swift
func generateShareCard(
    image: UIImage,
    style: ShareCardStyle
) -> UIImage {
    // 1. Create canvas (1080x1080 for Instagram)
    let canvas = UIImage(size: CGSize(width: 1080, height: 1080))
    
    // 2. Add image (centered, aspect-fit)
    canvas.draw(image, in: rect)
    
    // 3. Add watermark/branding (optional)
    if style.showWatermark {
        canvas.draw(watermark, at: position)
    }
    
    // 4. Add text overlay (optional)
    if let text = style.text {
        canvas.drawText(text, at: position)
    }
    
    // 5. Return composite image
    return canvas
}

enum ShareCardStyle {
    case instagram(size: CGSize = CGSize(width: 1080, height: 1080))
    case twitter(size: CGSize = CGSize(width: 1200, height: 675))
    case facebook(size: CGSize = CGSize(width: 1200, height: 630))
    case story(size: CGSize = CGSize(width: 1080, height: 1920))
}
```

### **Export Pipeline**

**Recommended**:
```swift
enum ExportFormat {
    case jpeg(quality: Double)
    case png(transparent: Bool)
    case webp
    case heic
}

func exportImage(
    image: UIImage,
    format: ExportFormat,
    size: CGSize? = nil
) -> Data? {
    // 1. Resize if needed
    let finalImage = size.map { resize(image, to: $0) } ?? image
    
    // 2. Convert format
    switch format {
    case .jpeg(let quality):
        return finalImage.jpegData(compressionQuality: quality)
    case .png(let transparent):
        return finalImage.pngData()
    case .webp:
        return convertToWebP(finalImage)
    case .heic:
        return convertToHEIC(finalImage)
    }
}
```

### **Watermarking Strategy**

**Recommended**:
```swift
func addWatermark(
    image: UIImage,
    watermark: UIImage,
    position: WatermarkPosition = .bottomRight,
    opacity: Double = 0.3
) -> UIImage {
    // 1. Create canvas
    let canvas = UIGraphicsImageRenderer(size: image.size)
    
    // 2. Draw image
    canvas.image { context in
        image.draw(in: rect)
        
        // 3. Draw watermark
        watermark.draw(
            in: watermarkRect(at: position),
            blendMode: .normal,
            alpha: opacity
        )
    }
    
    return canvas.image
}

enum WatermarkPosition {
    case topLeft, topRight, bottomLeft, bottomRight, center
}
```

### **Versioning Strategy**

**Recommended**:
```swift
// Store processing history
struct ProcessingHistory {
    let originalImageURL: String
    let processedImageURL: String
    let prompt: String
    let parameters: ProcessingParameters
    let timestamp: Date
    let version: Int  // Increment for re-processes
}

// Allow version comparison
func compareVersions(v1: ProcessingHistory, v2: ProcessingHistory) -> ComparisonResult {
    // Compare by timestamp, parameters, or user preference
}
```

---

## 🎯 Missed Opportunities (High-Value for Y)

### **1. Preset Library by Category**

**Opportunity**: Pre-configured prompt libraries for different use cases.

**Implementation**:
```swift
struct PresetLibrary {
    let category: PresetCategory
    let presets: [Preset]
}

enum PresetCategory {
    case background  // Background removal, replacement, blur
    case enhance     // Upscale, sharpen, denoise
    case product     // Product photography enhancement
    case portrait    // Face enhancement, skin smoothing
    case fortune     // Tarot/coffee reading visuals (Fortunia-specific)
    case palm        // Palm reading visuals (Fortunia-specific)
}

struct Preset {
    let id: String
    let name: String
    let prompt: String
    let icon: String
    let parameters: ProcessingParameters
}
```

**Fortunia-Specific Presets**:
- **Tarot Card Style**: "Create a mystical tarot card aesthetic with golden borders and mystical symbols"
- **Coffee Reading Visual**: "Generate a coffee cup reading visualization with mystical patterns"
- **Palm Reading Overlay**: "Add palm reading lines and symbols to the hand image"
- **Fortune Telling Aura**: "Create an ethereal aura effect around the subject"

---

### **2. Auto-Alt-Text Generation**

**Opportunity**: Accessibility improvement with AI-generated alt text.

**Implementation**:
```swift
func generateAltText(image: UIImage) async throws -> String {
    // Use Vision framework or external service
    let description = await analyzeImage(image)
    return "Image showing: \(description)"
}

// Usage in UI
Image(uiImage: image)
    .accessibilityLabel(generatedAltText)
```

---

### **3. Localization of Overlays**

**Opportunity**: Localized text overlays for share cards.

**Implementation**:
```swift
struct LocalizedOverlay {
    let text: LocalizedStringKey
    let position: CGPoint
    let style: TextStyle
}

func generateLocalizedShareCard(
    image: UIImage,
    locale: Locale
) -> UIImage {
    let overlay = LocalizedOverlay(
        text: "Your Fortune Awaits",  // Localized
        position: .center,
        style: .mystical
    )
    return addOverlay(image, overlay)
}
```

---

### **4. Before/After Diff Scoring**

**Opportunity**: Show improvement metrics.

**Implementation**:
```swift
func calculateImprovementScore(
    original: UIImage,
    processed: UIImage
) -> ImprovementScore {
    // 1. Sharpness comparison
    let sharpnessDiff = calculateSharpness(processed) - calculateSharpness(original)
    
    // 2. Color vibrancy comparison
    let vibrancyDiff = calculateVibrancy(processed) - calculateVibrancy(original)
    
    // 3. Overall quality score
    let qualityScore = (sharpnessDiff + vibrancyDiff) / 2
    
    return ImprovementScore(
        sharpness: sharpnessDiff,
        vibrancy: vibrancyDiff,
        overall: qualityScore
    )
}

struct ImprovementScore {
    let sharpness: Double
    let vibrancy: Double
    let overall: Double
    
    var displayText: String {
        if overall > 0.3: return "✨ Significantly Enhanced"
        else if overall > 0.1: return "✨ Enhanced"
        else: return "✨ Slightly Enhanced"
    }
}
```

---

### **5. Style Transfer with Brand Tokens**

**Opportunity**: Apply Fortunia's brand aesthetic to processed images.

**Implementation**:
```swift
struct BrandTokens {
    let primaryColor: Color
    let secondaryColor: Color
    let mysticalPattern: UIImage
    let font: Font
    let style: MysticalStyle
}

enum MysticalStyle {
    case tarot
    case coffee
    case palm
    case aura
}

func applyBrandStyle(
    image: UIImage,
    tokens: BrandTokens
) -> UIImage {
    // Apply color grading
    // Add mystical patterns
    // Apply font/text styling
    // Return branded image
}
```

---

### **6. A/B Test Hooks for Prompt Variants**

**Opportunity**: Test different prompt strategies.

**Implementation**:
```swift
struct PromptVariant {
    let id: String
    let prompt: String
    let weight: Double  // 0.0 - 1.0 (A/B test weight)
}

func selectPromptVariant(
    variants: [PromptVariant],
    userSegment: UserSegment
) -> PromptVariant {
    // A/B test logic
    // Return variant based on user segment
}

// Analytics tracking
func trackPromptVariant(
    variant: PromptVariant,
    result: ProcessingResult
) {
    // Track success rate, user satisfaction
    // Optimize prompt selection
}
```

---

### **7. Human Subject Preservation Rules**

**Opportunity**: Automatic detection and preservation of human subjects.

**Implementation**:
```swift
func detectHumanSubjects(image: UIImage) -> [HumanSubject] {
    // Use Vision framework
    let request = VNDetectHumanRectanglesRequest()
    // Detect faces, bodies, hands
    return detectedSubjects
}

func processWithHumanPreservation(
    image: UIImage,
    prompt: String,
    preservation: SubjectPreservation
) -> UIImage {
    let subjects = detectHumanSubjects(image)
    
    if subjects.isEmpty {
        return processNormally(image, prompt)
    }
    
    // Apply preservation rules
    switch preservation {
    case .low:
        // Allow slight modifications
        return processWithMask(image, prompt, excludeRegions: [])
    case .medium:
        // Preserve facial features
        return processWithMask(image, prompt, excludeRegions: subjects.faces)
    case .high:
        // Preserve all human features
        return processWithMask(image, prompt, excludeRegions: subjects.all)
    }
}
```

---

### **8. Batch Processing with Progress**

**Opportunity**: Process multiple images at once.

**Implementation**:
```swift
func processBatch(
    images: [UIImage],
    prompt: String,
    onProgress: @escaping (Int, Int) -> Void  // current, total
) async throws -> [ProcessedImage] {
    var results: [ProcessedImage] = []
    
    for (index, image) in images.enumerated() {
        onProgress(index + 1, images.count)
        let result = try await processImage(image, prompt: prompt)
        results.append(result)
    }
    
    return results
}
```

---

## 📅 90-Day Roadmap (Phased)

### **Phase 1: MVP (Days 1-30)**

**Must-Haves for Stable v1**:
1. ✅ **Image Compression Module** (Days 1-3)
   - Core Image compression
   - Orientation fix
   - Configurable quality/dimension

2. ✅ **Upload Pipeline** (Days 4-7)
   - Supabase Storage integration
   - Progress tracking
   - Error handling

3. ✅ **Processing Pipeline** (Days 8-15)
   - Edge Function integration
   - AI provider call
   - Result download

4. ✅ **Basic Error Handling** (Days 16-20)
   - Network monitoring
   - Error taxonomy
   - User-friendly messages

5. ✅ **Quota Integration** (Days 21-25)
   - Pre-check validation
   - Quota consumption
   - Paywall triggers

6. ✅ **Save/Share** (Days 26-30)
   - Photos library save
   - Native share sheet
   - Permission handling

---

### **Phase 2: Reliability & UX (Days 31-60)**

**Reliability Boosts**:
1. ✅ **Idempotency Protection** (Days 31-35)
   - Request ID generation
   - Server-side deduplication
   - Cached result return

2. ✅ **Retry Logic** (Days 36-40)
   - Exponential backoff
   - Non-retryable error detection
   - Max retry limits

3. ✅ **Progress Tracking** (Days 41-45)
   - Granular progress updates
   - Elapsed time display
   - Status messages

4. ✅ **Caching Strategy** (Days 46-50)
   - Image hash-based cache
   - CDN integration
   - Local cache (optional)

5. ✅ **Quality Validation** (Days 51-55)
   - Format validation
   - Size limits
   - Export readiness checks

6. ✅ **Content Moderation** (Days 56-60)
   - NSFW detection
   - Prompt injection check
   - Safety validation

---

### **Phase 3: "Wow" Features (Days 61-90)**

**Advanced Features**:
1. ✅ **Preset Library** (Days 61-70)
   - Category-based presets
   - Fortunia-specific presets (tarot, coffee, palm)
   - Custom preset creation

2. ✅ **Share Card Generation** (Days 71-75)
   - Instagram/Twitter/Facebook formats
   - Watermarking
   - Localized overlays

3. ✅ **Before/After Comparison** (Days 76-80)
   - Side-by-side view
   - Improvement scoring
   - Diff visualization

4. ✅ **Style Transfer** (Days 81-85)
   - Brand token application
   - Mystical style presets
   - Custom style creation

5. ✅ **Batch Processing** (Days 86-90)
   - Multiple image processing
   - Progress tracking
   - Result gallery

---

## 📊 Summary

### **Reusable Components**

✅ **Core Modules**:
1. Image Compression (Core Image, GPU-accelerated)
2. Orientation Fix Utility (EXIF preservation)
3. Progress Tracking System (status enum, progress values)
4. Idempotent Request Handler (UUID-based)
5. Network Connectivity Monitor (real-time monitoring)
6. Image Size Validation (pre-upload checks)
7. Storage Path Organization (user-based structure)
8. Error Handling Taxonomy (hierarchical errors)

✅ **Pipeline Patterns**:
1. Upload → Process → Download (synchronous)
2. Upload → Submit → Poll → Download (asynchronous alternative)
3. Pre-validation → Compression → Upload → Processing

✅ **Safety & Quality**:
1. Content moderation (NSFW, prompt injection)
2. Quality validation (format, size, dimensions)
3. Export readiness checks (DPI, color profile)

### **Missed Opportunities**

✅ **High-Value Features**:
1. Preset Library (category-based)
2. Auto-Alt-Text (accessibility)
3. Localized Overlays (share cards)
4. Before/After Scoring (improvement metrics)
5. Style Transfer (brand tokens)
6. A/B Test Hooks (prompt optimization)
7. Human Subject Preservation (Vision framework)
8. Batch Processing (multiple images)

### **Implementation Priority**

**Phase 1 (MVP)**: Core processing pipeline, basic error handling, save/share  
**Phase 2 (Reliability)**: Idempotency, retry logic, caching, content moderation  
**Phase 3 (Advanced)**: Preset library, share cards, style transfer, batch processing

---

**End of Audit Report**

*This report contains only universal visual processing patterns and reusable components. No sensitive data, API keys, database schemas, or project-specific implementation details are included.*

