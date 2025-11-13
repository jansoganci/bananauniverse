import XCTest
import UIKit
@testable import YourAppName // Replace with your actual app module name

// MARK: - ModelDetailViewModel Tests

/// Comprehensive tests for ModelDetailViewModel
/// Tests cover: video generation, validation, image handling, credits, and state management
final class ModelDetailViewModelTests: XCTestCase {

    // MARK: - System Under Test

    var sut: ModelDetailViewModel!

    // MARK: - Dependencies (Mocks)

    var mockVideoService: MockVideoGenerationService!
    var mockCreditService: MockCreditService!
    var mockImageUploadService: MockImageUploadService!
    var mockUserDefaults: MockUserDefaultsManager!

    // MARK: - Test Data

    var testTheme: Theme!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()

        // Create fresh mocks
        mockVideoService = MockVideoGenerationService()
        mockCreditService = MockCreditService()
        mockImageUploadService = MockImageUploadService()
        mockUserDefaults = MockUserDefaultsManager()

        // Setup test data
        testTheme = Theme.mockCinematic
        mockUserDefaults.setupTestState(userId: "test-user-123")

        // Create system under test
        sut = ModelDetailViewModel(
            theme: testTheme,
            videoService: mockVideoService,
            creditService: mockCreditService,
            imageUploadService: mockImageUploadService,
            userDefaults: mockUserDefaults
        )
    }

    override func tearDown() {
        sut = nil
        mockVideoService = nil
        mockCreditService = nil
        mockImageUploadService = nil
        mockUserDefaults = nil
        testTheme = nil

        super.tearDown()
    }

    // MARK: - Tests: Initial State

    func testInitialState_PropertiesAreSetCorrectly() {
        // Then: Initial state should be correct
        XCTAssertEqual(sut.theme?.id, testTheme.id)
        XCTAssertEqual(sut.prompt, "")
        XCTAssertNil(sut.selectedImage)
        XCTAssertFalse(sut.isGenerating)
        XCTAssertEqual(sut.creditsRemaining, 0)
        XCTAssertFalse(sut.showingErrorAlert)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.showingResultScreen)
    }

    func testInitialState_SettingsUseThemeDefaults() {
        // Then: Settings should match theme defaults
        XCTAssertEqual(sut.settings.resolution, testTheme.settings.defaultResolution)
        XCTAssertEqual(sut.settings.duration, testTheme.settings.defaultDuration)
    }

    // MARK: - Tests: Validation - canGenerate

    func testCanGenerate_WithValidData_ReturnsTrue() async {
        // Given: Valid generation data
        sut.prompt = "A cat playing piano"
        mockCreditService.setupSuccess(credits: 100)
        await sut.loadCredits()

        // Then: Can generate
        XCTAssertTrue(sut.canGenerate)
    }

    func testCanGenerate_WithEmptyPrompt_ReturnsFalse() async {
        // Given: Empty prompt
        sut.prompt = ""
        mockCreditService.setupSuccess(credits: 100)
        await sut.loadCredits()

        // Then: Cannot generate
        XCTAssertFalse(sut.canGenerate)
    }

    func testCanGenerate_WithWhitespacePrompt_ReturnsFalse() async {
        // Given: Whitespace-only prompt
        sut.prompt = "   \n\t  "
        mockCreditService.setupSuccess(credits: 100)
        await sut.loadCredits()

        // Then: Cannot generate
        XCTAssertFalse(sut.canGenerate)
    }

    func testCanGenerate_WithInsufficientCredits_ReturnsFalse() async {
        // Given: Valid prompt but not enough credits
        sut.prompt = "A cat playing piano"
        mockCreditService.setupSuccess(credits: 2) // Theme costs 5
        await sut.loadCredits()

        // Then: Cannot generate
        XCTAssertFalse(sut.canGenerate)
    }

    func testCanGenerate_WithExactCredits_ReturnsTrue() async {
        // Given: Exact credit amount
        sut.prompt = "A cat playing piano"
        mockCreditService.setupSuccess(credits: testTheme.costPerGeneration)
        await sut.loadCredits()

        // Then: Can generate
        XCTAssertTrue(sut.canGenerate)
    }

    func testCanGenerate_WhileGenerating_ReturnsFalse() async {
        // Given: Valid data but currently generating
        sut.prompt = "A cat playing piano"
        mockCreditService.setupSuccess(credits: 100)
        await sut.loadCredits()

        // Manually set generating state
        sut.isGenerating = true

        // Then: Cannot generate during generation
        XCTAssertFalse(sut.canGenerate)
    }

    // MARK: - Tests: Image-to-Video Validation

    func testCanGenerate_ImageToVideoMode_RequiresImage() async {
        // Given: Theme requires image
        let imageTheme = TestDataBuilder.theme(
            name: "Image-to-Video",
            description: "Requires image"
        )
        imageTheme.requiresImage = true

        sut = ModelDetailViewModel(
            theme: imageTheme,
            videoService: mockVideoService,
            creditService: mockCreditService,
            imageUploadService: mockImageUploadService,
            userDefaults: mockUserDefaults
        )

        // Given: Valid prompt but no image
        sut.prompt = "Animate this"
        mockCreditService.setupSuccess(credits: 100)
        await sut.loadCredits()

        // Then: Cannot generate without image
        XCTAssertFalse(sut.canGenerate)

        // When: Image is added
        sut.selectedImage = UIImage(systemName: "photo")

        // Then: Can generate with image
        XCTAssertTrue(sut.canGenerate)
    }

    // MARK: - Tests: Load Credits

    func testLoadCredits_Success_UpdatesCreditsRemaining() async {
        // Given: Service returns credits
        mockCreditService.setupSuccess(credits: 75)

        // When: Loading credits
        await sut.loadCredits()

        // Then: Credits should be updated
        XCTAssertEqual(sut.creditsRemaining, 75)
        XCTAssertFalse(sut.showingErrorAlert)
    }

    func testLoadCredits_Failure_ShowsError() async {
        // Given: Service will fail
        mockCreditService.setupFailure(error: AppError.networkFailure)

        // When: Loading credits
        await sut.loadCredits()

        // Then: Should show error
        XCTAssertTrue(sut.showingErrorAlert)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertEqual(sut.creditsRemaining, 0)
    }

    func testLoadCredits_UsesCorrectUserId() async {
        // Given: Specific user ID
        mockUserDefaults.currentUserId = "specific-user-789"
        mockCreditService.setupSuccess(credits: 50)

        // When: Loading credits
        await sut.loadCredits()

        // Then: Should use correct user ID
        XCTAssertEqual(
            mockCreditService.getCreditsForUserCalls.last,
            "specific-user-789"
        )
    }

    // MARK: - Tests: Generate Video - Success

    func testGenerateVideo_Success_CreatesJob() async {
        // Given: Valid generation setup
        sut.prompt = "A cat playing piano in a jazz club"
        mockCreditService.setupSuccess(credits: 100)
        await sut.loadCredits()

        mockVideoService.setupSuccess(jobId: "job-123", status: "queued")

        // When: Generating video
        await sut.generateVideo()

        // Then: Should create job successfully
        XCTAssertEqual(sut.generatedJobId, "job-123")
        XCTAssertTrue(sut.showingResultScreen)
        XCTAssertFalse(sut.showingErrorAlert)
        XCTAssertFalse(sut.isGenerating)
    }

    func testGenerateVideo_Success_CallsServiceWithCorrectData() async {
        // Given: Valid generation setup
        sut.prompt = "Test prompt"
        sut.settings.resolution = "1080p"
        sut.settings.duration = 5
        mockCreditService.setupSuccess(credits: 100)
        await sut.loadCredits()
        mockVideoService.setupSuccess()

        // When: Generating video
        await sut.generateVideo()

        // Then: Should call service with correct data
        XCTAssertEqual(mockVideoService.generateVideoCallCount, 1)

        let request = mockVideoService.lastRequest
        XCTAssertNotNil(request)
        XCTAssertEqual(request?.userId, "test-user-123")
        XCTAssertEqual(request?.themeId, testTheme.id)
        XCTAssertEqual(request?.prompt, "Test prompt")
        XCTAssertEqual(request?.settings.resolution, "1080p")
        XCTAssertEqual(request?.settings.duration, 5)
    }

    func testGenerateVideo_Success_UpdatesLoadingState() async {
        // Given: Valid generation setup with delay
        sut.prompt = "Test prompt"
        mockCreditService.setupSuccess(credits: 100)
        await sut.loadCredits()

        mockVideoService.setupSuccess()
        mockVideoService.simulatedDelay = 0.5

        // When: Start generating
        let task = Task {
            await sut.generateVideo()
        }

        // Then: Should be generating
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        XCTAssertTrue(sut.isGenerating)

        // Wait for completion
        await task.value

        // Then: Should not be generating
        XCTAssertFalse(sut.isGenerating)
    }

    func testGenerateVideo_WithImage_UploadsImageFirst() async {
        // Given: Valid generation with image
        sut.prompt = "Animate this image"
        sut.selectedImage = UIImage(systemName: "photo")
        mockCreditService.setupSuccess(credits: 100)
        await sut.loadCredits()

        mockImageUploadService.setupSuccess(url: "https://example.com/uploaded.jpg")
        mockVideoService.setupSuccess()

        // When: Generating video
        await sut.generateVideo()

        // Then: Should upload image first
        XCTAssertEqual(mockImageUploadService.uploadCallCount, 1)

        // And: Should use uploaded URL in request
        let request = mockVideoService.lastRequest
        XCTAssertEqual(request?.imageURL, "https://example.com/uploaded.jpg")
    }

    // MARK: - Tests: Generate Video - Validation Failures

    func testGenerateVideo_InvalidPrompt_DoesNotGenerate() async {
        // Given: Invalid prompt
        sut.prompt = ""
        mockCreditService.setupSuccess(credits: 100)
        await sut.loadCredits()

        // When: Attempting to generate
        await sut.generateVideo()

        // Then: Should not call service
        XCTAssertEqual(mockVideoService.generateVideoCallCount, 0)
        XCTAssertFalse(sut.showingResultScreen)
    }

    func testGenerateVideo_InsufficientCredits_ShowsError() async {
        // Given: Not enough credits
        sut.prompt = "Valid prompt"
        mockCreditService.setupSuccess(credits: 2) // Need 5
        await sut.loadCredits()

        // When: Attempting to generate
        await sut.generateVideo()

        // Then: Should show insufficient credits error
        XCTAssertTrue(sut.showingErrorAlert)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertEqual(mockVideoService.generateVideoCallCount, 0)
    }

    // MARK: - Tests: Generate Video - Service Failures

    func testGenerateVideo_ServiceFailure_ShowsError() async {
        // Given: Valid setup but service will fail
        sut.prompt = "Valid prompt"
        mockCreditService.setupSuccess(credits: 100)
        await sut.loadCredits()

        mockVideoService.setupFailure(error: AppError.networkFailure)

        // When: Generating video
        await sut.generateVideo()

        // Then: Should show error
        XCTAssertTrue(sut.showingErrorAlert)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertFalse(sut.showingResultScreen)
        XCTAssertFalse(sut.isGenerating)
    }

    func testGenerateVideo_ImageUploadFailure_ShowsError() async {
        // Given: Valid setup but image upload will fail
        sut.prompt = "Animate this"
        sut.selectedImage = UIImage(systemName: "photo")
        mockCreditService.setupSuccess(credits: 100)
        await sut.loadCredits()

        mockImageUploadService.setupFailure(error: AppError.networkFailure)

        // When: Generating video
        await sut.generateVideo()

        // Then: Should show error
        XCTAssertTrue(sut.showingErrorAlert)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertFalse(sut.showingResultScreen)

        // And: Should not call video service
        XCTAssertEqual(mockVideoService.generateVideoCallCount, 0)
    }

    // MARK: - Tests: Settings Management

    func testUpdateResolution_UpdatesSettings() {
        // When: Updating resolution
        sut.settings.resolution = "720p"

        // Then: Settings should be updated
        XCTAssertEqual(sut.settings.resolution, "720p")
    }

    func testUpdateDuration_UpdatesSettings() {
        // When: Updating duration
        sut.settings.duration = 10

        // Then: Settings should be updated
        XCTAssertEqual(sut.settings.duration, 10)
    }

    func testUpdateAspectRatio_UpdatesSettings() {
        // When: Updating aspect ratio
        sut.settings.aspectRatio = "9:16"

        // Then: Settings should be updated
        XCTAssertEqual(sut.settings.aspectRatio, "9:16")
    }

    // MARK: - Tests: Cost Calculation

    func testGenerationCost_MatchesThemeCost() {
        // Then: Cost should match theme
        XCTAssertEqual(sut.generationCost, testTheme.costPerGeneration)
    }

    func testCanAffordGeneration_WithSufficientCredits_ReturnsTrue() async {
        // Given: Enough credits
        mockCreditService.setupSuccess(credits: 100)
        await sut.loadCredits()

        // Then: Can afford
        XCTAssertTrue(sut.canAffordGeneration)
    }

    func testCanAffordGeneration_WithInsufficientCredits_ReturnsFalse() async {
        // Given: Not enough credits
        mockCreditService.setupSuccess(credits: 2)
        await sut.loadCredits()

        // Then: Cannot afford
        XCTAssertFalse(sut.canAffordGeneration)
    }

    // MARK: - Tests: Image Selection

    func testSelectImage_UpdatesSelectedImage() {
        // Given: An image
        let testImage = UIImage(systemName: "photo")

        // When: Selecting image
        sut.selectedImage = testImage

        // Then: Should be set
        XCTAssertNotNil(sut.selectedImage)
        XCTAssertEqual(sut.selectedImage, testImage)
    }

    func testClearImage_RemovesSelectedImage() {
        // Given: Image selected
        sut.selectedImage = UIImage(systemName: "photo")

        // When: Clearing image
        sut.selectedImage = nil

        // Then: Should be nil
        XCTAssertNil(sut.selectedImage)
    }

    // MARK: - Tests: Concurrent Operations

    func testConcurrentGenerations_OnlyOneSucceeds() async {
        // Given: Valid generation setup
        sut.prompt = "Test prompt"
        mockCreditService.setupSuccess(credits: 100)
        await sut.loadCredits()

        mockVideoService.setupSuccess()
        mockVideoService.simulatedDelay = 0.3

        // When: Multiple concurrent generation attempts
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<3 {
                group.addTask {
                    await self.sut.generateVideo()
                }
            }
        }

        // Then: Should only call service once (prevented by isGenerating flag)
        // Adjust this based on your actual concurrency protection
        XCTAssertLessThanOrEqual(mockVideoService.generateVideoCallCount, 1)
    }

    // MARK: - Tests: Error Message Localization

    func testErrorMessage_IsLocalized() async {
        // Given: Service will fail
        mockCreditService.setupFailure(error: AppError.networkFailure)

        // When: Loading credits
        await sut.loadCredits()

        // Then: Error message should be present and localized
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertFalse(sut.errorMessage!.isEmpty)
    }

    // MARK: - Tests: Reset State

    func testReset_ClearsAllData() {
        // Given: ViewModel with data
        sut.prompt = "Test prompt"
        sut.selectedImage = UIImage(systemName: "photo")
        sut.generatedJobId = "job-123"
        sut.showingResultScreen = true

        // When: Resetting
        sut.reset()

        // Then: Should clear all data
        XCTAssertEqual(sut.prompt, "")
        XCTAssertNil(sut.selectedImage)
        XCTAssertNil(sut.generatedJobId)
        XCTAssertFalse(sut.showingResultScreen)
    }

    // MARK: - Tests: Performance

    func testGenerateVideo_Performance() {
        // Given: Valid setup
        sut.prompt = "Performance test prompt"
        mockCreditService.setupSuccess(credits: 100)
        mockVideoService.setupSuccess()

        // Measure performance
        measure {
            let expectation = expectation(description: "Generate video")

            Task {
                await sut.loadCredits()
                await sut.generateVideo()
                expectation.fulfill()
            }

            waitForExpectations(timeout: 5.0)
        }
    }
}

