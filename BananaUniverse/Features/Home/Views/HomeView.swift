//
//  HomeView.swift
//  noname_banana
//
//  Created by AI Assistant on 13.10.2025.
//

import SwiftUI

struct HomeView: View {
    @State private var showPaywall = false
    @StateObject private var authService = HybridAuthService.shared
    @StateObject private var creditManager = CreditManager.shared
    @StateObject private var viewModel = HomeViewModel() // ✅ NEW: ViewModel for dynamic data
    @EnvironmentObject var themeManager: ThemeManager
    let onToolSelected: (Tool) -> Void // Callback for tool selection
    @State private var rawSearch: String = ""
    @State private var searchQuery: String = ""
    @State private var searchTimer: Timer?
    @State private var hasSearchResults: Bool = true
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header Bar
                UnifiedHeaderBar(
                    title: "",
                    leftContent: .appLogo(32),
                    rightContent: .quotaBadge(creditManager.creditsRemaining, { 
                        showPaywall = true
                    })
                )
                
                
                // Quota Warning Banner
                if creditManager.creditsRemaining <= 1 {
                    QuotaWarningBanner()
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .padding(.top, DesignTokens.Spacing.sm)
                }
                
                // Search Bar
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                        .font(.system(size: 16, weight: .medium))

                    TextField("Search tools…", text: $rawSearch)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .font(.system(size: 16))
                        .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                        .onChange(of: rawSearch) { newValue in
                            searchTimer?.invalidate()
                            searchTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                                self.searchQuery = sanitizeSearch(newValue)
                                // Optional console analytics:
                                // print("📊 ANALYTICS", ["event":"search_performed","query": self.searchQuery])
                            }
                        }
                        .accessibilityLabel("Search tools")
                        .accessibilityHint("Type to filter available tools")

                    if !rawSearch.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                rawSearch = ""
                                searchQuery = ""
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                                .font(.system(size: 16))
                        }
                        .accessibilityLabel("Clear search")
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(DesignTokens.Background.secondary(themeManager.resolvedColorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(DesignTokens.Text.secondary(themeManager.resolvedColorScheme).opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.xs)
                
                // Content Area
                ScrollView {
                    VStack(spacing: DesignTokens.Spacing.md) {
                        // Loading State
                        if viewModel.isLoading && !viewModel.hasData {
                            ProgressView()
                                .padding(.top, 60)
                        }

                        // Featured Carousel (only show when not searching)
                        if searchQuery.isEmpty && !viewModel.carouselThemes.isEmpty {
                            FeaturedCarouselView(
                                tools: viewModel.carouselThemes, // ✅ CHANGED: Use ViewModel data
                                onToolTap: handleToolTap
                            )
                            .padding(.top, DesignTokens.Spacing.sm)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                removal: .opacity.combined(with: .scale(scale: 1.05))
                            ))
                        }

                        // Empty State (when searching with no results)
                        if !searchQuery.isEmpty && !hasSearchResults {
                            VStack(spacing: DesignTokens.Spacing.md) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 48, weight: .light))
                                    .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                                    .padding(.top, 60)

                                Text("No tools found")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))

                                Text("Try a different search term")
                                    .font(.system(size: 14))
                                    .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                            .transition(.opacity)
                        }

                        // Category Rows (Horizontal Scroll - Amazon Style)
                        // ✅ CHANGED: Use dynamic categories from database
                        ForEach(viewModel.categories, id: \.id) { category in
                            CategoryRow(
                                title: category.name,
                                tools: viewModel.remainingThemes(for: category.id),
                                onToolTap: handleToolTap,
                                onSeeAllTap: nil, // Placeholder for future "See All" functionality
                                searchQuery: searchQuery.isEmpty ? nil : searchQuery
                            )
                        }
                    }
                    .padding(.top, DesignTokens.Spacing.md)
                    .padding(.bottom, DesignTokens.Spacing.lg)
                }
            }
            .background(DesignTokens.Background.primary(themeManager.resolvedColorScheme))
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                // ✅ NEW: Load themes from database on appear
                if !viewModel.hasData {
                    viewModel.loadData()
                }
            }
            .onDisappear {
                // Fix timer memory leak
                searchTimer?.invalidate()
                searchTimer = nil
            }
            .onChange(of: searchQuery) { _ in
                // Update search results state
                updateSearchResults()
            }
            .refreshable {
                // ✅ NEW: Pull to refresh support
                viewModel.refresh()
            }
            .alert("Error Loading Themes", isPresented: $viewModel.showingErrorAlert) {
                Button("OK", role: .cancel) {}
                Button("Retry") {
                    viewModel.loadData()
                }
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallPreview()
        }
    }
    
    // MARK: - Computed Properties
    // ✅ REMOVED: Hardcoded categories - now using viewModel.categories (database-driven)
    
    
    // MARK: - Helper Methods

    private func handleToolTap(_ tool: Tool) {
        DesignTokens.Haptics.impact(.light)
        
        // All tools are accessible to everyone (credits are consumed per use)
        // Navigate to Chat tab with the tool
        onToolSelected(tool)
    }

    private func sanitizeSearch(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let capped = String(trimmed.prefix(100))
        // allow alphanumeric, space, dot, dash, underscore
        return capped.filter { $0.isLetter || $0.isNumber || " .-_".contains($0) }
    }

    private func updateSearchResults() {
        guard !searchQuery.isEmpty else {
            hasSearchResults = true
            return
        }

        // ✅ CHANGED: Use ViewModel search instead of static arrays
        let matchingTools = viewModel.searchThemes(query: searchQuery)

        withAnimation(.easeInOut(duration: 0.2)) {
            hasSearchResults = !matchingTools.isEmpty
        }
    }
}


// MARK: - Quota Warning Banner
struct QuotaWarningBanner: View {
    @StateObject private var creditManager = CreditManager.shared
    @State private var showPaywall = false
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(DesignTokens.Semantic.warning(themeManager.resolvedColorScheme))
                .font(.system(size: 16))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Low Credits")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                
                Text("\(creditManager.creditsRemaining) credit\(creditManager.creditsRemaining == 1 ? "" : "s") remaining")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
            }
            
            Spacer()
            
            Button("Buy Credits") {
                showPaywall = true
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(DesignTokens.Brand.primary(.light))
            .cornerRadius(8)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(DesignTokens.Semantic.warning(themeManager.resolvedColorScheme).opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(DesignTokens.Semantic.warning(themeManager.resolvedColorScheme).opacity(0.3), lineWidth: 1)
                )
        )
        .sheet(isPresented: $showPaywall) {
            PaywallPreview()
        }
    }
}

#Preview {
    HomeView(onToolSelected: { _ in })
        .environmentObject(ThemeManager())
}
