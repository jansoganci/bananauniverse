//
//  ContentView.swift
//  noname_banana
//
//  Created by Can Soğancı on 13.10.2025.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0 // Start on Home tab with welcome screen
    @StateObject private var authService = HybridAuthService.shared
    @StateObject private var creditManager = CreditManager.shared
    @StateObject private var themeManager = ThemeManager()
    // @StateObject private var adaptyService = AdaptyService.shared
    @StateObject private var appState = AppState()
    @StateObject private var chatViewModel = ChatViewModel()
    
    @Environment(\.colorScheme) var systemColorScheme
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab - Welcome screen with quick actions
            HomeView(onToolSelected: navigateToChatWithTool)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            // Chat Tab - Main photo processing feature
            ChatView(viewModel: chatViewModel)
                .id(appState.sessionId)
                .tabItem {
                    Label("Chat", systemImage: "message.fill")
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
        .onChange(of: appState.sessionId) { _ in
            chatViewModel.reset()
            chatViewModel.apply(appState.currentPrompt)
        }
        .onAppear {
            themeManager.updateResolvedScheme(systemScheme: systemColorScheme)
            updateTabBarAppearance(for: themeManager.resolvedColorScheme)
            
            // Initialize AdaptyService after Adapty SDK is activated
            Task {
                do {
                    // Mock initialization - always succeeds
                    // try await adaptyService.initialize()
                    print("Mock: AdaptyService initialized")
                } catch {
                    print("Mock: AdaptyService initialization skipped")
                }
            }
        }
    }
    
    // MARK: - TabBar Appearance Update
    
    private func updateTabBarAppearance(for colorScheme: ColorScheme) {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        
        // Use DesignTokens for theme-aware colors
        if colorScheme == .dark {
            // Dark theme colors using DesignTokens
            appearance.backgroundColor = UIColor(swiftUIColor: DesignTokens.Background.secondary(.dark))
            
            // Inactive tabs
            let inactiveColor = UIColor(swiftUIColor: DesignTokens.Text.secondary(.dark))
            appearance.stackedLayoutAppearance.normal.iconColor = inactiveColor
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: inactiveColor]
            
            // Active tab (using golden accent for dark mode)
            let activeColor = UIColor(swiftUIColor: DesignTokens.Brand.primary(.dark))
            appearance.stackedLayoutAppearance.selected.iconColor = activeColor
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: activeColor]
        } else {
            // Light theme colors using DesignTokens
            appearance.backgroundColor = UIColor(swiftUIColor: DesignTokens.Background.secondary(.light))
            
            // Inactive tabs
            let inactiveColor = UIColor(swiftUIColor: DesignTokens.Text.tertiary(.light))
            appearance.stackedLayoutAppearance.normal.iconColor = inactiveColor
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: inactiveColor]
            
            // Active tab (using golden primary for light mode)
            let activeColor = UIColor(swiftUIColor: DesignTokens.Brand.primary(.light))
            appearance.stackedLayoutAppearance.selected.iconColor = activeColor
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: activeColor]
        }
        
        // Apply appearance to all tab bars
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    // Function to handle navigation to Chat with tool
    private func navigateToChatWithTool(_ tool: Tool) {
        appState.selectPreset(id: tool.id, prompt: tool.prompt)
        selectedTab = 1 // Switch to Chat tab
    }
}

#Preview {
    ContentView()
}
