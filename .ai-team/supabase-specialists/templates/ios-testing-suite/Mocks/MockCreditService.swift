import Foundation

// MARK: - Mock Credit Service

/// Mock implementation of CreditServiceProtocol for testing
/// Simulates credit balance management and transactions
class MockCreditService: CreditServiceProtocol {

    // MARK: - Properties

    /// Current credit balance to return
    var creditsToReturn: Int = 100

    /// Error to throw from operations
    var errorToThrow: Error?

    /// Simulates network delay (in seconds)
    var simulatedDelay: TimeInterval = 0

    // MARK: - Call Tracking

    var getCreditsCallCount = 0
    var deductCreditsCallCount = 0
    var deductCreditsCalls: [(userId: String, amount: Int)] = []
    var getCreditsForUserCalls: [String] = []

    // MARK: - CreditServiceProtocol

    func getCredits(userId: String) async throws -> Int {
        getCreditsCallCount += 1
        getCreditsForUserCalls.append(userId)

        // Simulate network delay
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }

        // Throw error if configured
        if let error = errorToThrow {
            throw error
        }

        return creditsToReturn
    }

    func deductCredits(userId: String, amount: Int) async throws {
        deductCreditsCallCount += 1
        deductCreditsCalls.append((userId: userId, amount: amount))

        // Simulate network delay
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }

        // Throw error if configured
        if let error = errorToThrow {
            throw error
        }

        // Simulate deduction
        if creditsToReturn >= amount {
            creditsToReturn -= amount
        } else {
            throw AppError.insufficientCredits
        }
    }

    func addCredits(userId: String, amount: Int) async throws {
        // Simulate network delay
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }

        // Throw error if configured
        if let error = errorToThrow {
            throw error
        }

        // Simulate addition
        creditsToReturn += amount
    }

    // MARK: - Helper Methods

    /// Reset all state for next test
    func reset() {
        creditsToReturn = 100
        errorToThrow = nil
        simulatedDelay = 0
        getCreditsCallCount = 0
        deductCreditsCallCount = 0
        deductCreditsCalls = []
        getCreditsForUserCalls = []
    }

    /// Configure success scenario with specific balance
    func setupSuccess(credits: Int) {
        self.creditsToReturn = credits
        self.errorToThrow = nil
    }

    /// Configure failure scenario with error
    func setupFailure(error: Error) {
        self.errorToThrow = error
    }

    /// Configure insufficient credits scenario
    func setupInsufficientCredits() {
        self.creditsToReturn = 0
        self.errorToThrow = nil
    }

    /// Verify deduction was called with expected values
    func verifyDeductionCalled(userId: String, amount: Int) -> Bool {
        deductCreditsCalls.contains { $0.userId == userId && $0.amount == amount }
    }
}
