# iOS Migration Plan: Async Polling Architecture

## Overview

This document details all iOS/SwiftUI changes required to migrate from synchronous to async polling architecture.

**Scope**: iOS app (SwiftUI + MVVM)
**Duration**: 4-6 hours
**Risk**: Medium (user-facing changes)

---

## Part 1: Files to Create

### 1.1 NEW Model: `SubmitJobResponse.swift`

**File Path**: `BananaUniverse/Core/Models/SubmitJobResponse.swift`

**Purpose**: Parse response from `submit-job` Edge Function.

**Size Estimate**: ~30 lines

**Structure**:
```swift
struct SubmitJobResponse: Decodable {
    let success: Bool
    let jobId: String
    let status: String
    let creditInfo: CreditInfo?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case success
        case jobId = "job_id"
        case status
        case creditInfo = "credit_info"
        case error
    }
}
```

---

### 1.2 NEW Model: `CheckStatusResponse.swift`

**File Path**: `BananaUniverse/Core/Models/CheckStatusResponse.swift`

**Purpose**: Parse response from `check-status` Edge Function.

**Size Estimate**: ~40 lines

**Structure**:
```swift
struct CheckStatusResponse: Decodable {
    let success: Bool
    let status: String
    let imageURL: String?
    let error: String?
    let queuePosition: Int?

    enum CodingKeys: String, CodingKey {
        case success
        case status
        case imageURL = "image_url"
        case error
        case queuePosition = "queue_position"
    }
}
```

---

### 1.3 NEW Model: `JobStatusResult.swift`

**File Path**: `BananaUniverse/Core/Models/JobStatusResult.swift`

**Purpose**: Internal representation of job status (used by ViewModel).

**Size Estimate**: ~50 lines

**Structure**:
```swift
struct JobStatusResult {
    let status: JobStatus
    let imageURL: String?
    let error: String?
    let queuePosition: Int?

    enum JobStatus: String {
        case queued
        case processing
        case completed
        case failed
        case unknown
    }
}
```

---

### 1.4 NEW Error: `JobError` (Add to existing `ChatError`)

**File Path**: `BananaUniverse/Features/Chat/ViewModels/ChatViewModel.swift` (within existing enum)

**Purpose**: Handle job-specific errors.

**Structure** (add to existing `ChatError` enum):
```swift
enum ChatError: Error {
    // Existing cases...
    case processingFailed
    case invalidResult
    case noImageSelected

    // NEW cases
    case jobSubmissionFailed(String)
    case jobTimeout
    case jobStatusCheckFailed(String)
    case unknownJobStatus(String)

    var localizedDescription: String {
        switch self {
        // ... existing cases ...

        case .jobSubmissionFailed(let reason):
            return "Failed to submit job: \(reason)"
        case .jobTimeout:
            return "Processing timeout. Please try again."
        case .jobStatusCheckFailed(let reason):
            return "Failed to check job status: \(reason)"
        case .unknownJobStatus(let status):
            return "Unknown job status: \(status)"
        }
    }
}
```

---

## Part 2: Files to Modify

### 2.1 MODIFY: `SupabaseService.swift`

**File Path**: `BananaUniverse/Core/Services/SupabaseService.swift`

**Changes**: Add two new methods for async job pattern.

**Line Count**: ~150 new lines

#### New Method 1: `submitImageJob`

**Purpose**: Submit job to fal.ai async queue.

**Method signature**:
```swift
func submitImageJob(
    imageURL: String,
    prompt: String
) async throws -> SubmitJobResponse
```

**Responsibilities**:
1. Get user_id or device_id from `HybridAuthService`
2. Build request body
3. Call `submit-job` Edge Function
4. Parse response
5. Throw error if submission fails

**Error handling**:
- Network error → `SupabaseError.network`
- 402 Insufficient credits → `SupabaseError.insufficientCredits`
- 401 Unauthorized → `SupabaseError.unauthorized`
- 500 Server error → `SupabaseError.serverError`

---

#### New Method 2: `checkJobStatus`

**Purpose**: Query job status from fal.ai.

**Method signature**:
```swift
func checkJobStatus(
    jobId: String
) async throws -> CheckStatusResponse
```

