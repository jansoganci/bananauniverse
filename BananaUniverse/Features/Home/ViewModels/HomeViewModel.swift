//
//  HomeViewModel.swift
//  BananaUniverse
//
//  Created by AI Assistant on 2025.
//  ViewModel for HomeView - manages theme/tool data from database
//

import SwiftUI
import Combine

/// ViewModel for HomeView that manages dynamic theme/tool loading from database
@MainActor
class HomeViewModel: ObservableObject {

    // MARK: - Published Properties

    /// All available themes from database
    @Published var allThemes: [Theme] = []

    /// Featured themes for carousel (filtered from allThemes)
    @Published var featuredThemes: [Theme] = []

    /// All active categories from database
    @Published var categories: [Category] = []

    /// Loading state
    @Published var isLoading: Bool = false

    /// Error message for display
    @Published var errorMessage: String?

    /// Show error alert
    @Published var showingErrorAlert: Bool = false

    // MARK: - Dependencies

    private let themeService: ThemeServiceProtocol
    private let categoryService: CategoryServiceProtocol

    // MARK: - Initialization

    init(
        themeService: ThemeServiceProtocol = ThemeService.shared,
        categoryService: CategoryServiceProtocol = CategoryService.shared
    ) {
        self.themeService = themeService
        self.categoryService = categoryService
    }

    // MARK: - Public Methods

    /// Load themes and categories from database
    func loadData() {
        Task {
            isLoading = true
            errorMessage = nil

            do {
                // Load categories first (needed for filtering themes)
                let fetchedCategories = try await categoryService.fetchCategories()
                
                // Fetch themes from API
                let themes = try await themeService.fetchThemes()

                // Update state on main thread
                categories = fetchedCategories
                allThemes = themes
                featuredThemes = themes.filter { $0.isFeatured }

                print("✅ HomeViewModel: Loaded \(themes.count) themes (\(featuredThemes.count) featured) and \(fetchedCategories.count) categories")

            } catch {
                handleError(error)
            }

            isLoading = false
        }
    }

    /// Refresh themes and categories (clears cache and reloads)
    func refresh() {
        // Clear caches to force fresh fetch
        if let service = themeService as? ThemeService {
            service.clearCache()
        }
        if let service = categoryService as? CategoryService {
            service.clearCache()
        }
        loadData()
    }

    // MARK: - Computed Properties

    /// Get themes by category
    /// - Parameter category: Category ID (e.g., "main_tools", "seasonal")
    /// - Returns: Array of themes in that category
    func themesByCategory(_ category: String) -> [Theme] {
        return allThemes.filter { $0.category == category }
    }

    /// Get themes for featured carousel (top 5 featured themes)
    var carouselThemes: [Theme] {
        return Array(featuredThemes.prefix(5))
    }

    /// Check if data is loaded
    var hasData: Bool {
        return !allThemes.isEmpty
    }

    // MARK: - Search Support

    /// Filter themes by search query
    /// - Parameter query: Search query string
    /// - Returns: Filtered themes matching query
    func searchThemes(query: String) -> [Theme] {
        guard !query.isEmpty else {
            return allThemes
        }

        return allThemes.filter { theme in
            theme.name.localizedCaseInsensitiveContains(query) ||
            theme.prompt.localizedCaseInsensitiveContains(query) ||
            theme.category.localizedCaseInsensitiveContains(query) ||
            (theme.description?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    // MARK: - Category Support

    /// Get themes for a category
    /// - Parameter category: Category ID
    /// - Returns: All themes in category (featured flag is used for carousel only)
    func remainingThemes(for category: String) -> [Theme] {
        return themesByCategory(category)
    }

    // MARK: - Private Methods

    private func handleError(_ error: Error) {
        if let appError = error as? AppError {
            errorMessage = appError.errorDescription
        } else {
            errorMessage = "Failed to load themes. Please try again."
        }
        showingErrorAlert = true

        print("❌ HomeViewModel: Error loading themes - \(error.localizedDescription)")
    }
}

// MARK: - Mock ViewModel for Previews

#if DEBUG
extension HomeViewModel {
    /// Create a mock ViewModel with sample data for previews
    static var mock: HomeViewModel {
        let mockThemeService = MockThemeService()
        mockThemeService.mockThemes = Theme.mockThemes
        let mockCategoryService = MockCategoryService()
        mockCategoryService.mockCategories = Category.mockCategories
        let viewModel = HomeViewModel(themeService: mockThemeService, categoryService: mockCategoryService)
        viewModel.allThemes = Theme.mockThemes
        viewModel.featuredThemes = Theme.mockThemes.filter { $0.isFeatured }
        viewModel.categories = Category.mockCategories
        return viewModel
    }

    /// Create a mock ViewModel that simulates loading state
    static var mockLoading: HomeViewModel {
        let viewModel = HomeViewModel(themeService: MockThemeService(), categoryService: MockCategoryService())
        viewModel.isLoading = true
        return viewModel
    }

    /// Create a mock ViewModel that simulates error state
    static var mockError: HomeViewModel {
        let mockThemeService = MockThemeService()
        mockThemeService.shouldFail = true
        let viewModel = HomeViewModel(themeService: mockThemeService, categoryService: MockCategoryService())
        viewModel.errorMessage = "Failed to load themes"
        viewModel.showingErrorAlert = true
        return viewModel
    }
}
#endif
