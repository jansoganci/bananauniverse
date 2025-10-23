//
//  HomeView.swift
//  noname_banana
//
//  Created by AI Assistant on 13.10.2025.
//

import SwiftUI

struct HomeView: View {
    @State private var selectedCategory: String = "main_tools"
    @State private var showPaywall = false
    @StateObject private var authService = HybridAuthService.shared
    @StateObject private var creditManager = HybridCreditManager.shared
    @EnvironmentObject var themeManager: ThemeManager
    let onToolSelected: (String) -> Void // Callback for tool selection
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header Bar
                UnifiedHeaderBar(
                    title: "",
                    leftContent: .appLogo(32),
                    rightContent: creditManager.isPremiumUser ? nil : .getProButton({ 
                        showPaywall = true
                        // TODO: insert Adapty Paywall ID here - placement: home_get_pro
                    })
                )
                
                // Category Tabs
                CategoryTabs(
                    selectedCategory: $selectedCategory
                )
                
                // Content Area
                ScrollView {
                    VStack(spacing: DesignTokens.Spacing.lg) {
                        // Featured Tool Card
                        if let featuredTool = featuredTool {
                            FeaturedToolCard(
                                tool: featuredTool,
                                onUseTool: { handleToolTap(featuredTool) },
                                onLearnMore: { showToolInfo(featuredTool) }
                            )
                            .padding(.horizontal, DesignTokens.Spacing.md)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                removal: .opacity.combined(with: .scale(scale: 1.05))
                            ))
                        }
                        
                        // Tools Grid Section
                        ToolGridSection(
                            tools: remainingTools,
                            showPremiumBadge: shouldShowPremiumBadge,
                            onToolTap: handleToolTap,
                            category: selectedCategory
                        )
                        .animation(DesignTokens.Animation.smooth, value: selectedCategory)
                    }
                    .padding(.top, DesignTokens.Spacing.md)
                    .padding(.bottom, DesignTokens.Spacing.lg)
                }
            }
            .background(DesignTokens.Background.primary(themeManager.resolvedColorScheme))
            .navigationTitle("")
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showPaywall) {
            PreviewPaywallView()
        }
    }
    
    // MARK: - Computed Properties
    
    /// Featured tool for current category
    private var featuredTool: Tool? {
        CategoryFeaturedMapping.featuredTool(for: selectedCategory)
    }
    
    /// Remaining tools (excluding featured)
    private var remainingTools: [Tool] {
        CategoryFeaturedMapping.remainingTools(for: selectedCategory)
    }
    
    /// All tools for current category (for backward compatibility)
    private var currentTools: [Tool] {
        CategoryFeaturedMapping.currentTools(for: selectedCategory)
    }
    
    private var shouldShowPremiumBadge: Bool {
        // Hide badges for premium-only sections to reduce visual clutter
        switch selectedCategory {
        case "pro_looks":
            return false // All Pro Looks tools are premium, no need for individual badges
        default:
            return true // Show badges for mixed sections (Main Tools, Restoration)
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleToolTap(_ tool: Tool) {
        if tool.requiresPro {
            showPaywall = true
            // TODO: insert Adapty Paywall ID here - placement: home_tool_lock
        } else {
            // Navigate to Chat tab with the tool's prompt
            onToolSelected(tool.prompt)
        }
    }
    
    private func showToolInfo(_ tool: Tool) {
        // TODO: Implement tool info modal or navigation
        // For now, just show an alert or navigate to tool details
        print("Show tool info for: \(tool.title)")
    }
}

// MARK: - Category Tabs Component
struct CategoryTabs: View {
    @Binding var selectedCategory: String
    @EnvironmentObject var themeManager: ThemeManager
    
    private let categories = [
        (id: "main_tools", icon: "wrench.and.screwdriver", label: "Main Tools"),
        (id: "pro_looks", icon: "camera.fill", label: "Pro Looks"),
        (id: "restoration", icon: "arrow.triangle.2.circlepath", label: "Restoration")
    ]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(categories, id: \.id) { category in
                    TabButton(
                        icon: category.icon,
                        label: category.label,
                        isActive: selectedCategory == category.id,
                        onTap: {
                            // Add haptic feedback for category switching
                            DesignTokens.Haptics.selectionChanged()
                            
                            // Enhanced animation for category switching
                            withAnimation(DesignTokens.Animation.spring) {
                                selectedCategory = category.id
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
        }
        .background(DesignTokens.Background.primary(themeManager.resolvedColorScheme))
    }
}

#Preview {
    HomeView(onToolSelected: { _ in })
        .environmentObject(ThemeManager())
}
