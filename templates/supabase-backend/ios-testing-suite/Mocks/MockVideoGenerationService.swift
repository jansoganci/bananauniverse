import Foundation
import UIKit

// MARK: - Mock Video Generation Service

/// Mock implementation of VideoGenerationServiceProtocol for testing
/// Simulates video generation requests and responses
class MockVideoGenerationService: VideoGenerationServiceProtocol {

    // MARK: - Properties

    /// Response to return from generateVideo()
    var responseToReturn: VideoGenerationResponse?

    /// Error to throw from generateVideo()
    var errorToThrow: Error?

    /// Simulates network delay (in seconds)
    var simulatedDelay: TimeInterval = 0

    // MARK: - Call Tracking

    var generateVideoCallCount = 0
    var generateVideoRequests: [VideoGenerationRequest] = []
    var lastRequest: VideoGenerationRequest?

    // MARK: - VideoGenerationServiceProtocol

    func generateVideo(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        generateVideoCallCount += 1
        generateVideoRequests.append(request)
        lastRequest = request

        // Simulate network delay
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }

        // Throw error if configured
        if let error = errorToThrow {
            throw error
        }

        // Return configured response or default
        if let response = responseToReturn {
            return response
        }

        // Default success response
        return VideoGenerationResponse(
            jobId: "job-\(UUID().uuidString)",
            status: "queued",
            estimatedTime: 120
        )
    }

    // MARK: - Helper Methods

    /// Reset all state for next test
    func reset() {
        responseToReturn = nil
        errorToThrow = nil
        simulatedDelay = 0
        generateVideoCallCount = 0
        generateVideoRequests = []
        lastRequest = nil
    }

    /// Configure success scenario
    func setupSuccess(jobId: String = "test-job-123", status: String = "queued") {
        self.responseToReturn = VideoGenerationResponse(
            jobId: jobId,
            status: status,
            estimatedTime: 120
        )
        self.errorToThrow = nil
    }

    /// Configure failure scenario
    func setupFailure(error: Error) {
        self.errorToThrow = error
        self.responseToReturn = nil
    }

    /// Verify request was made with expected parameters
    func verifyRequestMade(
        userId: String,
        themeId: String,
        prompt: String
    ) -> Bool {
        generateVideoRequests.contains { request in
            request.userId == userId &&
            request.themeId == themeId &&
            request.prompt == prompt
        }
    }
}

// MARK: - Mock Video Generation Models

extension VideoGenerationRequest {
    /// Mock request for testing
    static var mockRequest: VideoGenerationRequest {
        VideoGenerationRequest(
            userId: "user-123",
            themeId: "theme-cinematic-1",
            prompt: "A cat playing piano in a jazz club",
            imageURL: nil,
            settings: VideoSettings(
                resolution: "1080p",
                duration: 5,
                aspectRatio: "16:9"
            )
        )
    }
}

extension VideoGenerationResponse {
    /// Mock success response
    static var mockSuccess: VideoGenerationResponse {
        VideoGenerationResponse(
            jobId: "job-success-123",
            status: "queued",
            estimatedTime: 120
        )
    }

    /// Mock response with custom job ID
    static func mock(jobId: String, status: String = "queued") -> VideoGenerationResponse {
        VideoGenerationResponse(
            jobId: jobId,
            status: status,
            estimatedTime: 120
        )
    }
}
