# Quick Reference Card - iOS Testing Patterns

## 🚀 Common Testing Patterns

### Basic Test Structure

```swift
func testFeature_Condition_ExpectedResult() async {
    // Given
    mockService.setupSuccess(data: expectedData)

    // When
    await sut.performAction()

    // Then
    XCTAssertEqual(sut.result, expected)
}
```

---

## 🔧 Mock Service Setup

### Success Scenarios

```swift
// Return specific data
mockThemeService.setupSuccess(themes: [Theme.mockCinematic])

// Return specific credit amount
mockCreditService.setupSuccess(credits: 100)

// Return custom response
mockVideoService.setupSuccess(jobId: "job-123", status: "queued")
```

### Error Scenarios

```swift
// Network failure
mockService.setupFailure(error: AppError.networkFailure)

// Insufficient credits
mockCreditService.setupInsufficientCredits()

// Unauthorized
mockService.setupFailure(error: AppError.unauthorized)
```

### Advanced Configuration

```swift
// Add network delay
mockService.simulatedDelay = 0.5

// Verify call count
XCTAssertEqual(mockService.fetchThemesCallCount, 1)

// Verify specific call
XCTAssertTrue(mockService.verifyRequestMade(
    userId: "user-123",
    themeId: "theme-1"
))
```

---

## ✅ Common Assertions

### Equality

```swift
XCTAssertEqual(sut.count, 5)
XCTAssertNotEqual(sut.value, 0)
```

### Boolean

```swift
XCTAssertTrue(sut.isValid)
XCTAssertFalse(sut.isLoading)
```

### Nil Checks

```swift
XCTAssertNil(sut.errorMessage)
XCTAssertNotNil(sut.user)
```

### Collections

```swift
XCTAssertTrue(sut.items.isEmpty)
XCTAssertFalse(sut.results.isEmpty)
XCTAssertEqual(sut.themes.count, 3)
```

### Error Handling

```swift
await assertThrowsError(try await sut.action()) { error in
    XCTAssertEqual(error as? AppError, AppError.networkFailure)
}
```

---

## 🎯 Testing ViewModels

### Test Initial State

```swift
func testInitialState_PropertiesAreCorrect() {
    XCTAssertEqual(sut.count, 0)
    XCTAssertTrue(sut.items.isEmpty)
    XCTAssertFalse(sut.isLoading)
}
```

### Test Data Loading

```swift
func testLoadData_Success_PopulatesData() async {
    // Given
    mockService.setupSuccess(data: mockData)

    // When
    await sut.loadData()

    // Then
    XCTAssertFalse(sut.items.isEmpty)
    XCTAssertFalse(sut.isLoading)
}
```

### Test Error Handling

```swift
func testLoadData_Failure_ShowsError() async {
    // Given
    mockService.setupFailure(error: AppError.networkFailure)

    // When
    await sut.loadData()

    // Then
    XCTAssertTrue(sut.showingErrorAlert)
    XCTAssertNotNil(sut.errorMessage)
}
```

### Test Validation

```swift
func testCanSubmit_ValidData_ReturnsTrue() {
    // Given
    sut.field1 = "valid"
    sut.field2 = "valid"

    // Then
    XCTAssertTrue(sut.canSubmit)
}

func testCanSubmit_InvalidData_ReturnsFalse() {
    // Given
    sut.field1 = ""

    // Then
    XCTAssertFalse(sut.canSubmit)
}
```

---

## 🌐 Testing Services

### Test HTTP Success

```swift
func testFetch_Success_ReturnsData() async throws {
    // Given
    mockURLSession.mockData = validJSON
    mockURLSession.mockResponse = successResponse()

    // When
    let result = try await sut.fetch()

    // Then
    XCTAssertEqual(result.count, 2)
}
```

### Test HTTP Errors

```swift
func testFetch_404_ThrowsNotFoundError() async {
    // Given
    mockURLSession.mockResponse = HTTPURLResponse(
        url: testURL,
        statusCode: 404,
        httpVersion: nil,
        headerFields: nil
    )

    // When/Then
    await assertThrowsError(try await sut.fetch())
}
```

### Test Network Errors

```swift
func testFetch_Timeout_ThrowsTimeoutError() async {
    // Given
    mockURLSession.mockError = NSError(
        domain: NSURLErrorDomain,
        code: NSURLErrorTimedOut
    )

    // When/Then
    await assertThrowsError(try await sut.fetch()) { error in
        XCTAssertEqual(error as? AppError, AppError.networkTimeout)
    }
}
```

---

## 📦 Test Data Builders

### Create Mock Themes

```swift
// Single theme
let theme = Theme.mockCinematic

// Multiple themes
let themes = Theme.mockThemes // [Cinematic, Anime, Realistic]

// Featured themes only
let featured = Theme.mockFeaturedThemes

// Custom theme
let custom = TestDataBuilder.theme(
    name: "Custom",
    isFeatured: true,
    cost: 10
)

// Multiple custom themes
let many = TestDataBuilder.themes(count: 10, featured: 3)
```

### Create Mock Requests

```swift
let request = VideoGenerationRequest.mockRequest

let custom = TestDataBuilder.videoRequest(
    userId: "user-123",
    themeId: "theme-1",
    prompt: "Test prompt"
)
```

---

## ⏱️ Testing Async Operations

### Basic Async Test

