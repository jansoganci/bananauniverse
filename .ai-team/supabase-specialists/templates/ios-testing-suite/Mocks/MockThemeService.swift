import Foundation

// MARK: - Mock Theme Service

/// Mock implementation of ThemeServiceProtocol for testing
/// Allows full control over service behavior and responses
class MockThemeService: ThemeServiceProtocol {

    // MARK: - Properties

    /// Themes to return from fetchThemes()
    var themesToReturn: [Theme] = []

    /// Error to throw from fetchThemes()
    var errorToThrow: Error?

    /// Tracks how many times fetchThemes() was called
    var fetchThemesCallCount = 0

    /// Simulates network delay (in seconds)
    var simulatedDelay: TimeInterval = 0

    /// Records all calls for verification
    var fetchThemesCalls: [Date] = []

    // MARK: - ThemeServiceProtocol

    func fetchThemes() async throws -> [Theme] {
        fetchThemesCallCount += 1
        fetchThemesCalls.append(Date())

        // Simulate network delay if configured
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }

        // Throw error if configured
        if let error = errorToThrow {
            throw error
        }

        // Return configured themes
        return themesToReturn
    }

    // MARK: - Helper Methods

    /// Reset all state for next test
    func reset() {
        themesToReturn = []
        errorToThrow = nil
        fetchThemesCallCount = 0
        simulatedDelay = 0
        fetchThemesCalls = []
    }

    /// Configure success scenario with themes
    func setupSuccess(themes: [Theme]) {
        self.themesToReturn = themes
        self.errorToThrow = nil
    }

    /// Configure failure scenario with error
    func setupFailure(error: Error) {
        self.errorToThrow = error
        self.themesToReturn = []
    }
}

// MARK: - Mock Theme Data

extension Theme {
    /// Mock theme for testing - Cinematic featured theme
    static var mockCinematic: Theme {
        Theme(
            id: "theme-cinematic-1",
            name: "Cinematic",
            description: "Hollywood-style videos with dramatic effects",
            isFeatured: true,
            thumbnailURL: "https://example.com/cinematic.jpg",
            costPerGeneration: 5,
            category: "video",
            settings: ThemeSettings(
                defaultResolution: "1080p",
                defaultDuration: 5,
                supportedAspectRatios: ["16:9", "9:16"]
            )
        )
    }

    /// Mock theme for testing - Anime non-featured theme
    static var mockAnime: Theme {
        Theme(
            id: "theme-anime-1",
            name: "Anime",
            description: "Japanese animation style",
            isFeatured: false,
            thumbnailURL: "https://example.com/anime.jpg",
            costPerGeneration: 3,
            category: "video",
            settings: ThemeSettings(
                defaultResolution: "720p",
                defaultDuration: 3,
                supportedAspectRatios: ["16:9"]
            )
        )
    }

    /// Mock theme for testing - Realistic featured theme
    static var mockRealistic: Theme {
        Theme(
            id: "theme-realistic-1",
            name: "Realistic",
            description: "Photorealistic video generation",
            isFeatured: true,
            thumbnailURL: "https://example.com/realistic.jpg",
            costPerGeneration: 8,
            category: "video",
            settings: ThemeSettings(
                defaultResolution: "1080p",
                defaultDuration: 5,
                supportedAspectRatios: ["16:9", "9:16", "1:1"]
            )
        )
    }

    /// Array of mock themes for bulk testing
    static var mockThemes: [Theme] {
        [mockCinematic, mockAnime, mockRealistic]
    }

    /// Featured themes only
    static var mockFeaturedThemes: [Theme] {
        mockThemes.filter { $0.isFeatured }
    }
}
