//
//  HomeView_Redesign_Preview.swift
//  BananaUniverse
//
//  PREVIEW ONLY - This file is for design visualization only
//  Does not affect the actual app. Safe to preview in Xcode.
//  Amazon/Netflix style horizontal scroll layout
//

import SwiftUI

// MARK: - Preview: Amazon-Style Home Screen Structure
struct HomeView_Redesign_Preview: View {
    @State private var rawSearch: String = ""
    @Environment(\.colorScheme) var systemColorScheme
    @StateObject private var themeManager = ThemeManager()
    
    private var colorScheme: ColorScheme {
        themeManager.resolvedColorScheme
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Fixed Header + Search Bar (Sticky)
                headerView
                searchBarView
                
                // Scrollable Content
                contentView
            }
            .background(DesignTokens.Background.primary(colorScheme))
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
        }
        .environmentObject(themeManager)
        .onAppear {
            themeManager.updateResolvedScheme(systemScheme: systemColorScheme)
        }
        .onChange(of: systemColorScheme) { newScheme in
            themeManager.updateResolvedScheme(systemScheme: newScheme)
        }
    }
    
    // MARK: - View Components
    
    private var headerView: some View {
        HStack {
            Image(systemName: "photo.stack")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(DesignTokens.Brand.primary(colorScheme))
            
            Spacer()
            
            Text("PRO")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(DesignTokens.Brand.primary(colorScheme))
                .cornerRadius(8)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .frame(height: 56)
        .background(DesignTokens.Background.primary(colorScheme))
    }
    
    private var searchBarView: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                .font(.system(size: 16, weight: .medium))
            
            TextField("Search tools…", text: $rawSearch)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .font(.system(size: 16))
                .foregroundColor(DesignTokens.Text.primary(colorScheme))
            
            if !rawSearch.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        rawSearch = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(DesignTokens.Background.secondary(colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(DesignTokens.Text.secondary(colorScheme).opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
    }
    
    private var contentView: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.xl) {
                // Featured Carousel
                if !featuredTools.isEmpty {
                    FeaturedCarouselView(
                        tools: featuredTools,
                        onToolTap: { _ in }
                    )
                    .padding(.top, DesignTokens.Spacing.md)
                }
                
                // Category Rows (Horizontal Scroll)
                CategoryRow(
                    title: "Photo Editor",
                    tools: getToolsForCategory("main_tools"),
                    onToolTap: { _ in },
                    onSeeAllTap: {}
                )
                
                CategoryRow(
                    title: "Seasonal",
                    tools: getToolsForCategory("seasonal"),
                    onToolTap: { _ in },
                    onSeeAllTap: {}
                )
                
                CategoryRow(
                    title: "Pro Photos",
                    tools: getToolsForCategory("pro_looks"),
                    onToolTap: { _ in },
                    onSeeAllTap: {}
                )
                
                CategoryRow(
                    title: "Enhancer",
                    tools: getToolsForCategory("restoration"),
                    onToolTap: { _ in },
                    onSeeAllTap: {}
                )
            }
            .padding(.bottom, DesignTokens.Spacing.lg)
        }
    }
    
    // MARK: - Helper Methods
    
    private func getToolsForCategory(_ categoryId: String) -> [Tool] {
        #if DEBUG
        switch categoryId {
        case "main_tools":
            return Theme.mockThemes
        case "seasonal":
            return Theme.mockThemes
        case "pro_looks":
            return Theme.mockThemes
        case "restoration":
            return Theme.mockThemes
        default:
            return []
        }
        #else
        return []
        #endif
    }
    
    private var featuredTools: [Tool] {
        #if DEBUG
        let mainTools = Array(Theme.mockThemes.prefix(2))
        let seasonalTools = Array(Theme.mockThemes.prefix(1))
        let proTools = Array(Theme.mockThemes.prefix(1))
        let restorationTools = Array(Theme.mockThemes.prefix(1))
        
        return Array((mainTools + seasonalTools + proTools + restorationTools).prefix(5))
        #else
        return []
        #endif
    }
}

// MARK: - Xcode Preview

#if DEBUG
#Preview("Home Redesign") {
    HomeView_Redesign_Preview()
}

#Preview("Home Redesign - Dark") {
    HomeView_Redesign_Preview()
        .preferredColorScheme(.dark)
}
#endif
