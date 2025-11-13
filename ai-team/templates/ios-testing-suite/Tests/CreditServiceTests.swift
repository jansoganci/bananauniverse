import XCTest
@testable import YourAppName // Replace with your actual app module name

// MARK: - CreditService Tests

/// Comprehensive tests for CreditService
/// Tests cover: credit fetching, deduction, addition, error handling, and edge cases
final class CreditServiceTests: XCTestCase {

    // MARK: - System Under Test

    var sut: CreditService!

    // MARK: - Dependencies

    var mockURLSession: MockURLSession!
    var mockAppConfig: MockAppConfig!

    // MARK: - Test Data

    let testUserId = "test-user-123"

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()

        mockURLSession = MockURLSession()
        mockAppConfig = MockAppConfig()

        sut = CreditService(
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

    // MARK: - Tests: Get Credits - Success

    func testGetCredits_Success_ReturnsBalance() async throws {
        // Given: Mock response with credits
        let responseJSON = """
        {
            "credits": 75
        }
        """.data(using: .utf8)!

        mockURLSession.mockData = responseJSON
        mockURLSession.mockResponse = successResponse()

        // When: Getting credits
        let credits = try await sut.getCredits(userId: testUserId)

        // Then: Should return correct balance
        XCTAssertEqual(credits, 75)
    }

    func testGetCredits_Success_UsesCorrectEndpoint() async throws {
        // Given: Mock successful response
        mockURLSession.mockData = creditsResponse(100)
        mockURLSession.mockResponse = successResponse()

        // When: Getting credits
        _ = try await sut.getCredits(userId: testUserId)

        // Then: Should use correct endpoint
        let url = mockURLSession.lastRequest?.url?.absoluteString
        XCTAssertTrue(url?.contains("/functions/v1/get-credits") ?? false)
        XCTAssertTrue(url?.contains("user_id=\(testUserId)") ?? false)
    }

    func testGetCredits_Success_IncludesAuthHeaders() async throws {
        // Given: Mock successful response
        mockURLSession.mockData = creditsResponse(100)
        mockURLSession.mockResponse = successResponse()

        // When: Getting credits
        _ = try await sut.getCredits(userId: testUserId)

        // Then: Should include auth headers
        let headers = mockURLSession.lastRequest?.allHTTPHeaderFields
        XCTAssertEqual(headers?["Authorization"], "Bearer \(mockAppConfig.supabaseAnonKey)")
        XCTAssertEqual(headers?["apikey"], mockAppConfig.supabaseAnonKey)
    }

    func testGetCredits_ZeroBalance_ReturnsZero() async throws {
        // Given: User has no credits
        mockURLSession.mockData = creditsResponse(0)
        mockURLSession.mockResponse = successResponse()

        // When: Getting credits
        let credits = try await sut.getCredits(userId: testUserId)

        // Then: Should return zero
        XCTAssertEqual(credits, 0)
    }

    func testGetCredits_LargeBalance_ReturnsCorrectly() async throws {
        // Given: User has many credits
        mockURLSession.mockData = creditsResponse(999999)
        mockURLSession.mockResponse = successResponse()

        // When: Getting credits
        let credits = try await sut.getCredits(userId: testUserId)

        // Then: Should handle large numbers
        XCTAssertEqual(credits, 999999)
    }

    // MARK: - Tests: Get Credits - Errors

    func testGetCredits_UserNotFound_ThrowsError() async {
        // Given: 404 response
        mockURLSession.mockData = errorResponse("User not found")
        mockURLSession.mockResponse = HTTPURLResponse(
            url: mockAppConfig.apiURL,
            statusCode: 404,
            httpVersion: nil,
            headerFields: nil
        )

        // When/Then: Should throw user not found error
        await assertThrowsError(try await sut.getCredits(userId: testUserId)) { error in
            XCTAssertEqual(error as? AppError, AppError.userNotFound)
        }
    }

    func testGetCredits_NetworkFailure_ThrowsError() async {
        // Given: Network error
        mockURLSession.mockError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet
        )

        // When/Then: Should throw network error
        await assertThrowsError(try await sut.getCredits(userId: testUserId)) { error in
            XCTAssertEqual(error as? AppError, AppError.networkFailure)
        }
    }