```swift
func testAsyncOperation() async {
    await sut.asyncMethod()
    XCTAssertTrue(sut.completed)
}
```

### Async with Error Handling

```swift
func testAsyncWithError() async throws {
    try await sut.asyncMethodThatThrows()
    XCTAssertTrue(sut.success)
}
```

### Async with Timeout

```swift
func testAsyncWithTimeout() async throws {
    try await waitForCondition(timeout: 5.0) {
        await sut.isReady
    }
}
```

---

## 🔄 Testing State Changes

### Test Loading States

```swift
func testAction_UpdatesLoadingState() async {
    // When: Start action
    let task = Task {
        await sut.performAction()
    }

    // Then: Should be loading
    try? await Task.sleep(nanoseconds: 100_000_000)
    XCTAssertTrue(sut.isLoading)

    // Wait for completion
    await task.value

    // Then: Should not be loading
    XCTAssertFalse(sut.isLoading)
}
```

### Test Property Updates

```swift
func testAction_UpdatesProperty() async {
    // Given
    XCTAssertEqual(sut.count, 0)

    // When
    await sut.increment()

    // Then
    XCTAssertEqual(sut.count, 1)
}
```

---

## 🔍 Testing Search/Filter

```swift
func testSearch_EmptyQuery_ShowsAll() {
    sut.searchQuery = ""
    XCTAssertEqual(sut.filteredItems.count, sut.allItems.count)
}

func testSearch_WithQuery_FiltersResults() {
    sut.searchQuery = "test"
    XCTAssertTrue(sut.filteredItems.allSatisfy {
        $0.name.contains("test")
    })
}

func testSearch_NoMatches_ReturnsEmpty() {
    sut.searchQuery = "nonexistent"
    XCTAssertTrue(sut.filteredItems.isEmpty)
}
```

---

## 🎮 Testing User Interactions

### Test Button Enable/Disable

```swift
func testButton_ValidInput_IsEnabled() {
    sut.inputField = "valid"
    XCTAssertTrue(sut.buttonEnabled)
}

func testButton_InvalidInput_IsDisabled() {
    sut.inputField = ""
    XCTAssertFalse(sut.buttonEnabled)
}
```

### Test Form Submission

```swift
func testSubmit_ValidForm_Succeeds() async {
    // Given
    sut.field1 = "valid"
    sut.field2 = "valid"
    mockService.setupSuccess()

    // When
    await sut.submit()

    // Then
    XCTAssertTrue(sut.submitted)
    XCTAssertFalse(sut.showingError)
}
```

---

## 🔁 Testing Concurrent Operations

```swift
func testConcurrentCalls_HandleCorrectly() async {
    mockService.setupSuccess()

    await withTaskGroup(of: Void.self) { group in
        for _ in 0..<5 {
            group.addTask {
                await self.sut.performAction()
            }
        }
    }

    XCTAssertEqual(sut.completedCount, 5)
}
```

---

## 🎭 Setup & Teardown

### Basic Setup

```swift
override func setUp() {
    super.setUp()

    mockService = MockService()
    sut = ViewModel(service: mockService)
}

override func tearDown() {
    sut = nil
    mockService = nil

    super.tearDown()
}
```

### Setup with Configuration

```swift
override func setUp() {
    super.setUp()

    mockService = MockService()
    mockUserDefaults = MockUserDefaultsManager()
    mockUserDefaults.setupTestState(
        userId: "test-user",
        language: "en"
    )

    sut = ViewModel(
        service: mockService,
        userDefaults: mockUserDefaults
    )
}
```

---

## 📝 Test Naming Examples

```swift
// ✅ Good: Clear and descriptive
func testLoadData_Success_PopulatesThemes()
func testGenerateVideo_InsufficientCredits_ShowsError()
func testSearchQuery_WithMatchingName_FiltersThemes()

// ❌ Bad: Unclear
func testLoadData()
func testError()
func testSearch()
```

---

## 🚨 Common Pitfalls

### ❌ Missing await

```swift
// Wrong
func testAsync() {
    sut.asyncMethod() // Warning!
}

// Correct
func testAsync() async {
    await sut.asyncMethod()
}
```

### ❌ Shared state

```swift
// Wrong
static var sharedData = []

// Correct
var testData: [Item] = []
override func setUp() {
    testData = [] // Fresh each time
}
```

### ❌ Using real services

```swift
// Wrong
let service = RealService.shared

// Correct
let mockService = MockService()
```

---

## 🎯 Quick Commands

```bash
# Run all tests
Cmd + U

# Run specific test file
Click diamond next to class name

# Run single test
Click diamond next to test method

# View coverage
Report Navigator → Coverage tab

# Clean build
Cmd + Shift + K
```

---

## 📊 Coverage Targets

| Component | Target |
|-----------|--------|
| ViewModels | 80%+ |
| Services | 70%+ |
| Models | 60%+ |
| Overall | 60%+ |

---

## ✅ Pre-Flight Checklist

Before committing tests:

- [ ] All tests pass (Cmd + U)
- [ ] No warnings
- [ ] Coverage meets targets
- [ ] Tests are independent
- [ ] Tests are fast (<5s total)
- [ ] Descriptive test names
- [ ] Given-When-Then structure
- [ ] Mocks used (not real services)

---

**Quick Reference Version 1.0**
**For: iOS Unit Testing with XCTest**
**Pattern: Given-When-Then + Mocks + DI**
