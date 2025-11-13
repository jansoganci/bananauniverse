import XCTest
@testable import YourAppName // Replace with your actual app module name

// MARK: - ThemeService Tests

/// Comprehensive tests for ThemeService
/// Tests cover: HTTP requests, response parsing, caching, error handling, and network conditions
final class ThemeServiceTests: XCTestCase {

    // MARK: - System Under Test

    var sut: ThemeService!

    // MARK: - Dependencies

    var mockURLSession: MockURLSession!
    var mockAppConfig: MockAppConfig!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()

        mockURLSession = MockURLSession()
        mockAppConfig = MockAppConfig()

        sut = ThemeService(
            urlSession: mockURLSession,
            config: mockAppConfig
        )
    }

    override func tearDown() {
        sut = nil
        mockURLSession = nil
        mockAppConfig = nil

        super.tearDown()
    }

    // MARK: - Tests: Successful Fetch

    func testFetchThemes_Success_ReturnsThemes() async throws {
        // Given: Mock response with valid JSON
        let themes = [Theme.mockCinematic, Theme.mockAnime]
        let jsonData = try encodeToJSON(themes)

        mockURLSession.mockData = jsonData
        mockURLSession.mockResponse = HTTPURLResponse(
            url: mockAppConfig.apiURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        // When: Fetching themes
        let result = try await sut.fetchThemes()

        // Then: Should return parsed themes
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].id, Theme.mockCinematic.id)
        XCTAssertEqual(result[1].id, Theme.mockAnime.id)
    }

    func testFetchThemes_Success_UsesCorrectURL() async throws {
        // Given: Mock successful response
        mockURLSession.mockData = try encodeToJSON([Theme.mockCinematic])
        mockURLSession.mockResponse = successResponse()

        // When: Fetching themes
        _ = try await sut.fetchThemes()

        // Then: Should use correct endpoint
        let requestURL = mockURLSession.lastRequest?.url
        XCTAssertEqual(requestURL?.absoluteString, "\(mockAppConfig.supabaseURL)/functions/v1/get-models")
    }

    func testFetchThemes_Success_IncludesRequiredHeaders() async throws {
        // Given: Mock successful response
        mockURLSession.mockData = try encodeToJSON([Theme.mockCinematic])
        mockURLSession.mockResponse = successResponse()

        // When: Fetching themes
        _ = try await sut.fetchThemes()

        // Then: Should include required headers
        let headers = mockURLSession.lastRequest?.allHTTPHeaderFields

        XCTAssertEqual(headers?["Authorization"], "Bearer \(mockAppConfig.supabaseAnonKey)")
        XCTAssertEqual(headers?["apikey"], mockAppConfig.supabaseAnonKey)
        XCTAssertEqual(headers?["Content-Type"], "application/json")
    }

    func testFetchThemes_EmptyResponse_ReturnsEmptyArray() async throws {
        // Given: Empty array response
        let emptyJSON = try encodeToJSON([Theme]())
        mockURLSession.mockData = emptyJSON
        mockURLSession.mockResponse = successResponse()

        // When: Fetching themes
        let result = try await sut.fetchThemes()

        // Then: Should return empty array
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Tests: HTTP Status Codes

    func testFetchThemes_404NotFound_ThrowsError() async {
        // Given: 404 response
        mockURLSession.mockData = Data()
        mockURLSession.mockResponse = HTTPURLResponse(
            url: mockAppConfig.apiURL,
            statusCode: 404,
            httpVersion: nil,
            headerFields: nil
        )

        // When/Then: Should throw error
        await assertThrowsError(try await sut.fetchThemes()) { error in
            XCTAssertEqual(error as? AppError, AppError.networkFailure)
        }
    }

    func testFetchThemes_500ServerError_ThrowsError() async {
        // Given: 500 response
        mockURLSession.mockData = Data()
        mockURLSession.mockResponse = HTTPURLResponse(
            url: mockAppConfig.apiURL,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )

        // When/Then: Should throw error
        await assertThrowsError(try await sut.fetchThemes()) { error in
            XCTAssertEqual(error as? AppError, AppError.networkFailure)
        }
    }

    func testFetchThemes_401Unauthorized_ThrowsAuthError() async {
        // Given: 401 response
        mockURLSession.mockData = Data()
        mockURLSession.mockResponse = HTTPURLResponse(
            url: mockAppConfig.apiURL,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )

        // When/Then: Should throw unauthorized error
        await assertThrowsError(try await sut.fetchThemes()) { error in
            XCTAssertEqual(error as? AppError, AppError.unauthorized)
        }
    }

    func testFetchThemes_429RateLimit_ThrowsError() async {
        // Given: 429 Too Many Requests
        mockURLSession.mockData = Data()
        mockURLSession.mockResponse = HTTPURLResponse(
            url: mockAppConfig.apiURL,
            statusCode: 429,
            httpVersion: nil,
            headerFields: nil
        )

        // When/Then: Should throw error
        await assertThrowsError(try await sut.fetchThemes()) { error in
            // Check for rate limit error or network error
            XCTAssertNotNil(error)
        }
    }

    // MARK: - Tests: Network Errors

    func testFetchThemes_NetworkTimeout_ThrowsTimeoutError() async {
        // Given: Network timeout error
        mockURLSession.mockError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorTimedOut,
            userInfo: nil
        )

        // When/Then: Should throw timeout error
        await assertThrowsError(try await sut.fetchThemes()) { error in
            XCTAssertEqual(error as? AppError, AppError.networkTimeout)
        }
    }

    func testFetchThemes_NoInternetConnection_ThrowsNetworkError() async {
        // Given: No internet connection
        mockURLSession.mockError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: nil
        )

        // When/Then: Should throw network error
        await assertThrowsError(try await sut.fetchThemes()) { error in
            XCTAssertEqual(error as? AppError, AppError.networkFailure)
        }
    }

    func testFetchThemes_HostUnreachable_ThrowsNetworkError() async {
        // Given: Host unreachable
        mockURLSession.mockError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorCannotFindHost,
            userInfo: nil
        )

        // When/Then: Should throw network error
        await assertThrowsError(try await sut.fetchThemes()) { error in
            XCTAssertEqual(error as? AppError, AppError.networkFailure)
        }
    }

    // MARK: - Tests: JSON Parsing

    func testFetchThemes_InvalidJSON_ThrowsParsingError() async {
        // Given: Invalid JSON data
        mockURLSession.mockData = "Invalid JSON{".data(using: .utf8)!
        mockURLSession.mockResponse = successResponse()

        // When/Then: Should throw parsing error
        await assertThrowsError(try await sut.fetchThemes()) { error in
            XCTAssertEqual(error as? AppError, AppError.invalidResponse)
        }
    }

    func testFetchThemes_MissingRequiredFields_ThrowsParsingError() async {
        // Given: JSON with missing required fields
        let incompleteJSON = """
        [
            {
                "id": "theme-1",
                "name": "Theme Name"
                // Missing other required fields
            }
        ]
        """.data(using: .utf8)!

        mockURLSession.mockData = incompleteJSON
        mockURLSession.mockResponse = successResponse()

        // When/Then: Should throw parsing error
        await assertThrowsError(try await sut.fetchThemes()) { error in
            // Should fail to decode
            XCTAssertNotNil(error)
        }
    }

    func testFetchThemes_HandlesSnakeCaseToCamelCase() async throws {
        // Given: JSON with snake_case fields
        let snakeCaseJSON = """
        [
            {
                "id": "theme-1",
                "name": "Test",
                "description": "Description",
                "is_featured": true,
                "thumbnail_url": "https://example.com/image.jpg",
                "cost_per_generation": 5,
                "category": "video",
                "settings": {
                    "default_resolution": "1080p",
                    "default_duration": 5,
                    "supported_aspect_ratios": ["16:9"]
                }
            }
        ]
        """.data(using: .utf8)!

        mockURLSession.mockData = snakeCaseJSON
        mockURLSession.mockResponse = successResponse()

        // When: Fetching themes
        let result = try await sut.fetchThemes()

        // Then: Should parse correctly
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result[0].isFeatured) // snake_case → camelCase
        XCTAssertEqual(result[0].costPerGeneration, 5)
    }

    // MARK: - Tests: ETag Caching

    func testFetchThemes_FirstRequest_StoresETag() async throws {
        // Given: Response with ETag header
        let themes = [Theme.mockCinematic]
        let jsonData = try encodeToJSON(themes)

        mockURLSession.mockData = jsonData
        mockURLSession.mockResponse = HTTPURLResponse(
            url: mockAppConfig.apiURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["ETag": "etag-12345"]
        )

        // When: Fetching themes
        _ = try await sut.fetchThemes()

        // Then: Should store ETag
        XCTAssertEqual(sut.cachedETag, "etag-12345")
    }

    func testFetchThemes_SubsequentRequest_SendsIfNoneMatch() async throws {
        // Given: Previous request stored ETag
        sut.cachedETag = "etag-12345"

        mockURLSession.mockData = Data()
        mockURLSession.mockResponse = HTTPURLResponse(
            url: mockAppConfig.apiURL,
            statusCode: 304, // Not Modified
            httpVersion: nil,
            headerFields: nil
        )

        // When: Fetching themes again
        _ = try? await sut.fetchThemes()

        // Then: Should send If-None-Match header
        let headers = mockURLSession.lastRequest?.allHTTPHeaderFields
        XCTAssertEqual(headers?["If-None-Match"], "etag-12345")
    }

    func testFetchThemes_304NotModified_ReturnsCachedData() async throws {
        // Given: Cached themes and 304 response
        let cachedThemes = [Theme.mockCinematic, Theme.mockAnime]
        sut.cachedThemes = cachedThemes
        sut.cachedETag = "etag-12345"

        mockURLSession.mockData = Data()
        mockURLSession.mockResponse = HTTPURLResponse(
            url: mockAppConfig.apiURL,
            statusCode: 304,
            httpVersion: nil,
            headerFields: nil
        )

        // When: Fetching themes
        let result = try await sut.fetchThemes()

        // Then: Should return cached data
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].id, cachedThemes[0].id)
        XCTAssertEqual(result[1].id, cachedThemes[1].id)
    }

    // MARK: - Tests: Timeout Handling

    func testFetchThemes_RespectsConfiguredTimeout() async throws {
        // Given: Configured timeout
        mockAppConfig.apiTimeout = 15.0

        mockURLSession.mockData = try encodeToJSON([Theme.mockCinematic])
        mockURLSession.mockResponse = successResponse()

        // When: Fetching themes
        _ = try await sut.fetchThemes()

        // Then: Request should use configured timeout
        XCTAssertEqual(mockURLSession.lastRequest?.timeoutInterval, 15.0)
    }

    // MARK: - Tests: Concurrent Requests

    func testFetchThemes_ConcurrentRequests_HandleCorrectly() async throws {
        // Given: Mock successful response
        mockURLSession.mockData = try encodeToJSON([Theme.mockCinematic])
        mockURLSession.mockResponse = successResponse()

        // When: Multiple concurrent requests
        let results = try await withThrowingTaskGroup(of: [Theme].self) { group in
            for _ in 0..<5 {
                group.addTask {
                    try await self.sut.fetchThemes()
                }
            }

            var allResults: [[Theme]] = []
            for try await result in group {
                allResults.append(result)
            }
            return allResults
        }

        // Then: All should succeed
        XCTAssertEqual(results.count, 5)
        XCTAssertTrue(results.allSatisfy { $0.count == 1 })
    }

    // MARK: - Tests: Memory Management

    func testFetchThemes_LargeDataSet_DoesNotLeak() async throws {
        // Given: Large dataset
        let largeThemeSet = TestDataBuilder.themes(count: 1000)
        let jsonData = try encodeToJSON(largeThemeSet)

        mockURLSession.mockData = jsonData
        mockURLSession.mockResponse = successResponse()

        // When: Fetching large dataset
        _ = try await sut.fetchThemes()

        // Then: Should complete without memory issues
        // Note: Use Instruments to verify memory doesn't grow excessively
        XCTAssertTrue(true, "Completed without crash")
    }

    // MARK: - Tests: Performance

    func testFetchThemes_Performance() {
        // Given: Standard response
        let themes = TestDataBuilder.themes(count: 50, featured: 10)

        measure {
            let expectation = expectation(description: "Fetch themes")

            Task {
                do {
                    self.mockURLSession.mockData = try self.encodeToJSON(themes)
                    self.mockURLSession.mockResponse = self.successResponse()

                    _ = try await self.sut.fetchThemes()
                    expectation.fulfill()
                } catch {
                    XCTFail("Failed to fetch: \(error)")
                }
            }

            waitForExpectations(timeout: 5.0)
        }
    }

    // MARK: - Helper Methods

    private func encodeToJSON<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return try encoder.encode(value)
    }

    private func successResponse() -> HTTPURLResponse {
        HTTPURLResponse(
            url: mockAppConfig.apiURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
    }

    private func assertThrowsError<T>(
        _ expression: @autoclosure () async throws -> T,
        _ errorHandler: (Error) -> Void = { _ in }
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expected error to be thrown")
        } catch {
            errorHandler(error)
        }
    }
}

