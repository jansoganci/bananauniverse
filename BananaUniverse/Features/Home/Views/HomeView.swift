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
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject var themeManager: ThemeManager
    let onToolSelected: (Tool) -> Void // Callback for tool selection
    @State private var searchQuery: String = ""
    @State private var isSearchPresented = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header Bar
                UnifiedHeaderBar(
                    title: "",
                    leftContent: .appLogo(32),
                    rightContent: .custom {
                        AnyView(
                            HStack(spacing: DesignTokens.Spacing.md) {
                                // Search icon button
                                Button {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                        isSearchPresented = true
                                    }
                                } label: {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 22, weight: .medium))
                                        .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                                }
                                .accessibilityLabel("Search tools")
                                .accessibilityHint("Double tap to open search")
                                
                                // Credits badge
                                QuotaDisplayView(
                                    style: .compact,
                                    action: {
                                        showPaywall = true
                                    }
                                )
                            }
                        )
                    }
                )
                
                
                // Quota Warning Banner
                if creditManager.creditsRemaining <= 1 {
                    QuotaWarningBanner()
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .padding(.top, DesignTokens.Spacing.sm)
                }

                // Content Area
                ScrollView {
                    VStack(spacing: DesignTokens.Spacing.md) {
                        // Loading State
                        if viewModel.isLoading && !viewModel.hasData {
                            HomeSkeletonView()
                        }

                        // Featured Carousel
                        if !viewModel.carouselThemes.isEmpty {
                            FeaturedCarouselView(
                                tools: viewModel.carouselThemes,
                                onToolTap: handleToolTap
                            )
                            .padding(.horizontal, DesignTokens.Spacing.md)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                removal: .opacity.combined(with: .scale(scale: 1.05))
                            ))
                        }

                        // Category Rows (Horizontal Scroll - Amazon Style)
                        ForEach(viewModel.categories, id: \.id) { category in
                            CategoryRow(
                                title: category.name,
                                tools: viewModel.remainingThemes(for: category.id),
                                onToolTap: handleToolTap,
                                onSeeAllTap: nil, // Placeholder for future "See All" functionality
                                searchQuery: nil // No inline filtering anymore
                            )
                        }
                    }
                    .padding(.top, DesignTokens.Spacing.sm)
                    .padding(.bottom, DesignTokens.Spacing.lg)
                }
            }
            .background(DesignTokens.Background.primary(themeManager.resolvedColorScheme))
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                if !viewModel.hasData {
                    viewModel.loadData()
                }
            }
            .refreshable {
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
        .fullScreenCover(isPresented: $isSearchPresented) {
            FullScreenSearchView(
                searchQuery: $searchQuery,
                tools: viewModel.allThemes,
                onToolSelected: { tool in
                    isSearchPresented = false
                    handleToolTap(tool)
                },
                onDismiss: {
                    isSearchPresented = false
                }
            )
            .environmentObject(themeManager)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallPreview()
        }
    }
    
    // MARK: - Helper Methods

    private func handleToolTap(_ tool: Tool) {
        DesignTokens.Haptics.impact(.light)
        
        // All tools are accessible to everyone (credits are consumed per use)
        // Navigate to Chat tab with the tool
        onToolSelected(tool)
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
            .foregroundColor(DesignTokens.Text.onBrand(themeManager.resolvedColorScheme))
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(DesignTokens.Brand.primary(themeManager.resolvedColorScheme))
            .cornerRadius(DesignTokens.CornerRadius.sm)
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


// MARK: - Home Skeleton View
struct HomeSkeletonView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // Carousel Skeleton
            SkeletonView()
                .frame(width: 350, height: 220)
                .cornerRadius(DesignTokens.CornerRadius.lg)
                .padding(.horizontal, DesignTokens.Spacing.md)
            
            // Category Rows Skeleton
            ForEach(0..<2) { _ in
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    SkeletonView()
                        .frame(width: 120, height: 20)
                        .cornerRadius(4)
                        .padding(.horizontal, DesignTokens.Spacing.md)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DesignTokens.Spacing.md) {
                            ForEach(0..<3) { _ in
                                VStack(alignment: .center, spacing: DesignTokens.Spacing.sm) {
                                    SkeletonView()
                                        .frame(width: 120, height: 120)
                                        .cornerRadius(DesignTokens.CornerRadius.sm)
                                    
                                    SkeletonView()
                                        .frame(width: 80, height: 16)
                                        .cornerRadius(4)
                                }
                            }
                        }
                        .padding(.horizontal, DesignTokens.Spacing.md)
                    }
                }
            }
        }
        .padding(.top, DesignTokens.Spacing.sm)
    }
}

#Preview {
    HomeView(onToolSelected: { _ in })
        .environmentObject(ThemeManager())
}
