# iOS Testing Suite - Complete Guide

## 📋 Table of Contents

1. [Overview](#overview)
2. [Installation & Setup](#installation--setup)
3. [Running Tests](#running-tests)
4. [Test Coverage](#test-coverage)
5. [Test Structure](#test-structure)
6. [Writing New Tests](#writing-new-tests)
7. [Best Practices](#best-practices)
8. [Troubleshooting](#troubleshooting)

---

## Overview

This testing suite provides comprehensive unit tests for your iOS application with:

- **120+ test cases** covering ViewModels, Services, and business logic
- **Mock implementations** for all external dependencies
- **Test helpers** for async testing, state observation, and data builders
- **60%+ code coverage** target for production readiness

### What's Included

```
ios-testing-suite/
├── Tests/
│   ├── HomeViewModelTests.swift           (30+ test cases)
│   ├── ModelDetailViewModelTests.swift    (40+ test cases)
│   ├── ThemeServiceTests.swift            (30+ test cases)
│   └── CreditServiceTests.swift           (30+ test cases)
├── Mocks/
│   ├── MockThemeService.swift
│   ├── MockCreditService.swift
│   └── MockVideoGenerationService.swift
├── Helpers/
│   └── TestHelpers.swift
└── TESTING-GUIDE.md (this file)
```

---

## Installation & Setup

### Step 1: Add Files to Your Xcode Project

1. **Open your Xcode project**

2. **Create a Test Target** (if you don't have one):
   - File → New → Target
   - Choose "Unit Testing Bundle"
   - Name it: `YourAppNameTests`
   - Language: Swift
   - Click Finish

3. **Add test files to your test target**:
   - Drag all files from `ios-testing-suite/` into your Xcode project
   - Ensure they're added to your test target (check the box in Target Membership)

### Step 2: Update Module Name

In all test files, replace:
```swift
@testable import YourAppName
```

With your actual app module name:
```swift
@testable import MyVideoApp  // Your actual app name
```

### Step 3: Ensure Testability

In your main app target's Build Settings:
- Search for "Enable Testability"
- Set to **Yes** for Debug configuration

### Step 4: Add Required Protocols

Your production code needs these protocols for dependency injection.

**Add to your project:**

```swift
// MARK: - Service Protocols

protocol ThemeServiceProtocol {
    func fetchThemes() async throws -> [Theme]
}

protocol CreditServiceProtocol {
    func getCredits(userId: String) async throws -> Int
    func deductCredits(userId: String, amount: Int) async throws
    func addCredits(userId: String, amount: Int) async throws
}

protocol VideoGenerationServiceProtocol {
    func generateVideo(request: VideoGenerationRequest) async throws -> VideoGenerationResponse
}

protocol ImageUploadServiceProtocol {
    func uploadImage(_ image: UIImage) async throws -> String
}
```

**Make your services conform:**

```swift
// In your actual service files
class ThemeService: ThemeServiceProtocol {
    static let shared = ThemeService()
    // ... existing implementation
}

class CreditService: CreditServiceProtocol {
    static let shared = CreditService()
    // ... existing implementation
}
```

### Step 5: Add Dependency Injection to ViewModels

Update your ViewModels to accept dependencies:

**Before:**
```swift
class HomeViewModel: ObservableObject {
    init() {
        // Uses ThemeService.shared directly
    }
}
```

**After:**
```swift
class HomeViewModel: ObservableObject {
    private let themeService: ThemeServiceProtocol
    private let creditService: CreditServiceProtocol

    init(
        themeService: ThemeServiceProtocol = ThemeService.shared,
        creditService: CreditServiceProtocol = CreditService.shared
    ) {
        self.themeService = themeService
        self.creditService = creditService
    }
}
```

This allows:
- Production code uses `.shared` singletons (default)
- Tests inject mock services

---

## Running Tests

### From Xcode

**Run all tests:**
- Press `Cmd + U`
- Or: Product → Test

**Run specific test file:**
- Click the diamond icon next to the test class name

**Run single test:**
- Click the diamond icon next to the test method

**Run with coverage:**
- Product → Test (Cmd + U)
- View coverage: View → Navigators → Show Report Navigator → Coverage tab

### From Command Line

```bash
# Run all tests
xcodebuild test \
  -project YourApp.xcodeproj \
  -scheme YourApp \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# Run with coverage
xcodebuild test \
  -project YourApp.xcodeproj \
  -scheme YourApp \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -enableCodeCoverage YES
```

### Continuous Integration (CI)

**GitHub Actions example:**

```yaml
name: iOS Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_15.0.app

      - name: Run tests
        run: |
          xcodebuild test \
            -project YourApp.xcodeproj \
            -scheme YourApp \
            -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
            -enableCodeCoverage YES

      - name: Upload coverage
        uses: codecov/codecov-action@v3
```

---

## Test Coverage

### Viewing Coverage in Xcode

1. Run tests with coverage: `Cmd + U`
2. Open Report Navigator: `Cmd + 9`
3. Select latest test run
4. Click "Coverage" tab

### Current Coverage Targets

| Component | Target | Current Tests |
|-----------|--------|---------------|
| **HomeViewModel** | 80%+ | 30+ test cases |
| **ModelDetailViewModel** | 80%+ | 40+ test cases |
| **ThemeService** | 70%+ | 30+ test cases |
| **CreditService** | 70%+ | 30+ test cases |
| **Overall App** | 60%+ | 130+ test cases |

### Coverage Best Practices

**What to prioritize:**
- ✅ ViewModels (business logic)
- ✅ Services (API calls, data processing)
- ✅ Models with computed properties
- ✅ Error handling paths
- ✅ Validation logic

**What to skip:**
- ⏭️ SwiftUI Views (test with UI tests instead)
- ⏭️ Simple getters/setters
- ⏭️ Framework code
- ⏭️ Configuration files

---

## Test Structure

### Anatomy of a Test File

```swift
import XCTest
@testable import YourAppName

final class HomeViewModelTests: XCTestCase {

    // MARK: - System Under Test
    var sut: HomeViewModel!

    // MARK: - Dependencies (Mocks)
    var mockThemeService: MockThemeService!
    var mockCreditService: MockCreditService!

    // MARK: - Setup & Teardown
    override func setUp() {
        super.setUp()
        // Create fresh mocks for each test
        mockThemeService = MockThemeService()
        mockCreditService = MockCreditService()

        // Create system under test
        sut = HomeViewModel(
            themeService: mockThemeService,
            creditService: mockCreditService
        )
    }

    override func tearDown() {
        // Clean up
        sut = nil
        mockThemeService = nil
        mockCreditService = nil
        super.tearDown()
    }

    // MARK: - Tests
    func testLoadData_Success_PopulatesThemes() async {
        // Given: Mock service returns themes
        mockThemeService.setupSuccess(themes: [Theme.mockCinematic])

        // When: Loading data
        await sut.loadData()

        // Then: Themes should be populated
        XCTAssertEqual(sut.allThemes.count, 1)
        XCTAssertFalse(sut.isLoading)
    }
}
```

### Test Naming Convention

```
test[WhatYouAreTesting]_[Condition]_[ExpectedResult]
```

**Examples:**
- `testLoadData_Success_PopulatesThemes`
- `testGenerateVideo_InsufficientCredits_ShowsError`
- `testSearchQuery_WithMatchingName_FiltersThemes`

### Given-When-Then Pattern

```swift
func testExample() async {
    // Given: Setup initial state and mocks
    mockService.setupSuccess(data: mockData)

    // When: Perform the action being tested
    await sut.performAction()

    // Then: Verify the expected outcome
    XCTAssertEqual(sut.result, expectedValue)
}
```

---

## Writing New Tests

### Example 1: Testing a ViewModel

```swift
func testNewFeature_Success_UpdatesState() async {
    // Given: Mock dependencies
    mockService.setupSuccess(result: expectedResult)

    // When: Call the method
    await sut.newFeature()

    // Then: Verify state changes
    XCTAssertTrue(sut.featureCompleted)
    XCTAssertEqual(sut.result, expectedResult)
    XCTAssertFalse(sut.isLoading)
}
```

### Example 2: Testing Error Handling

```swift
func testNewFeature_NetworkFailure_ShowsError() async {
    // Given: Mock service will fail
    mockService.setupFailure(error: AppError.networkFailure)

    // When: Call the method
    await sut.newFeature()

    // Then: Should show error
    XCTAssertTrue(sut.showingErrorAlert)
    XCTAssertNotNil(sut.errorMessage)
    XCTAssertFalse(sut.featureCompleted)
}
```

### Example 3: Testing Validation

```swift
func testValidation_InvalidInput_ReturnsFalse() {
    // Given: Invalid data
    sut.inputField = ""

    // When: Checking validation
    let isValid = sut.isValid

    // Then: Should be invalid
    XCTAssertFalse(isValid)
}
```

### Example 4: Testing Async Operations

```swift
func testAsyncOperation_CompletesSuccessfully() async throws {
    // Given: Setup
    mockService.setupSuccess()

    // When: Start operation
    try await sut.asyncOperation()

    // Then: Verify completion
    XCTAssertTrue(sut.operationCompleted)
}
```

---

## Best Practices

### ✅ Do's

1. **Test behavior, not implementation**
   ```swift
   // Good: Tests what happens
   XCTAssertEqual(sut.allThemes.count, 2)

   // Bad: Tests how it happens
   XCTAssertTrue(sut.didCallPrivateMethod)
   ```

2. **Use descriptive test names**
   ```swift
   // Good
   func testLoadData_NetworkFailure_ShowsErrorMessage()

   // Bad
   func testLoadData2()
   ```

3. **Keep tests independent**
   ```swift
   // Each test should work in isolation
   override func setUp() {
       // Fresh state for each test
       sut = HomeViewModel(/* fresh mocks */)
   }
   ```

4. **Test edge cases**
   ```swift
   func testSearch_EmptyString_ShowsAllResults()
   func testSearch_WhitespaceOnly_ShowsAllResults()
   func testSearch_SpecialCharacters_HandlesCorrectly()
   ```

5. **Use test helpers**
   ```swift
   // Create reusable test data
   let themes = TestDataBuilder.themes(count: 10, featured: 3)
   ```

### ❌ Don'ts

1. **Don't test framework code**
   ```swift
   // Bad: Testing SwiftUI's behavior
   func testText_SetsFontSize() {
       // SwiftUI already tests this
   }
   ```

2. **Don't use real network calls**
   ```swift
   // Bad: Slow, unreliable
   let realService = ThemeService.shared

   // Good: Fast, reliable
   let mockService = MockThemeService()
   ```

3. **Don't share state between tests**
   ```swift
   // Bad: Tests depend on each other
   static var sharedData = [Theme]()

   // Good: Fresh state each time
   var testData: [Theme] = []
   ```

4. **Don't ignore async warnings**
   ```swift
   // Bad: Incorrect async handling
   func testAsync() {
       sut.asyncMethod() // Warning: call is not awaited
   }

   // Good: Proper async handling
   func testAsync() async {
       await sut.asyncMethod()
   }
   ```

---

## Troubleshooting

### Issue: "No such module 'YourAppName'"

**Solution:**
1. Check that `@testable import YourAppName` matches your actual module name
2. Ensure "Enable Testability" is set to YES in Build Settings
3. Clean build folder: Product → Clean Build Folder (Cmd + Shift + K)

### Issue: Tests fail with "Expression was not awaited"

**Solution:**
```swift
// Wrong
func testSomething() {
    sut.asyncMethod() // Not awaited
}

// Correct
func testSomething() async {
    await sut.asyncMethod()
}
```

### Issue: "Protocol not found"

**Solution:**
Add protocol definitions to your main app target:
```swift
protocol ThemeServiceProtocol {
    func fetchThemes() async throws -> [Theme]
}
```

### Issue: Tests pass individually but fail when run together

**Cause:** Shared state between tests

**Solution:**
Ensure `setUp()` creates fresh instances:
```swift
override func setUp() {
    super.setUp()
    mockService = MockThemeService() // Fresh instance
    sut = HomeViewModel(themeService: mockService)
}
```

### Issue: Slow test execution

**Causes & Solutions:**

1. **Using real services**
   - Solution: Use mocks instead

2. **Large delays in tests**
   ```swift
   // Bad: Real delays
   mockService.simulatedDelay = 2.0

   // Good: No delays in tests
   mockService.simulatedDelay = 0
   ```

3. **Too many tests running**
   - Solution: Run specific test suites during development

### Issue: XCTest assertions don't show helpful messages

**Solution:** Add custom failure messages:
```swift
// Basic
XCTAssertEqual(sut.count, 5)

// Better: Custom message
XCTAssertEqual(
    sut.count,
    5,
    "Expected 5 themes after loading, got \(sut.count)"
)
```

---

## Advanced Topics

### Testing Published Properties

```swift
import Combine

func testPublishedProperty_Updates_TriggersChange() {
    var receivedValues: [Int] = []
    let cancellable = sut.$creditsRemaining
        .sink { value in
            receivedValues.append(value)
        }

    // Trigger changes
    sut.creditsRemaining = 50
    sut.creditsRemaining = 75

    XCTAssertEqual(receivedValues, [0, 50, 75])
    cancellable.cancel()
}
```

### Testing Concurrent Operations

```swift
func testConcurrentOperations_HandleCorrectly() async {
    await withTaskGroup(of: Void.self) { group in
        for _ in 0..<10 {
            group.addTask {
                await self.sut.performOperation()
            }
        }
    }

    // Verify results
    XCTAssertEqual(sut.operationCount, 10)
}
```

### Performance Testing

```swift
func testPerformance_LoadsDataQuickly() {
    mockService.setupSuccess(themes: largeDataset)

    measure {
        let expectation = expectation(description: "Load data")

        Task {
            await sut.loadData()
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5.0)
    }
}
```

---

## Next Steps

### Phase 1: Get to 60% Coverage (Current Goal)

- [x] Add HomeViewModel tests ✅
- [x] Add ModelDetailViewModel tests ✅
- [x] Add ThemeService tests ✅
- [x] Add CreditService tests ✅
- [ ] Run coverage report
- [ ] Fill in any gaps to reach 60%

### Phase 2: Expand Coverage

- [ ] Add ResultViewModel tests
- [ ] Add HistoryViewModel tests
- [ ] Add ProfileViewModel tests
- [ ] Add UserService tests
- [ ] Add ImageUploadService tests

### Phase 3: Integration & UI Tests

- [ ] Add integration tests (real service → mock backend)
- [ ] Add UI tests for critical flows
- [ ] Add snapshot tests for UI consistency

---

## Resources

- [Apple Testing Documentation](https://developer.apple.com/documentation/xctest)
- [Swift Testing Best Practices](https://www.swiftbysundell.com/basics/unit-testing/)
- [Async Testing Guide](https://developer.apple.com/videos/play/wwdc2021/10194/)

---

## Support

If you encounter issues not covered in this guide:

1. Check Xcode console for detailed error messages
2. Ensure all dependencies are properly injected
3. Verify test target has access to all necessary files
4. Review the example tests for patterns to follow

Happy Testing! 🧪