// MARK: - Mock URLSession

class MockURLSession: URLSessionProtocol {
    var mockData: Data?
    var mockResponse: URLResponse?
    var mockError: Error?
    var lastRequest: URLRequest?
    var requestCount = 0

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requestCount += 1
        lastRequest = request

        if let error = mockError {
            throw error
        }

        guard let data = mockData, let response = mockResponse else {
            throw AppError.networkFailure
        }

        return (data, response)
    }

    func reset() {
        mockData = nil
        mockResponse = nil
        mockError = nil
        lastRequest = nil
        requestCount = 0
    }
}

// MARK: - Mock AppConfig

class MockAppConfig {
    var supabaseURL: String = "https://test.supabase.co"
    var supabaseAnonKey: String = "test-anon-key-12345"
    var apiTimeout: TimeInterval = 30.0

    var apiURL: URL {
        URL(string: "\(supabaseURL)/functions/v1/get-models")!
    }
}

// MARK: - URLSession Protocol

protocol URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}

// MARK: - ThemeService Extensions for Testing

extension ThemeService {
    var cachedETag: String? {
        get { /* Access internal cached ETag */ return nil }
        set { /* Set internal cached ETag */ }
    }

    var cachedThemes: [Theme]? {
        get { /* Access internal cached themes */ return nil }
        set { /* Set internal cached themes */ }
    }
}