**Responsibilities**:
1. Build request body with job_id
2. Call `check-status` Edge Function
3. Parse response
4. Return status (queued/processing/completed/failed)

**Error handling**:
- Network error → `SupabaseError.network`
- 404 Job not found → `SupabaseError.jobNotFound`
- 500 Server error → `SupabaseError.serverError`

---

#### Keep Existing Method (Fallback): `processImageSteveJobsStyle`

**Action**: Do NOT delete this method yet.

**Purpose**: Fallback to old synchronous endpoint if polling fails.

**Usage**: Only called if new polling logic throws error (Phase 2 safety net).

**Removal**: Phase 4 (after 2 weeks of stable polling).

---

### 2.2 MODIFY: `ChatViewModel.swift`

**File Path**: `BananaUniverse/Features/Chat/ViewModels/ChatViewModel.swift`

**Changes**: Replace synchronous call with async polling pattern.

**Line Count**: ~200 lines modified/added

#### Change 1: Add Polling State Properties

**Add to properties section** (after line ~76):
```swift
@Published var currentJobID: String? = nil
@Published var queuePosition: Int? = nil
@Published private(set) var pollingAttempts: Int = 0
```

---

#### Change 2: Replace `processImage` Method

**Current code** (lines ~207-352):
```swift
private func processImage(_ image: UIImage) async {
    // ... validation ...

    // OLD: Synchronous call
    let steveJobsResult = try await supabaseService.processImageSteveJobsStyle(
        imageURL: imageURL,
        prompt: originalPrompt
    )

    // ... handle result ...
}
```

**New code**:
```swift
private func processImage(_ image: UIImage) async {
    // ... keep existing validation (lines 207-253) ...

    jobStatus = .submitting
    errorMessage = nil
    uploadProgress = 0.0

    // Add user message (keep existing)
    addUserMessage(content: promptContent, image: image)

    do {
        // STEP 1: Submit job
        uploadProgress = 0.2
        let submitResult = try await supabaseService.submitImageJob(
            imageURL: imageURL,
            prompt: originalPrompt
        )

        guard submitResult.success else {
            throw ChatError.jobSubmissionFailed(submitResult.error ?? "Unknown error")
        }

        currentJobID = submitResult.jobId
        uploadProgress = 0.3

        // Add status message
        addAssistantMessage(
            content: "🤖 Processing your image... (Job ID: \(submitResult.jobId.prefix(8)))",
            image: nil
        )

        // STEP 2: Poll for completion
        jobStatus = .processing(elapsedTime: 0)
        let finalResult = try await pollJobStatus(jobId: submitResult.jobId)

        uploadProgress = 0.9

        // STEP 3: Download and display result
        guard let processedImageURL = finalResult.imageURL else {
            throw ChatError.invalidResult
        }

        guard let url = URL(string: processedImageURL) else {
            throw ChatError.invalidResult
        }

        let (processedImageData, _) = try await URLSession.shared.data(from: url)

        guard let processedUIImage = UIImage(data: processedImageData) else {
            throw ChatError.invalidResult
        }

        processedImage = processedUIImage
        jobStatus = .completed
        uploadProgress = 1.0

        // Update assistant message with result
        if let lastMessage = messages.last, lastMessage.type == .assistant {
            messages[messages.count - 1] = ChatMessage(
                type: .assistant,
                content: "✨ Your image has been processed successfully!",
                image: processedUIImage,
                timestamp: Date()
            )
        }

    } catch {
        let appError = AppError.from(error)
        errorMessage = appError.errorDescription
        jobStatus = .failed(error: appError.errorDescription ?? "Processing failed")
        uploadProgress = 0.0

        // Add error message to chat
        addErrorMessage(content: "❌ Processing failed: \(error.localizedDescription)")
    }

    // Cleanup
    storageService.cleanupTemporaryImageData()

    // Reset after delay
    Task {
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        if !jobStatus.isActive {
            jobStatus = .idle
        }
    }
}
```

---

#### Change 3: Add NEW Method `pollJobStatus`

**Insert after `processImage` method**:

```swift
/// Polls job status with exponential backoff until complete or timeout
private func pollJobStatus(jobId: String) async throws -> JobStatusResult {
    var interval: TimeInterval = 2.0  // Start at 2 seconds
    let maxInterval: TimeInterval = 10.0
    let timeout: TimeInterval = 120.0  // 2 minutes max
    var elapsed: TimeInterval = 0.0
    pollingAttempts = 0

    while elapsed < timeout {
        pollingAttempts += 1

        let statusResponse = try await supabaseService.checkJobStatus(jobId: jobId)

        // Update queue position (for UI feedback)
        queuePosition = statusResponse.queuePosition

        // Parse status
        let statusString = statusResponse.status.lowercased()

        switch statusString {
        case "completed":
            // Success!
            return JobStatusResult(
                status: .completed,
                imageURL: statusResponse.imageURL,
                error: nil,
                queuePosition: nil
            )

        case "failed":
            // Processing failed, throw error
            throw ChatError.jobStatusCheckFailed(statusResponse.error ?? "Unknown error")

        case "processing", "queued", "in_queue", "in_progress":
            // Still processing, continue polling
            jobStatus = .processing(elapsedTime: Int(elapsed))

            // Exponential backoff
            try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            elapsed += interval
            interval = min(interval * 1.5, maxInterval)

        default:
            // Unknown status
            throw ChatError.unknownJobStatus(statusString)
        }
    }

    // Timeout reached
    throw ChatError.jobTimeout
}
```

---

#### Change 4: Add Cancel Functionality (Optional)

**Insert new method**:
```swift
/// Cancel current polling operation
func cancelCurrentJob() {
    guard let jobId = currentJobID else { return }

    // Cancel polling (Task will throw CancellationError)
    for task in inFlightTasks {
        task.cancel()
    }

    jobStatus = .idle
    currentJobID = nil
    errorMessage = "Processing cancelled by user"
}
```

---

### 2.3 MODIFY: `ChatView.swift` (Optional UI Enhancements)

**File Path**: `BananaUniverse/Features/Chat/Views/ChatView.swift`

**Changes**: Add queue position display, cancel button (optional).

**Line Count**: ~30 lines added

#### Enhancement 1: Show Queue Position

**Insert in processing state UI** (around line ~150):
```swift
if viewModel.jobStatus.isActive {
    VStack(spacing: 8) {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle())

        Text(viewModel.jobStatus.displayText)
            .font(.caption)
            .foregroundColor(.secondary)

        // NEW: Show queue position if available
        if let queuePosition = viewModel.queuePosition {
            Text("Queue position: \(queuePosition)")
                .font(.caption2)
                .foregroundColor(.orange)
        }

        // NEW: Show polling attempts
        if viewModel.pollingAttempts > 0 {
            Text("Status checks: \(viewModel.pollingAttempts)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}
```

---

#### Enhancement 2: Add Cancel Button (Optional)

**Insert in processing state UI**:
```swift
if viewModel.jobStatus.isActive {
    VStack {
        // ... existing progress UI ...

        Button(action: {
            viewModel.cancelCurrentJob()
        }) {
            Text("Cancel")
                .font(.caption)
                .foregroundColor(.red)
        }
        .padding(.top, 8)
    }
}
```

---

### 2.4 MODIFY: `SupabaseError.swift` (Add New Error Cases)

**File Path**: `BananaUniverse/Core/Services/SupabaseService.swift` (or separate error file)

**Changes**: Add job-specific error cases.

**Add to existing `SupabaseError` enum**:
```swift
enum SupabaseError: Error {
    // Existing cases...
    case quotaExceeded
    case unauthorized
    case network(Error)

    // NEW cases
    case jobSubmissionFailed(String)
    case jobNotFound
    case jobStatusCheckFailed(String)
    case insufficientCredits(CreditInfo)

    var localizedDescription: String {
        switch self {
        // ... existing cases ...

        case .jobSubmissionFailed(let reason):
            return "Failed to submit job: \(reason)"
        case .jobNotFound:
            return "Job not found. It may have expired."
        case .jobStatusCheckFailed(let reason):
            return "Failed to check job status: \(reason)"
        case .insufficientCredits(let info):
            return "Insufficient credits. You have \(info.balance) credits."
        }
    }
}
```