// MARK: - Test Extensions

extension ModelDetailViewModel {
    /// Computed property for generation cost
    var generationCost: Int {
        theme?.costPerGeneration ?? 0
    }

    /// Computed property to check if user can afford generation
    var canAffordGeneration: Bool {
        creditsRemaining >= generationCost
    }

    /// Reset all state (if not in your implementation)
    func reset() {
        prompt = ""
        selectedImage = nil
        generatedJobId = nil
        showingResultScreen = false
        errorMessage = nil
        showingErrorAlert = false
    }
}

// MARK: - Mock Image Upload Service

class MockImageUploadService: ImageUploadServiceProtocol {
    var urlToReturn: String?
    var errorToThrow: Error?
    var simulatedDelay: TimeInterval = 0
    var uploadCallCount = 0
    var uploadedImages: [UIImage] = []

    func uploadImage(_ image: UIImage) async throws -> String {
        uploadCallCount += 1
        uploadedImages.append(image)

        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }

        if let error = errorToThrow {
            throw error
        }

        return urlToReturn ?? "https://example.com/default-upload.jpg"
    }

    func setupSuccess(url: String) {
        self.urlToReturn = url
        self.errorToThrow = nil
    }

    func setupFailure(error: Error) {
        self.errorToThrow = error
        self.urlToReturn = nil
    }

    func reset() {
        urlToReturn = nil
        errorToThrow = nil
        simulatedDelay = 0
        uploadCallCount = 0
        uploadedImages = []
    }
}
