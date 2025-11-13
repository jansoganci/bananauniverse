import XCTest
@testable import YourAppName // Replace with your actual app module name

// MARK: - HomeViewModel Tests

/// Comprehensive tests for HomeViewModel
/// Tests cover: data loading, search, filtering, error handling, and state management
final class HomeViewModelTests: XCTestCase {

    // MARK: - System Under Test

    var sut: HomeViewModel!

    // MARK: - Dependencies (Mocks)

    var mockThemeService: MockThemeService!
    var mockCreditService: MockCreditService!
    var mockUserDefaults: MockUserDefaultsManager!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()

        // Create fresh mocks for each test
        mockThemeService = MockThemeService()
        mockCreditService = MockCreditService()
        mockUserDefaults = MockUserDefaultsManager()

        // Setup default test state
        mockUserDefaults.setupTestState(userId: "test-user-123")

        // Create system under test with mocked dependencies
        sut = HomeViewModel(
            themeService: mockThemeService,
            creditService: mockCreditService,
            userDefaults: mockUserDefaults
        )
    }

    override func tearDown() {
        sut = nil
        mockThemeService = nil
        mockCreditService = nil
        mockUserDefaults = nil

        super.tearDown()
    }

    // MARK: - Tests: Initial State

    func testInitialState_PropertiesAreSetCorrectly() {
        // Given: A newly initialized HomeViewModel

        // Then: Initial state should be correct
        XCTAssertEqual(sut.creditsRemaining, 0, "Credits should start at 0")
        XCTAssertEqual(sut.searchQuery, "", "Search query should be empty")
        XCTAssertTrue(sut.featuredThemes.isEmpty, "Featured themes should be empty")
        XCTAssertTrue(sut.allThemes.isEmpty, "All themes should be empty")
        XCTAssertFalse(sut.isLoading, "Should not be loading initially")
        XCTAssertFalse(sut.showingErrorAlert, "Should not show error initially")
        XCTAssertNil(sut.errorMessage, "Error message should be nil")
    }

    // MARK: - Tests: Load Data - Success

    func testLoadData_Success_PopulatesThemes() async {
        // Given: Mock service will return themes
        let mockThemes = Theme.mockThemes
        mockThemeService.setupSuccess(themes: mockThemes)
        mockCreditService.setupSuccess(credits: 50)

        // When: Loading data
        await sut.loadData()

        // Then: Themes should be populated
        XCTAssertEqual(sut.allThemes.count, 3, "Should have 3 themes")
        XCTAssertEqual(sut.featuredThemes.count, 2, "Should have 2 featured themes")
        XCTAssertEqual(sut.creditsRemaining, 50, "Should have 50 credits")
        XCTAssertFalse(sut.isLoading, "Should not be loading after completion")
    }

    func testLoadData_Success_SeparatesFeaturedThemes() async {
        // Given: Mix of featured and non-featured themes
        let themes = [
            Theme.mockCinematic,  // featured
            Theme.mockAnime,      // not featured
            Theme.mockRealistic   // featured
        ]
        mockThemeService.setupSuccess(themes: themes)
        mockCreditService.setupSuccess(credits: 100)

        // When: Loading data
        await sut.loadData()

        // Then: Featured themes should be filtered correctly
        XCTAssertEqual(sut.featuredThemes.count, 2)
        XCTAssertTrue(sut.featuredThemes.allSatisfy { $0.isFeatured })

        let featuredIds = sut.featuredThemes.map { $0.id }
        XCTAssertTrue(featuredIds.contains("theme-cinematic-1"))
        XCTAssertTrue(featuredIds.contains("theme-realistic-1"))
        XCTAssertFalse(featuredIds.contains("theme-anime-1"))
    }

    func testLoadData_Success_CallsServicesOnce() async {
        // Given: Mock services configured
        mockThemeService.setupSuccess(themes: Theme.mockThemes)
        mockCreditService.setupSuccess(credits: 100)

        // When: Loading data
        await sut.loadData()

        // Then: Services should be called exactly once
        XCTAssertEqual(mockThemeService.fetchThemesCallCount, 1)
        XCTAssertEqual(mockCreditService.getCreditsCallCount, 1)
    }

    func testLoadData_Success_UpdatesLoadingState() async {
        // Given: Mock service with delay
        mockThemeService.setupSuccess(themes: Theme.mockThemes)
        mockThemeService.simulatedDelay = 0.5
        mockCreditService.setupSuccess(credits: 100)

        // When: Start loading
        let loadingTask = Task {
            await sut.loadData()
        }

        // Then: Should be loading during operation
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        XCTAssertTrue(sut.isLoading, "Should be loading during async operation")

        // Wait for completion
        await loadingTask.value

        // Then: Should not be loading after completion
        XCTAssertFalse(sut.isLoading, "Should not be loading after completion")
    }

    // MARK: - Tests: Load Data - Failure

    func testLoadData_ThemeServiceFailure_ShowsError() async {
        // Given: Theme service will fail
        mockThemeService.setupFailure(error: AppError.networkFailure)
        mockCreditService.setupSuccess(credits: 100)

        // When: Loading data
        await sut.loadData()

        // Then: Should show error state
        XCTAssertTrue(sut.showingErrorAlert, "Should show error alert")
        XCTAssertNotNil(sut.errorMessage, "Should have error message")
        XCTAssertTrue(sut.allThemes.isEmpty, "Themes should be empty on error")
        XCTAssertFalse(sut.isLoading, "Should not be loading after error")
    }

    func testLoadData_CreditServiceFailure_ShowsError() async {
        // Given: Credit service will fail
        mockThemeService.setupSuccess(themes: Theme.mockThemes)
        mockCreditService.setupFailure(error: AppError.networkFailure)

        // When: Loading data
        await sut.loadData()

        // Then: Should show error state
        XCTAssertTrue(sut.showingErrorAlert, "Should show error alert")
        XCTAssertNotNil(sut.errorMessage, "Should have error message")

        // Note: Themes might still load if implementation continues on credit error
        // Adjust based on your actual error handling strategy
    }

    func testLoadData_NetworkTimeout_ShowsTimeoutError() async {
        // Given: Network timeout error
        mockThemeService.setupFailure(error: AppError.networkTimeout)
        mockCreditService.setupSuccess(credits: 100)

        // When: Loading data
        await sut.loadData()

        // Then: Should show timeout error
        XCTAssertTrue(sut.showingErrorAlert)
        XCTAssertNotNil(sut.errorMessage)
        // You could check for specific error message if needed
        // XCTAssertEqual(sut.errorMessage, "Network timeout. Please try again.")
    }

    // MARK: - Tests: Search Functionality

    func testSearchQuery_WhenEmpty_ShowsAllThemes() async {
        // Given: Themes loaded
        let themes = TestDataBuilder.themes(count: 5, featured: 2)
        mockThemeService.setupSuccess(themes: themes)
        mockCreditService.setupSuccess(credits: 100)
        await sut.loadData()

        // When: Search query is empty
        sut.searchQuery = ""

        // Then: Should show all themes
        XCTAssertEqual(sut.filteredThemes.count, 5)
    }

    func testSearchQuery_WithMatchingName_FiltersThemes() async {
        // Given: Themes loaded
        let themes = [
            TestDataBuilder.theme(name: "Cinematic"),
            TestDataBuilder.theme(name: "Anime"),
            TestDataBuilder.theme(name: "Realistic")
        ]
        mockThemeService.setupSuccess(themes: themes)
        mockCreditService.setupSuccess(credits: 100)
        await sut.loadData()

        // When: Searching for "Anime"
        sut.searchQuery = "Anime"

        // Then: Should return only matching theme
        XCTAssertEqual(sut.filteredThemes.count, 1)
        XCTAssertEqual(sut.filteredThemes.first?.name, "Anime")
    }

    func testSearchQuery_CaseInsensitive_FiltersCorrectly() async {
        // Given: Themes loaded
        let themes = [TestDataBuilder.theme(name: "Cinematic")]
        mockThemeService.setupSuccess(themes: themes)
        mockCreditService.setupSuccess(credits: 100)
        await sut.loadData()

        // When: Searching with different case
        sut.searchQuery = "cInEmAtIc"

        // Then: Should still match
        XCTAssertEqual(sut.filteredThemes.count, 1)
        XCTAssertEqual(sut.filteredThemes.first?.name, "Cinematic")
    }

    func testSearchQuery_PartialMatch_FiltersCorrectly() async {
        // Given: Themes loaded
        let themes = [
            TestDataBuilder.theme(name: "Hollywood Cinematic"),
            TestDataBuilder.theme(name: "Anime Style"),
            TestDataBuilder.theme(name: "Cinematic Realistic")
        ]
        mockThemeService.setupSuccess(themes: themes)
        mockCreditService.setupSuccess(credits: 100)
        await sut.loadData()

        // When: Searching for partial word
        sut.searchQuery = "Cine"

        // Then: Should match both themes containing "Cine"
        XCTAssertEqual(sut.filteredThemes.count, 2)
        XCTAssertTrue(sut.filteredThemes.allSatisfy { $0.name.contains("Cinematic") })
    }

    func testSearchQuery_NoMatches_ReturnsEmptyArray() async {
        // Given: Themes loaded
        let themes = [TestDataBuilder.theme(name: "Cinematic")]
        mockThemeService.setupSuccess(themes: themes)
        mockCreditService.setupSuccess(credits: 100)
        await sut.loadData()

        // When: Searching for non-existent theme
        sut.searchQuery = "NonExistent"

        // Then: Should return empty array
        XCTAssertTrue(sut.filteredThemes.isEmpty)
    }

    // MARK: - Tests: Credits

    func testCreditsRemaining_UpdatesFromService() async {
        // Given: Different credit amounts
        let testCases = [0, 5, 50, 100, 500]

        for credits in testCases {
            // Given: Service returns specific credit amount
            mockThemeService.setupSuccess(themes: [])
            mockCreditService.setupSuccess(credits: credits)

            // When: Loading data
            await sut.loadData()

            // Then: Credits should match
            XCTAssertEqual(
                sut.creditsRemaining,
                credits,
                "Credits should be \(credits)"
            )
        }
    }

    func testLowCredits_FlagIsCorrect() async {
        // Given: Service returns low credits
        mockThemeService.setupSuccess(themes: Theme.mockThemes)
        mockCreditService.setupSuccess(credits: 3)
        await sut.loadData()

        // Then: Low credits flag should be true
        XCTAssertTrue(sut.hasLowCredits, "Should flag low credits")

        // When: Credits increase
        mockCreditService.setupSuccess(credits: 20)
        await sut.loadData()

        // Then: Low credits flag should be false
        XCTAssertFalse(sut.hasLowCredits, "Should not flag sufficient credits")
    }

    // MARK: - Tests: Refresh

    func testRefresh_ReloadsData() async {
        // Given: Initial data loaded
        mockThemeService.setupSuccess(themes: [Theme.mockCinematic])
        mockCreditService.setupSuccess(credits: 50)
        await sut.loadData()

        XCTAssertEqual(sut.allThemes.count, 1)

        // When: Data changes and we refresh
        mockThemeService.setupSuccess(themes: Theme.mockThemes)
        mockCreditService.setupSuccess(credits: 100)
        await sut.refresh()

        // Then: Should have new data
        XCTAssertEqual(sut.allThemes.count, 3)
        XCTAssertEqual(sut.creditsRemaining, 100)
    }

    // MARK: - Tests: Empty States

    func testEmptyState_NoThemesAvailable_IsCorrect() async {
        // Given: Service returns no themes
        mockThemeService.setupSuccess(themes: [])
        mockCreditService.setupSuccess(credits: 100)

        // When: Loading data
        await sut.loadData()

        // Then: Should show empty state
        XCTAssertTrue(sut.allThemes.isEmpty)
        XCTAssertTrue(sut.filteredThemes.isEmpty)
        XCTAssertTrue(sut.shouldShowEmptyState)
    }

    // MARK: - Tests: User ID

    func testLoadData_UsesCorrectUserId() async {
        // Given: User ID in defaults
        mockUserDefaults.currentUserId = "specific-user-456"
        mockThemeService.setupSuccess(themes: [])
        mockCreditService.setupSuccess(credits: 100)

        // When: Loading data
        await sut.loadData()

        // Then: Should use correct user ID
        XCTAssertEqual(
            mockCreditService.getCreditsForUserCalls.last,
            "specific-user-456"
        )
    }

    // MARK: - Tests: Concurrent Loads

    func testConcurrentLoads_DoNotCauseCrash() async {
        // Given: Mock services
        mockThemeService.setupSuccess(themes: Theme.mockThemes)
        mockThemeService.simulatedDelay = 0.2
        mockCreditService.setupSuccess(credits: 100)

        // When: Multiple concurrent loads
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    await self.sut.loadData()
                }
            }
        }

        // Then: Should complete without crash
        XCTAssertFalse(sut.allThemes.isEmpty)
        XCTAssertFalse(sut.isLoading)
    }

    // MARK: - Tests: Memory & Performance

    func testLoadData_Performance() {
        // Given: Large dataset
        let largeThemeSet = TestDataBuilder.themes(count: 100, featured: 20)
        mockThemeService.setupSuccess(themes: largeThemeSet)
        mockCreditService.setupSuccess(credits: 1000)

        // Measure performance
        measure {
            let expectation = expectation(description: "Load data")

            Task {
                await sut.loadData()
                expectation.fulfill()
            }

            waitForExpectations(timeout: 5.0)
        }
    }
}

// MARK: - Test Extensions

extension HomeViewModel {
    /// Computed property for filtered themes (if not in your implementation, add this)
    var filteredThemes: [Theme] {
        guard !searchQuery.isEmpty else { return allThemes }
        return allThemes.filter { theme in
            theme.name.localizedCaseInsensitiveContains(searchQuery) ||
            theme.description.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    /// Computed property for empty state
    var shouldShowEmptyState: Bool {
        !isLoading && allThemes.isEmpty
    }

    /// Computed property for low credits warning
    var hasLowCredits: Bool {
        creditsRemaining < 10
    }
}
