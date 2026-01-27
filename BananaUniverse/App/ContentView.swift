//
//  ContentView.swift
//  noname_banana
//
//  Created by Can Soğancı on 13.10.2025.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0 // Start on Home tab with welcome screen
    @State private var selectedTool: Tool? = nil
    @State private var navigationPath = NavigationPath()

    @StateObject private var authService = HybridAuthService.shared
    @StateObject private var creditManager = CreditManager.shared
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var appState = AppState()

    @Environment(\.colorScheme) var systemColorScheme

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $selectedTab) {
            // Home Tab - Browse and select themes
            NavigationStack(path: $navigationPath) {
                HomeView(onToolSelected: navigateToImageProcessing)
                    .navigationDestination(for: Tool.self) { tool in
                        ImageProcessingView(
                            viewModel: ImageProcessingViewModel(theme: tool),
                            sourceTab: $selectedTab,
                            targetTab: 0
                        )
                        .environmentObject(themeManager)
                        .environmentObject(appState)
                    }
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(0)

            // Create Tab - Image processing with nano-banana models
            ImageProcessingView(
                viewModel: ImageProcessingViewModel(theme: nil),
                sourceTab: $selectedTab,
                targetTab: 1
            )
            .environmentObject(themeManager)
            .environmentObject(appState)
            .tabItem {
                Label("Create", systemImage: "wand.and.stars")
            }
            .tag(1)

            // Library Tab - Past jobs and history
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "square.stack.3d.up.fill")
                }
                .tag(2)

            // Profile Tab - User settings and account management
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(3)
            }
            .id(themeManager.resolvedColorScheme) // Force TabView recreation on theme change
            .accentColor(DesignTokens.Brand.primary(themeManager.resolvedColorScheme))
            .preferredColorScheme(themeManager.preference == .system ? nil : (themeManager.preference == .dark ? .dark : .light))
            .environmentObject(authService)
            .environmentObject(themeManager)
            .environmentObject(appState)
            .onChange(of: systemColorScheme) { newScheme in
            themeManager.updateResolvedScheme(systemScheme: newScheme)
            updateTabBarAppearance(for: themeManager.resolvedColorScheme)
        }
        .onChange(of: themeManager.preference) { _ in
            let resolvedScheme = themeManager.resolveTheme(systemScheme: systemColorScheme)
            themeManager.updateResolvedScheme(systemScheme: systemColorScheme)
            updateTabBarAppearance(for: resolvedScheme)
        }
            .onAppear {
                themeManager.updateResolvedScheme(systemScheme: systemColorScheme)
                updateTabBarAppearance(for: themeManager.resolvedColorScheme)
            }

            // Offline Banner - Appears at top when no internet connection
            VStack {
                OfflineBanner()
                    .environmentObject(themeManager)
                Spacer()
            }
            .allowsHitTesting(false) // Allow taps to pass through to content below
        }
    }
    
    // MARK: - TabBar Appearance Update
    
    private func updateTabBarAppearance(for colorScheme: ColorScheme) {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        
        // Use DesignTokens for theme-aware colors
        appearance.backgroundColor = UIColor(swiftUIColor: DesignTokens.Background.secondary(colorScheme))
        
        // Inactive tabs
        let inactiveColor = UIColor(swiftUIColor: DesignTokens.Text.tertiary(colorScheme))
        appearance.stackedLayoutAppearance.normal.iconColor = inactiveColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: inactiveColor]
        
        // Active tab (using brand primary color)
        let activeColor = UIColor(swiftUIColor: DesignTokens.Brand.primary(colorScheme))
        appearance.stackedLayoutAppearance.selected.iconColor = activeColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: activeColor]
        
        // Apply appearance to all tab bars
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    // Function to handle navigation to ImageProcessing with tool
    private func navigateToImageProcessing(_ tool: Tool) {
        navigationPath.append(tool)
    }
}

#Preview {
    ContentView()
}
