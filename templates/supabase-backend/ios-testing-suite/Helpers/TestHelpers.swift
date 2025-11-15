import Foundation
import XCTest

// MARK: - Async Testing Helpers

/// Helper functions for testing async Swift code
extension XCTestCase {

    /// Wait for an async condition to become true
    /// - Parameters:
    ///   - timeout: Maximum time to wait (default 5 seconds)
    ///   - description: Description for failure message
    ///   - condition: Async closure that returns Bool
    func waitForCondition(
        timeout: TimeInterval = 5.0,
        description: String = "Condition not met",
        condition: @escaping () async -> Bool
    ) async throws {
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < timeout {
            if await condition() {
                return
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }

        XCTFail("\(description) - Timeout after \(timeout) seconds")
    }

    /// Execute async code and wait for completion
    /// - Parameters:
    ///   - timeout: Maximum time to wait
    ///   - operation: Async operation to execute
    func awaitAsync(
        timeout: TimeInterval = 5.0,
        _ operation: @escaping () async throws -> Void
    ) async throws {
        try await operation()
    }
}

// MARK: - Published Property Testing

/// Helper for testing @Published properties in ObservableObject
class PublishedPropertyObserver<T> {
    private var cancellables = Set<AnyCancellable>()
    private(set) var values: [T] = []

    init<Object: ObservableObject>(
        _ object: Object,
        keyPath: KeyPath<Object, T>
    ) {
        object.objectWillChange
            .sink { [weak self, weak object] _ in
                guard let self = self, let object = object else { return }
                let value = object[keyPath: keyPath]
                self.values.append(value)
            }
            .store(in: &cancellables)

        // Capture initial value
        values.append(object[keyPath: keyPath])
    }

    /// Get value at specific index
    func value(at index: Int) -> T? {
        guard index < values.count else { return nil }
        return values[index]
    }

    /// Most recent value
    var latestValue: T? {
        values.last
    }

    /// Number of times property changed
    var changeCount: Int {
        values.count - 1
    }
}

// MARK: - XCTest Extensions

extension XCTestCase {

    /// Assert that an async operation throws a specific error
    func assertThrowsError<T>(
        _ expression: @autoclosure () async throws -> T,
        _ message: String = "",
        file: StaticString = #file,
        line: UInt = #line,
        _ errorHandler: (Error) -> Void = { _ in }
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expected error to be thrown", file: file, line: line)
        } catch {
            errorHandler(error)
        }
    }

    /// Assert that two arrays contain the same elements (order doesn't matter)
    func assertArraysEqual<T: Equatable>(
        _ array1: [T],
        _ array2: [T],
        _ message: String = "Arrays are not equal",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            Set(array1),
            Set(array2),
            message,
            file: file,
            line: line
        )
    }
}

// MARK: - Mock User Defaults

/// Mock implementation of UserDefaults for testing
class MockUserDefaultsManager {
    private var storage: [String: Any] = [:]

    var language: String {
        get { storage["language"] as? String ?? "en" }
        set { storage["language"] = newValue }
    }

    var themePreference: String {
        get { storage["themePreference"] as? String ?? "system" }
        set { storage["themePreference"] = newValue }
    }

    var currentUserId: String? {
        get { storage["currentUserId"] as? String }
        set { storage["currentUserId"] = newValue }
    }

    var deviceId: String? {
        get { storage["deviceId"] as? String }
        set { storage["deviceId"] = newValue }
    }

    var onboardingCompleted: Bool {
        get { storage["onboardingCompleted"] as? Bool ?? false }
        set { storage["onboardingCompleted"] = newValue }
    }

    var hasSeenWelcomeBanner: Bool {
        get { storage["hasSeenWelcomeBanner"] as? Bool ?? false }
        set { storage["hasSeenWelcomeBanner"] = newValue }
    }

    /// Reset all stored values
    func reset() {
        storage.removeAll()
    }

    /// Set initial test state
    func setupTestState(
        userId: String = "test-user-123",
        language: String = "en",
        theme: String = "system"
    ) {
        self.currentUserId = userId
        self.language = language
        self.themePreference = theme
        self.onboardingCompleted = true
    }
}

// MARK: - Test Data Builders

/// Builder pattern for creating test data
struct TestDataBuilder {

    /// Create a test theme with customizable properties
    static func theme(
        id: String = UUID().uuidString,
        name: String = "Test Theme",
        description: String = "Test description",
        isFeatured: Bool = false,
        cost: Int = 5
    ) -> Theme {
        Theme(
            id: id,
            name: name,
            description: description,
            isFeatured: isFeatured,
            thumbnailURL: "https://example.com/\(id).jpg",
            costPerGeneration: cost,
            category: "video",
            settings: ThemeSettings(
                defaultResolution: "1080p",
                defaultDuration: 5,
                supportedAspectRatios: ["16:9"]
            )
        )
    }

    /// Create multiple test themes
    static func themes(count: Int, featured: Int = 0) -> [Theme] {
        var themes: [Theme] = []

        for i in 0..<count {
            themes.append(
                theme(
                    id: "theme-\(i)",
                    name: "Theme \(i)",
                    isFeatured: i < featured
                )
            )
        }

        return themes
    }

    /// Create a test video generation request
    static func videoRequest(
        userId: String = "test-user",
        themeId: String = "test-theme",
        prompt: String = "Test prompt",
        imageURL: String? = nil
    ) -> VideoGenerationRequest {
        VideoGenerationRequest(
            userId: userId,
            themeId: themeId,
            prompt: prompt,
            imageURL: imageURL,
            settings: VideoSettings(
                resolution: "1080p",
                duration: 5,
                aspectRatio: "16:9"
            )
        )
    }
}

// MARK: - Import for Combine (needed for Published observer)
import Combine
