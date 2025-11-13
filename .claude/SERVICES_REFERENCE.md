# Services Reference

Complete documentation of all services, their methods, responsibilities, and usage patterns.

## Core Services

### SupabaseService

Main service for Supabase operations (auth, database, storage).

**Location:** `Core/Services/SupabaseService.swift`

**Initialization:**
```swift
static let shared = SupabaseService()
let client: SupabaseClient
```

**Authentication Methods:**

```swift
// Sign in with email/password
func signIn(email: String, password: String) async throws

// Sign up new user
func signUp(email: String, password: String) async throws

// Sign out current user
func signOut() async throws

// Get current authenticated user
func getCurrentUser() -> User?

// Get current session (with JWT token)
func getCurrentSession() async throws -> Session?
```

**Storage Methods:**

```swift
// Upload image and return public URL
func uploadImageToStorage(
    imageData: Data, 
    fileName: String? = nil
) async throws -> String

// Download image by path
func downloadImage(path: String) async throws -> Data

// Delete image from storage
func deleteImage(path: String) async throws
```

**Database Methods:**

```swift
// Process image via Edge Function
func processImage(
    imageURL: String,
    prompt: String,
    toolID: String,
    userState: UserState
) async throws -> ProcessImageResponse

// Get user's quota status
func getQuota(userId: String) async throws -> QuotaInfo

// Get processed images history
func getProcessedImages(
    limit: Int = 50,
    offset: Int = 0
) async throws -> [ProcessedImage]

// Get user profile
func getUserProfile() async throws -> UserProfile?
```

**Usage:**
```swift
@StateObject private var supabaseService = SupabaseService.shared

// Process image
let result = try await supabaseService.processImage(
    imageURL: imageURL,
    prompt: prompt,
    toolID: toolID,
    userState: userState
)
```

---

### HybridCreditManager

Manages quota/credit system for both authenticated and anonymous users.

**Location:** `Core/Services/HybridCreditManager.swift`

**Key Features:**
- Tracks daily quota usage
- Handles quota reset at midnight UTC
- Supports both authenticated and anonymous users
- Validates quota before processing
- Updates quota after successful processing

**Methods:**

```swift
// Check if user has available quota
func hasAvailableQuota() async -> Bool

// Get current quota info
func getCurrentQuota() async -> QuotaInfo

// Consume quota (called after successful processing)
func consumeQuota() async throws

// Refresh quota from server
func refreshQuota() async throws
```

**Usage:**
```swift
@StateObject private var creditManager = HybridCreditManager.shared

// Check quota before processing
guard await creditManager.hasAvailableQuota() else {
    // Show paywall
    return
}

// After successful processing
try await creditManager.consumeQuota()
```

---

### HybridAuthService

Handles authentication for both authenticated and anonymous users.

**Location:** `Core/Services/HybridAuthService.swift`

**Methods:**

```swift
// Initialize anonymous session
func initializeAnonymousSession() async throws

// Sign in with email/password
func signIn(email: String, password: String) async throws

// Sign up new user
func signUp(email: String, password: String) async throws

// Sign out
func signOut() async throws

// Get current user state
func getCurrentUserState() -> UserState
```

**Usage:**
```swift
@StateObject private var authService = HybridAuthService.shared

// Initialize on app launch
try await authService.initializeAnonymousSession()

// Get user state
let userState = authService.getCurrentUserState()
```

---

### StorageService

Handles local and remote storage operations.

**Location:** `Core/Services/StorageService.swift`

**Methods:**

```swift
// Save image to Photos app
func saveToPhotos(_ image: UIImage) async throws

// Share image
func shareImage(_ image: UIImage, from viewController: UIViewController)

// Cache image locally
func cacheImage(url: URL, image: UIImage)

// Get cached image
func getCachedImage(url: URL) -> UIImage?
```

**Usage:**
```swift
@StateObject private var storageService = StorageService.shared

// Save processed image
try await storageService.saveToPhotos(processedImage)
```

---

### StoreKitService

Manages in-app purchases and subscriptions via StoreKit 2.

**Location:** `Core/Services/StoreKitService.swift`

**Methods:**

```swift
// Load available products
func loadProducts() async throws -> [Product]

// Purchase product
func purchase(_ product: Product) async throws -> Transaction

// Check subscription status
func checkSubscriptionStatus() async throws -> SubscriptionStatus

// Restore purchases
func restorePurchases() async throws

// Get current subscription
func getCurrentSubscription() async -> Subscription?
```

**Products:**
- `weekly_pro`: $4.99/week
- `yearly_pro`: $79.99/year

**Usage:**
```swift
@StateObject private var storeKitService = StoreKitService.shared

// Load products
let products = try await storeKitService.loadProducts()

// Purchase
let transaction = try await storeKitService.purchase(product)

// Check status
let status = try await storeKitService.checkSubscriptionStatus()
```

---

### SeasonalManager

Manages seasonal/holiday content and features.

**Location:** `Core/Services/SeasonalManager.swift`

**Methods:**