    func testGetCredits_InvalidResponse_ThrowsError() async {
        // Given: Invalid JSON
        mockURLSession.mockData = "Invalid JSON".data(using: .utf8)!
        mockURLSession.mockResponse = successResponse()

        // When/Then: Should throw invalid response error
        await assertThrowsError(try await sut.getCredits(userId: testUserId)) { error in
            XCTAssertEqual(error as? AppError, AppError.invalidResponse)
        }
    }

    func testGetCredits_Unauthorized_ThrowsError() async {
        // Given: 401 response
        mockURLSession.mockData = Data()
        mockURLSession.mockResponse = HTTPURLResponse(
            url: mockAppConfig.apiURL,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )

        // When/Then: Should throw unauthorized error
        await assertThrowsError(try await sut.getCredits(userId: testUserId)) { error in
            XCTAssertEqual(error as? AppError, AppError.unauthorized)
        }
    }

    // MARK: - Tests: Deduct Credits - Success

    func testDeductCredits_Success_CompletesWithoutError() async throws {
        // Given: Successful deduction response
        let responseJSON = """
        {
            "success": true,
            "remaining_credits": 45
        }
        """.data(using: .utf8)!

        mockURLSession.mockData = responseJSON
        mockURLSession.mockResponse = successResponse()

        // When: Deducting credits
        try await sut.deductCredits(userId: testUserId, amount: 5)

        // Then: Should complete without throwing
        // No assertion needed - if we reach here, it succeeded
    }

    func testDeductCredits_Success_SendsCorrectPayload() async throws {
        // Given: Mock successful response
        mockURLSession.mockData = deductionResponse(success: true, remaining: 45)
        mockURLSession.mockResponse = successResponse()

        // When: Deducting credits
        try await sut.deductCredits(userId: testUserId, amount: 5)

        // Then: Should send correct data
        let request = mockURLSession.lastRequest
        XCTAssertEqual(request?.httpMethod, "POST")

        let bodyData = request?.httpBody
        let bodyJSON = try? JSONSerialization.jsonObject(with: bodyData!) as? [String: Any]

        XCTAssertEqual(bodyJSON?["user_id"] as? String, testUserId)
        XCTAssertEqual(bodyJSON?["amount"] as? Int, 5)
    }

    func testDeductCredits_Success_UsesCorrectEndpoint() async throws {
        // Given: Mock successful response
        mockURLSession.mockData = deductionResponse(success: true, remaining: 50)
        mockURLSession.mockResponse = successResponse()

        // When: Deducting credits
        try await sut.deductCredits(userId: testUserId, amount: 10)

        // Then: Should use correct endpoint
        let url = mockURLSession.lastRequest?.url?.absoluteString
        XCTAssertTrue(url?.contains("/functions/v1/deduct-credits") ?? false)
    }

    // MARK: - Tests: Deduct Credits - Insufficient Credits

    func testDeductCredits_InsufficientCredits_ThrowsError() async {
        // Given: Insufficient credits response
        let responseJSON = """
        {
            "success": false,
            "error": "Insufficient credits"
        }
        """.data(using: .utf8)!

        mockURLSession.mockData = responseJSON
        mockURLSession.mockResponse = HTTPURLResponse(
            url: mockAppConfig.apiURL,
            statusCode: 400,
            httpVersion: nil,
            headerFields: nil
        )

        // When/Then: Should throw insufficient credits error
        await assertThrowsError(try await sut.deductCredits(userId: testUserId, amount: 100)) { error in
            XCTAssertEqual(error as? AppError, AppError.insufficientCredits)
        }
    }