---

## Part 3: Files to Delete

**NONE** during Phase 2.

**Phase 4 only** (after 2 weeks):
- Remove `processImageSteveJobsStyle` method from `SupabaseService.swift`
- Remove fallback logic from `ChatViewModel.swift` (if added)

---

## Part 4: Configuration Changes

### 4.1 Polling Parameters

**File**: `BananaUniverse/Core/Config/Config.swift` (or create if doesn't exist)

**Add polling configuration**:
```swift
enum PollingConfig {
    static let initialInterval: TimeInterval = 2.0      // Start at 2 seconds
    static let maxInterval: TimeInterval = 10.0         // Max 10 seconds
    static let timeout: TimeInterval = 120.0            // 2 minutes total
    static let backoffMultiplier: Double = 1.5          // Exponential growth
}
```

**Update `pollJobStatus` to use config**:
```swift
var interval = PollingConfig.initialInterval
let maxInterval = PollingConfig.maxInterval
let timeout = PollingConfig.timeout
```

---

### 4.2 URLSession Timeout

**File**: `BananaUniverse/Core/Services/SupabaseService.swift`

**Verify URLSession timeout > polling timeout**:
```swift
private let session: URLSession = {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 30.0       // Individual request: 30s
    config.timeoutIntervalForResource = 150.0     // Total resource: 150s (> 120s polling)
    return URLSession(configuration: config)
}()
```

---

## Part 5: Backward Compatibility Strategy

### Phase 2 (During iOS Migration)

**Keep fallback to old endpoint** (safety net):

```swift
// In processImage method
do {
    // Try new polling pattern
    let submitResult = try await supabaseService.submitImageJob(...)
    let finalResult = try await pollJobStatus(jobId: submitResult.jobId)

} catch {
    // Fallback to old synchronous endpoint
    print("⚠️ [FALLBACK] Polling failed, trying synchronous endpoint:", error)

    let steveJobsResult = try await supabaseService.processImageSteveJobsStyle(
        imageURL: imageURL,
        prompt: originalPrompt
    )

    // ... handle result from old endpoint ...
}
```

**Rationale**: If new polling fails (network issue, backend bug), fall back to old reliable endpoint.

**Remove fallback**: Phase 4 (after 2 weeks of stable polling).

---

### Phase 4 (After Stable Migration)

**Remove fallback code**:
1. Delete `processImageSteveJobsStyle` method
2. Remove try/catch fallback logic
3. Test without safety net

---

## Part 6: Testing Checklist

### Local Testing (Before TestFlight)

**Setup**:
```bash
# Run local Supabase
cd /path/to/banana.universe
supabase start

# Note local endpoint (usually http://localhost:54321)
```

**Update Config.swift** (temporarily):
```swift
#if DEBUG
let supabaseURL = "http://localhost:54321"
#else
let supabaseURL = "https://your-project.supabase.co"
#endif
```

**Tests**:
- [ ] Submit job → receives job_id within 2 seconds
- [ ] Poll status → receives "processing" first, then "completed"
- [ ] Display processed image in ChatView
- [ ] Timeout after 120 seconds → shows error
- [ ] Network drop mid-polling → reconnects, resumes polling
- [ ] Invalid prompt → shows error, credit refunded

---

### TestFlight Testing (Before App Store)

**Build & Upload**:
```bash
# Archive app
xcodebuild archive -workspace BananaUniverse.xcworkspace \
  -scheme BananaUniverse -archivePath build/BananaUniverse.xcarchive

# Upload to TestFlight
xcodebuild -exportArchive -archivePath build/BananaUniverse.xcarchive \
  -exportPath build/BananaUniverse.ipa -exportOptionsPlist ExportOptions.plist
```

**Manual tests**:
- [ ] Happy path: Submit → Poll → Display result
- [ ] Edge case: Kill app mid-polling → relaunch → job completes (if job_history used)
- [ ] Edge case: Switch to background → return → polling continues
- [ ] Concurrency: Submit 3 jobs simultaneously → all complete
- [ ] Premium user: Unlimited polling, no credit check

---

### Production Testing (After App Store Approval)

**Monitor**:
- Check Sentry for crash reports
- Check analytics for timeout rate
- Check support tickets for user complaints
- Check App Store reviews (1-2 star reviews mentioning "slow")

**Metrics** (via Firebase Analytics or similar):
- Event: `job_submitted` (count)
- Event: `job_completed` (count, duration)
- Event: `job_timeout` (count)
- Event: `job_failed` (count, error)

---

## Part 7: Error Handling Strategy

### Network Errors

**Scenario**: iOS loses internet mid-polling.

**Handling**:
```swift
do {
    let status = try await checkJobStatus(jobId: jobId)
} catch {
    // Log error
    print("⚠️ [POLLING] Network error:", error)

    // Don't throw immediately, retry
    if pollingAttempts < 3 {
        try await Task.sleep(nanoseconds: 2_000_000_000)
        continue  // Retry
    } else {
        throw error  // Give up after 3 retries
    }
}
```

---

### Timeout Handling

**Scenario**: Job takes >120 seconds.

**Handling**:
```swift
// In pollJobStatus
if elapsed >= timeout {
    // Show user-friendly error
    throw ChatError.jobTimeout
}

// In processImage catch block
catch ChatError.jobTimeout {
    errorMessage = "Processing took too long. Your credit has been refunded. Please try again."

    // Note: Backend refunds credit automatically on timeout
}
```

---

### Invalid Job Status

**Scenario**: Backend returns unknown status (e.g., "pending", "cancelled").

**Handling**:
```swift
switch statusString {
case "completed", "failed", "processing", "queued":
    // Handle known cases
default:
    // Log unknown status
    print("⚠️ [POLLING] Unknown status:", statusString)

    // Treat as "processing" (optimistic)
    jobStatus = .processing(elapsedTime: Int(elapsed))
}
```

---

## Part 8: UI/UX Improvements

### Progress Feedback

**Current**: Generic "Processing..."

**Improved**:
```swift
// In pollJobStatus
if let queuePosition = statusResponse.queuePosition {
    addAssistantMessage(
        content: "⏳ Queue position: \(queuePosition). Estimated wait: \(queuePosition * 5)s",
        image: nil
    )
}

// After 30 seconds
if elapsed > 30 {
    addAssistantMessage(
        content: "🎨 Still processing... This usually takes 15-30 seconds.",
        image: nil
    )
}
```

---

### Retry Button (On Timeout)

**Add to ChatView**:
```swift
if case .failed(let error) = viewModel.jobStatus {
    VStack {
        Text(error)
            .foregroundColor(.red)

        Button("Retry") {
            viewModel.retryLastJob()
        }
        .buttonStyle(.borderedProminent)
    }
}
```

**Add to ChatViewModel**:
```swift
func retryLastJob() {
    guard let lastJobId = currentJobID else { return }

    Task {
        do {
            jobStatus = .processing(elapsedTime: 0)
            let result = try await pollJobStatus(jobId: lastJobId)
            // ... handle result ...
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

---

## Part 9: Deployment Steps

### Step 1: Prepare Branch

```bash
git checkout -b feature/async-polling
git pull origin main
```

---

### Step 2: Implement Changes

(Code implementation happens after plan approval)

**Order**:
1. Create new models (SubmitJobResponse, CheckStatusResponse, JobStatusResult)
2. Update SupabaseService (submitImageJob, checkJobStatus)
3. Update ChatViewModel (pollJobStatus, new processImage)
4. Update ChatView (optional UI enhancements)
5. Update error enums

---

### Step 3: Test Locally

```bash
# Run Supabase locally
supabase start

# Run iOS app in simulator
open BananaUniverse.xcworkspace
# Cmd + R
```

**Test checklist** (see Part 6).

---

### Step 4: Submit to TestFlight

```bash
# Increment build number
agvtool next-version -all

# Archive
xcodebuild archive -workspace BananaUniverse.xcworkspace \
  -scheme BananaUniverse -archivePath build/BananaUniverse.xcarchive

# Upload
xcodebuild -exportArchive ...
```

---

### Step 5: Test on TestFlight

**Internal testing** (24 hours):
- Test on physical device (iPhone 12+, iOS 15+)
- Test with low network (4G, airplane mode toggle)
- Test with multiple jobs

**External testing** (optional, 3-5 days):
- Invite 5-10 beta testers
- Collect feedback
- Fix critical bugs

---

### Step 6: Submit to App Store

**Pre-submission checklist**:
- [ ] All tests pass
- [ ] No Sentry errors
- [ ] TestFlight feedback addressed
- [ ] App Store screenshots updated (if UI changed)
- [ ] Release notes written

**Submit**:
- App Store Connect → My Apps → BananaUniverse → + Version
- Upload build from TestFlight
- Submit for review

**Wait**: 1-2 days for App Store approval.

---

## Part 10: Rollback Procedure

### Scenario: Phase 2 iOS deployment fails

**Symptoms**:
- Users report "timeout" errors
- Crash reports spike in Sentry
- App Store reviews: "App doesn't work anymore"

**Rollback steps**:

1. **Build hotfix**:
   - Revert `ChatViewModel.swift` to old `processImageSteveJobsStyle` call
   - Revert `SupabaseService.swift` (remove new methods)
   - Bump version: 1.2.1 → 1.2.2

2. **Submit hotfix to App Store**:
   - Request expedited review (mention critical bug)
   - Approval time: 1-2 hours

3. **Notify users** (optional):
   - In-app banner: "We're fixing a bug. Please update to v1.2.2."

4. **Investigate root cause**:
   - Check Sentry logs
   - Check backend logs (Supabase)
   - Test locally

5. **Fix & re-deploy**:
   - Fix bug
   - Test on TestFlight (2-3 days)
   - Re-submit to App Store

**Time to rollback**: 2-4 hours (build + App Store expedited review)

**Impact**: Users on old version (1.2.1) experience errors until they update.

---

## Part 11: Performance Optimization

### Reduce Polling Frequency (After Data Collection)

**Analyze metrics** (after Phase 3):
- If 90% of jobs complete in <15 seconds:
  - Reduce initial interval: 2s → 1s
  - Reduce max interval: 10s → 5s
- If 90% of jobs take >30 seconds:
  - Increase initial interval: 2s → 5s
  - Keep max interval: 10s

**Update PollingConfig.swift**:
```swift
static let initialInterval: TimeInterval = 1.0  // Optimized
static let maxInterval: TimeInterval = 5.0      // Optimized
```

---

### Parallel Operations (Optional)

**Current**: Sequential download + display.

**Optimized**: Download + update UI in parallel.

```swift
// After receiving completed status
async let imageDownload = URLSession.shared.data(from: url)
async let databaseUpdate = updateJobHistory(jobId: jobId, status: "completed")

let (imageData, _) = try await imageDownload
let _ = try await databaseUpdate

// Display image
processedImage = UIImage(data: imageData)
```

---

## Part 12: Monitoring & Analytics

### Track Polling Efficiency

**Add analytics events**:
```swift
// In pollJobStatus
Analytics.logEvent("job_polling_started", parameters: [
    "job_id": jobId
])

// After completion
Analytics.logEvent("job_polling_completed", parameters: [
    "job_id": jobId,
    "polling_attempts": pollingAttempts,
    "elapsed_time": elapsed
])

// On timeout
Analytics.logEvent("job_polling_timeout", parameters: [
    "job_id": jobId,
    "polling_attempts": pollingAttempts
])
```

**Dashboard queries**:
- Average polling attempts per job (target: 5-10)
- Timeout rate (target: <1%)
- Average time to completion (target: 15-30 seconds)

---

## Summary

**Phase 2 Deliverables**:
- ✅ New models created (SubmitJobResponse, CheckStatusResponse, JobStatusResult)
- ✅ SupabaseService updated (submitImageJob, checkJobStatus)
- ✅ ChatViewModel updated (polling loop with exponential backoff)
- ✅ Error handling (timeout, network errors, unknown status)
- ✅ UI enhancements (queue position, polling attempts)
- ✅ TestFlight build deployed
- ✅ Backward compatibility (fallback to old endpoint)

**Ready for Phase 3**: Production monitoring.

---

**Document Version**: 1.0
**Last Updated**: 2025-11-13
**Owner**: iOS Team