```swift
// Get current seasonal mode
func getCurrentSeasonalMode() -> SeasonalMode

// Check if seasonal tools should be shown
func shouldShowSeasonalTools() -> Bool

// Get seasonal tool prompts
func getSeasonalPrompt(for toolID: String) -> String?
```

**Seasonal Modes:**
- `thanksgiving`: November
- `christmas`: December
- `newYear`: January
- `none`: Default mode

**Usage:**
```swift
@StateObject private var seasonalManager = SeasonalManager.shared

let mode = seasonalManager.getCurrentSeasonalMode()
let shouldShow = seasonalManager.shouldShowSeasonalTools()
```

---

### AppState

Global application state singleton.

**Location:** `Core/Services/AppState.swift`

**Properties:**

```swift
@Published var userState: UserState
@Published var isPremium: Bool
@Published var quotaUsed: Int
@Published var quotaLimit: Int
@Published var seasonalMode: SeasonalMode
```

**Methods:**

```swift
// Update user state
func updateUserState(_ state: UserState)

// Update premium status
func updatePremiumStatus(_ isPremium: Bool)

// Update quota
func updateQuota(used: Int, limit: Int)
```

**Usage:**
```swift
@StateObject private var appState = AppState.shared

// Observe changes
appState.$isPremium
    .sink { isPremium in
        // Update UI
    }
```

---

## ViewModel Services

### ChatViewModel

Manages chat interface state and image processing.

**Location:** `Features/Chat/ViewModels/ChatViewModel.swift`

**Properties:**

```swift
@Published var messages: [ChatMessage]
@Published var isLoading: Bool
@Published var errorMessage: String?
@Published var selectedTool: Tool?
```

**Methods:**

```swift
// Process image with selected tool
func processImage(_ image: UIImage, tool: Tool) async

// Send message
func sendMessage(_ message: String)

// Retry failed processing
func retryProcessing(messageID: UUID)
```

**Usage:**
```swift
@StateObject private var viewModel = ChatViewModel()

// Process image
await viewModel.processImage(image, tool: selectedTool)
```

---

### LibraryViewModel

Manages image library/history.

**Location:** `Features/Library/ViewModels/LibraryViewModel.swift`

**Methods:**

```swift
// Load processed images
func loadImages() async

// Refresh images
func refresh() async

// Delete image
func deleteImage(_ image: ProcessedImage) async

// Share image
func shareImage(_ image: ProcessedImage)
```

**Usage:**
```swift
@StateObject private var viewModel = LibraryViewModel()

// Load on appear
.task {
    await viewModel.loadImages()
}
```

---

## Service Dependencies

### Dependency Graph

```
AppState
  ├── HybridAuthService → SupabaseService
  ├── HybridCreditManager → SupabaseService
  ├── StoreKitService (independent)
  ├── SeasonalManager (independent)
  └── StorageService (independent)

ChatViewModel
  ├── SupabaseService
  ├── HybridCreditManager
  └── AppState

LibraryViewModel
  ├── SupabaseService
  └── StorageService
```

### Singleton Pattern

All core services use singleton pattern:
```swift
static let shared = ServiceName()
private init() { }
```

### Service Initialization Order

1. `SupabaseService.shared` - Initialize first (needed by others)
2. `HybridAuthService.shared` - Initialize anonymous session
3. `HybridCreditManager.shared` - Load quota
4. `AppState.shared` - Update global state
5. ViewModels - Initialize with services

---

## Error Handling

### Service Error Types

```swift
enum SupabaseError: Error {
    case invalidURL
    case quotaExceeded
    case networkError
    case authenticationFailed
    case processingFailed
}

enum StoreKitError: Error {
    case productNotFound
    case purchaseFailed
    case subscriptionExpired
}
```

### Error Handling Pattern

```swift
do {
    let result = try await service.performAction()
    // Handle success
} catch SupabaseError.quotaExceeded {
    // Show paywall
} catch SupabaseError.networkError {
    // Show retry option
} catch {
    // Generic error handling
    print("Error: \(error.localizedDescription)")
}
```

---

## Testing Services

### Mock Services

For testing, create mock implementations:

```swift
class MockSupabaseService: SupabaseService {
    override func processImage(...) async throws -> ProcessImageResponse {
        // Return mock response
    }
}
```

### Service Testing Pattern

```swift
func testServiceMethod() async {
    let service = MockService()
    let result = try await service.method()
    XCTAssertNotNil(result)
}
```

---

## Best Practices

### 1. Always Use @MainActor for UI Updates

```swift
@MainActor
class Service: ObservableObject {
    @Published var state: State
}
```

### 2. Use Async/Await for All Network Calls

```swift
func fetchData() async throws -> Data {
    // Network call
}
```

### 3. Handle Errors Properly

```swift
do {
    try await service.call()
} catch {
    // Log and handle error
}
```

### 4. Use Singleton for Shared Services

```swift
static let shared = Service()
```

### 5. Update AppState After Critical Operations

```swift
try await authService.signIn(...)
AppState.shared.updateUserState(newState)
```

