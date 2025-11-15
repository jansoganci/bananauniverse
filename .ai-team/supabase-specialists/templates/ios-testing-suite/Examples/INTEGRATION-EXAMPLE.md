# Integration Example: Adding Tests to Existing Project

## Quick Start (15 Minutes)

This guide shows you exactly how to integrate the testing suite into your existing iOS project.

---

## Step 1: Add Service Protocols (5 minutes)

Create a new file: `Core/Protocols/ServiceProtocols.swift`

```swift
import Foundation
import UIKit

// MARK: - Service Protocols

/// Protocol for theme fetching operations
protocol ThemeServiceProtocol {
    func fetchThemes() async throws -> [Theme]
}

/// Protocol for credit management operations
protocol CreditServiceProtocol {
    func getCredits(userId: String) async throws -> Int
    func deductCredits(userId: String, amount: Int) async throws
    func addCredits(userId: String, amount: Int) async throws
}

/// Protocol for video generation operations
protocol VideoGenerationServiceProtocol {
    func generateVideo(request: VideoGenerationRequest) async throws -> VideoGenerationResponse
}

/// Protocol for image upload operations
protocol ImageUploadServiceProtocol {
    func uploadImage(_ image: UIImage) async throws -> String
}
```

---

## Step 2: Make Services Conform (5 minutes)

### Update ThemeService.swift

**Before:**
```swift
class ThemeService {
    static let shared = ThemeService()

    func fetchThemes() async throws -> [Theme] {
        // Implementation
    }
}
```

**After:**
```swift
class ThemeService: ThemeServiceProtocol {  // ← Add protocol conformance
    static let shared = ThemeService()

    func fetchThemes() async throws -> [Theme] {
        // Implementation (no changes needed)
    }
}
```

### Update CreditService.swift

```swift
class CreditService: CreditServiceProtocol {  // ← Add protocol conformance
    static let shared = CreditService()

    func getCredits(userId: String) async throws -> Int {
        // Implementation
    }

    func deductCredits(userId: String, amount: Int) async throws {
        // Implementation
    }

    func addCredits(userId: String, amount: Int) async throws {
        // Implementation
    }
}
```

### Update VideoGenerationService.swift

```swift
class VideoGenerationService: VideoGenerationServiceProtocol {  // ← Add protocol conformance
    static let shared = VideoGenerationService()

    func generateVideo(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        // Implementation
    }
}
```

---

## Step 3: Add Dependency Injection to ViewModels (5 minutes)

### Update HomeViewModel.swift

**Before:**
```swift
class HomeViewModel: ObservableObject {
    @Published var allThemes: [Theme] = []
    @Published var creditsRemaining: Int = 0
    @Published var isLoading: Bool = false

    func loadData() async {
        do {
            // Directly uses singleton
            self.allThemes = try await ThemeService.shared.fetchThemes()
            self.creditsRemaining = try await CreditService.shared.getCredits(userId: userId)
        } catch {
            // Error handling
        }
    }
}
```

**After:**
```swift
class HomeViewModel: ObservableObject {
    @Published var allThemes: [Theme] = []
    @Published var creditsRemaining: Int = 0
    @Published var isLoading: Bool = false

    // ← Add dependencies
    private let themeService: ThemeServiceProtocol
    private let creditService: CreditServiceProtocol

    // ← Add dependency injection
    init(
        themeService: ThemeServiceProtocol = ThemeService.shared,
        creditService: CreditServiceProtocol = CreditService.shared
    ) {
        self.themeService = themeService
        self.creditService = creditService
    }

    func loadData() async {
        do {
            // ← Use injected dependencies
            self.allThemes = try await themeService.fetchThemes()
            self.creditsRemaining = try await creditService.getCredits(userId: userId)
        } catch {
            // Error handling
        }
    }
}
```

**Key Points:**
- Default parameters use `.shared` singletons
- Production code works exactly the same (no changes needed in views)
- Tests can inject mocks

### Update ModelDetailViewModel.swift

```swift
class ModelDetailViewModel: ObservableObject {
    @Published var prompt: String = ""
    @Published var isGenerating: Bool = false
    @Published var creditsRemaining: Int = 0

    // Add dependencies
    private let videoService: VideoGenerationServiceProtocol
    private let creditService: CreditServiceProtocol
    private let imageUploadService: ImageUploadServiceProtocol

    // Add dependency injection
    init(
        theme: Theme,
        videoService: VideoGenerationServiceProtocol = VideoGenerationService.shared,
        creditService: CreditServiceProtocol = CreditService.shared,
        imageUploadService: ImageUploadServiceProtocol = ImageUploadService.shared
    ) {
        self.theme = theme
        self.videoService = videoService
        self.creditService = creditService
        self.imageUploadService = imageUploadService
    }

    func generateVideo() async {
        // Use injected dependencies
        let response = try await videoService.generateVideo(request: request)
    }
}
```

---

## Step 4: Add Test Files to Xcode (3 minutes)