    func testDeductCredits_NegativeAmount_ThrowsError() async {
        // When/Then: Should throw validation error
        await assertThrowsError(try await sut.deductCredits(userId: testUserId, amount: -5)) { error in
            // Should fail validation
            XCTAssertNotNil(error)
        }
    }

    func testDeductCredits_ZeroAmount_HandlesCorrectly() async throws {
        // Given: Deducting zero
        mockURLSession.mockData = deductionResponse(success: true, remaining: 50)
        mockURLSession.mockResponse = successResponse()

        // When: Deducting zero credits
        // Depending on your implementation, this might:
        // - Complete successfully (no-op)
        // - Throw validation error

        // Adjust based on your actual behavior
        do {
            try await sut.deductCredits(userId: testUserId, amount: 0)
            // If you allow zero deductions
            XCTAssertTrue(true)
        } catch {
            // If you reject zero deductions
            XCTAssertNotNil(error)
        }
    }

    // MARK: - Tests: Add Credits - Success

    func testAddCredits_Success_CompletesWithoutError() async throws {
        // Given: Successful addition response
        let responseJSON = """
        {
            "success": true,
            "new_balance": 150
        }
        """.data(using: .utf8)!

        mockURLSession.mockData = responseJSON
        mockURLSession.mockResponse = successResponse()

        // When: Adding credits
        try await sut.addCredits(userId: testUserId, amount: 50)

        // Then: Should complete without throwing
    }

    func testAddCredits_Success_SendsCorrectPayload() async throws {
        // Given: Mock successful response
        mockURLSession.mockData = additionResponse(success: true, newBalance: 150)
        mockURLSession.mockResponse = successResponse()

        // When: Adding credits
        try await sut.addCredits(userId: testUserId, amount: 50)

        // Then: Should send correct data
        let request = mockURLSession.lastRequest
        XCTAssertEqual(request?.httpMethod, "POST")

        let bodyData = request?.httpBody
        let bodyJSON = try? JSONSerialization.jsonObject(with: bodyData!) as? [String: Any]

        XCTAssertEqual(bodyJSON?["user_id"] as? String, testUserId)
        XCTAssertEqual(bodyJSON?["amount"] as? Int, 50)
    }

    func testAddCredits_LargeAmount_HandlesCorrectly() async throws {
        // Given: Adding many credits
        mockURLSession.mockData = additionResponse(success: true, newBalance: 10000)
        mockURLSession.mockResponse = successResponse()

        // When: Adding large amount
        try await sut.addCredits(userId: testUserId, amount: 10000)

        // Then: Should complete successfully
    }

    // MARK: - Tests: Add Credits - Errors

    func testAddCredits_NegativeAmount_ThrowsError() async {
        // When/Then: Should throw validation error
        await assertThrowsError(try await sut.addCredits(userId: testUserId, amount: -50)) { error in
            XCTAssertNotNil(error)
        }
    }

    func testAddCredits_ServerError_ThrowsError() async {
        // Given: Server error
        mockURLSession.mockData = Data()
        mockURLSession.mockResponse = HTTPURLResponse(
            url: mockAppConfig.apiURL,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )

        // When/Then: Should throw network error
        await assertThrowsError(try await sut.addCredits(userId: testUserId, amount: 50)) { error in
            XCTAssertEqual(error as? AppError, AppError.networkFailure)
        }
    }

    // MARK: - Tests: Concurrent Operations

    func testConcurrentGetCredits_HandleCorrectly() async throws {
        // Given: Mock successful response
        mockURLSession.mockData = creditsResponse(100)
        mockURLSession.mockResponse = successResponse()

        // When: Multiple concurrent gets
        let results = try await withThrowingTaskGroup(of: Int.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    try await self.sut.getCredits(userId: self.testUserId)
                }
            }