1. **Create test target** (if you don't have one):
   - File → New → Target
   - Choose "Unit Testing Bundle"
   - Name: `YourAppTests`

2. **Add test files**:
   - Drag `ios-testing-suite/Tests/` folder into Xcode
   - Drag `ios-testing-suite/Mocks/` folder into Xcode
   - Drag `ios-testing-suite/Helpers/` folder into Xcode
   - Ensure all files are added to test target (check Target Membership)

3. **Update module imports**:
   - In all test files, change:
     ```swift
     @testable import YourAppName
     ```
   - To your actual app module name:
     ```swift
     @testable import VideoAIApp  // Your actual name
     ```

---

## Step 5: Run Your First Test (2 minutes)

1. Open `HomeViewModelTests.swift`
2. Press `Cmd + U` to run tests
3. Watch tests pass! 🎉

**Expected output:**
```
Test Suite 'HomeViewModelTests' started
✓ testInitialState_PropertiesAreSetCorrectly (0.001s)
✓ testLoadData_Success_PopulatesThemes (0.015s)
✓ testLoadData_Success_SeparatesFeaturedThemes (0.012s)
✓ testSearchQuery_WithMatchingName_FiltersThemes (0.018s)
...
Test Suite 'HomeViewModelTests' passed
Executed 30 tests, with 0 failures (0 unexpected) in 0.234s
```

---

## Common Integration Issues

### Issue 1: "Cannot find type 'Theme' in scope"

**Solution:** Ensure test target has access to your models:

1. Select your model files (Theme.swift, etc.)
2. In File Inspector, check your test target in Target Membership
3. Or: Make models accessible by keeping them in main target only and using `@testable import`

### Issue 2: Views still create ViewModels without injection

**Current:**
```swift
struct HomeView: View {
    @StateObject var viewModel = HomeViewModel()  // Uses default .shared
}
```

**This is fine!** Default parameters handle it:
```swift
init(
    themeService: ThemeServiceProtocol = ThemeService.shared,  // ← Default
    creditService: CreditServiceProtocol = CreditService.shared
)
```

Views don't need to change. They automatically use `.shared` singletons.

### Issue 3: "Expression was not awaited"

**Wrong:**
```swift
func testLoadData() {
    sut.loadData()  // Missing await
}
```

**Correct:**
```swift
func testLoadData() async {  // ← Make test async
    await sut.loadData()     // ← Await the call
}
```

---

## Verify Integration Success

Run this checklist:

- [ ] All 4 test files compile without errors
- [ ] `Cmd + U` runs tests successfully
- [ ] At least 50+ tests pass
- [ ] Production app still works (views create ViewModels normally)
- [ ] Coverage report shows 60%+ coverage (View → Navigators → Show Report Navigator → Coverage)

---

## What Changed in Your App?

### ✅ What Changed:
1. Added protocol definitions
2. Made services conform to protocols
3. Added dependency injection to ViewModels

### ✅ What Didn't Change:
1. Views still work the same
2. Services still work the same
3. No changes to UI code
4. No changes to business logic
5. No changes to API calls

**The only difference:** ViewModels can now accept mock dependencies for testing!

---

## Next Steps

Now that tests are integrated:

1. **Run coverage report:**
   - Product → Test (Cmd + U)
   - View → Navigators → Show Report Navigator
   - Select your test run → Coverage tab
   - Goal: 60%+ coverage

2. **Add more tests:**
   - Use existing tests as templates
   - Follow the patterns in `HomeViewModelTests.swift`
   - Cover your custom ViewModels and Services

3. **Run tests in CI:**
   - Add to GitHub Actions (see TESTING-GUIDE.md)
   - Run before every merge
   - Ensure 60%+ coverage before deploying

---

## Real-World Example: Complete ViewModel Conversion

Here's a complete before/after for a realistic ViewModel:

### Before (No Testing Support)

```swift
class ProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var creditsRemaining: Int = 0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    func loadProfile() async {
        isLoading = true

        do {
            // Direct singleton usage - can't test
            self.user = try await UserService.shared.getProfile()
            self.creditsRemaining = try await CreditService.shared.getCredits(userId: user?.id ?? "")
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func signOut() {
        // Direct singleton usage - can't test
        AuthService.shared.signOut()
    }
}
```

### After (Fully Testable)

```swift
class ProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var creditsRemaining: Int = 0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // Add dependencies
    private let userService: UserServiceProtocol
    private let creditService: CreditServiceProtocol
    private let authService: AuthServiceProtocol

    // Add dependency injection with defaults
    init(
        userService: UserServiceProtocol = UserService.shared,
        creditService: CreditServiceProtocol = CreditService.shared,
        authService: AuthServiceProtocol = AuthService.shared
    ) {
        self.userService = userService
        self.creditService = creditService
        self.authService = authService
    }

    func loadProfile() async {
        isLoading = true

        do {
            // Use injected dependencies - testable!
            self.user = try await userService.getProfile()
            self.creditsRemaining = try await creditService.getCredits(userId: user?.id ?? "")
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func signOut() {
        // Use injected dependency - testable!
        authService.signOut()
    }
}
```

### The Test (Now Possible!)

```swift
func testLoadProfile_Success_LoadsUserData() async {
    // Given: Mock services
    let mockUser = User(id: "123", name: "John")
    mockUserService.setupSuccess(user: mockUser)
    mockCreditService.setupSuccess(credits: 50)

    // When: Loading profile
    await sut.loadProfile()

    // Then: Should load data
    XCTAssertEqual(sut.user?.id, "123")
    XCTAssertEqual(sut.creditsRemaining, 50)
    XCTAssertFalse(sut.isLoading)
    XCTAssertNil(sut.errorMessage)
}
```

---

## Success! 🎉

You now have:
- ✅ 130+ tests covering critical functionality
- ✅ Fully testable ViewModels and Services
- ✅ Mock implementations for all dependencies
- ✅ 60%+ code coverage
- ✅ Foundation for extracting as reusable template

**Total integration time: ~15 minutes**

**What you gained:**
- Confidence to refactor
- Catch bugs before production
- Document expected behavior
- Enable template extraction

Ready to extract this as your iOS template! 🚀