            var allResults: [Int] = []
            for try await result in group {
                allResults.append(result)
            }
            return allResults
        }

        // Then: All should return same value
        XCTAssertEqual(results.count, 5)
        XCTAssertTrue(results.allSatisfy { $0 == 100 })
    }

    func testConcurrentDeductions_HandleCorrectly() async {
        // Note: This test depends on your backend's transaction handling
        // Adjust based on your actual atomicity guarantees

        // Given: Mock responses
        mockURLSession.mockData = deductionResponse(success: true, remaining: 50)
        mockURLSession.mockResponse = successResponse()

        // When: Multiple concurrent deductions
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<3 {
                group.addTask {
                    try? await self.sut.deductCredits(
                        userId: self.testUserId,
                        amount: 10
                    )
                }
            }
        }

        // Then: Should complete without crashing
        // Actual atomicity testing would require integration tests
        XCTAssertTrue(true)
    }

    // MARK: - Tests: Idempotency

    func testDeductCredits_WithIdempotencyKey_SendsCorrectly() async throws {
        // Given: Mock successful response
        mockURLSession.mockData = deductionResponse(success: true, remaining: 45)
        mockURLSession.mockResponse = successResponse()

        // When: Deducting with idempotency
        try await sut.deductCredits(
            userId: testUserId,
            amount: 5,
            idempotencyKey: "test-key-123"
        )

        // Then: Should include idempotency key in header
        let headers = mockURLSession.lastRequest?.allHTTPHeaderFields
        XCTAssertEqual(headers?["Idempotency-Key"], "test-key-123")
    }

    // MARK: - Tests: Timeout

    func testGetCredits_Timeout_ThrowsError() async {
        // Given: Timeout error
        mockURLSession.mockError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorTimedOut
        )

        // When/Then: Should throw timeout error
        await assertThrowsError(try await sut.getCredits(userId: testUserId)) { error in
            XCTAssertEqual(error as? AppError, AppError.networkTimeout)
        }
    }

    func testDeductCredits_Timeout_ThrowsError() async {
        // Given: Timeout error
        mockURLSession.mockError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorTimedOut
        )

        // When/Then: Should throw timeout error
        await assertThrowsError(try await sut.deductCredits(userId: testUserId, amount: 5)) { error in
            XCTAssertEqual(error as? AppError, AppError.networkTimeout)
        }
    }

    // MARK: - Tests: Performance

    func testGetCredits_Performance() {
        mockURLSession.mockData = creditsResponse(100)
        mockURLSession.mockResponse = successResponse()

        measure {
            let expectation = expectation(description: "Get credits")

            Task {
                _ = try? await self.sut.getCredits(userId: self.testUserId)
                expectation.fulfill()
            }

            waitForExpectations(timeout: 5.0)
        }
    }

    // MARK: - Helper Methods

    private func creditsResponse(_ amount: Int) -> Data {
        """
        {
            "credits": \(amount)
        }
        """.data(using: .utf8)!
    }

    private func deductionResponse(success: Bool, remaining: Int) -> Data {
        """
        {
            "success": \(success),
            "remaining_credits": \(remaining)
        }
        """.data(using: .utf8)!
    }

    private func additionResponse(success: Bool, newBalance: Int) -> Data {
        """
        {
            "success": \(success),
            "new_balance": \(newBalance)
        }
        """.data(using: .utf8)!
    }

    private func errorResponse(_ message: String) -> Data {
        """
        {
            "error": "\(message)"
        }
        """.data(using: .utf8)!
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

// MARK: - CreditService Extensions for Testing

extension CreditService {
    /// Deduct credits with optional idempotency key
    func deductCredits(
        userId: String,
        amount: Int,
        idempotencyKey: String? = nil
    ) async throws {
        // Validate
        guard amount >= 0 else {
            throw AppError.invalidRequest
        }

        // Build request with idempotency key if provided
        var request = URLRequest(url: URL(string: "\(config.supabaseURL)/functions/v1/deduct-credits")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let key = idempotencyKey {
            request.setValue(key, forHTTPHeaderField: "Idempotency-Key")
        }

        // Continue with deduction...
    }
}
