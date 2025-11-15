//
//  FeaturedCarouselView.swift
//  BananaUniverse
//
//  Created by AI Assistant on 01.11.2025.
//  5-item carousel with auto-advance (3s interval, infinite loop)
//

import SwiftUI

// MARK: - Featured Carousel View Component
struct FeaturedCarouselView: View {
    // MARK: - Properties
    let tools: [Tool]
    let onToolTap: (Tool) -> Void
    
    // MARK: - State
    @State private var currentIndex: Int = 0
    @State private var autoAdvanceTimer: Timer?
    @State private var isPaused: Bool = false
    @State private var pauseTimer: Timer?
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 0) {
            if !tools.isEmpty {
                TabView(selection: $currentIndex) {
                    ForEach(Array(infiniteTools.enumerated()), id: \.offset) { index, tool in
                        FeaturedCarouselCard(
                            tool: tool,
                            onTap: { 
                                handleToolTap(tool)
                            }
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 200)
                .onAppear {
                    // Start at middle section for infinite scroll
                    currentIndex = tools.count
                    startAutoAdvance()
                }
                .onDisappear {
                    stopAutoAdvance()
                }
                .onChange(of: currentIndex) { newIndex in
                    handleInfiniteScroll(newIndex)
                }
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { _ in
                            pauseAutoAdvance()
                        }
                )
            }
        }
    }
    
    // MARK: - Computed Properties
    
    // Create 3x array for infinite scroll illusion
    private var infiniteTools: [Tool] {
        guard !tools.isEmpty else { return [] }
        return tools + tools + tools
    }
    
    // MARK: - Actions
    private func handleToolTap(_ tool: Tool) {
        DesignTokens.Haptics.impact(.medium)
        pauseAutoAdvance()
        onToolTap(tool)
    }
    
    // MARK: - Infinite Scroll Handler
    
    private func handleInfiniteScroll(_ newIndex: Int) {
        let toolCount = tools.count
        guard toolCount > 0 else { return }
        
        // Seamlessly jump to middle section when reaching edges
        // This creates an infinite scroll illusion
        
        if newIndex < toolCount {
            // In first section - jump to middle section
            DispatchQueue.main.async {
                currentIndex = newIndex + toolCount
            }
        } else if newIndex >= toolCount * 2 {
            // In third section - jump to middle section
            DispatchQueue.main.async {
                currentIndex = newIndex - toolCount
            }
        }
    }
    
    // MARK: - Timer Management
    private func startAutoAdvance() {
        guard tools.count > 1 else { return }
        
        stopAutoAdvance() // Clear any existing timer
        
        autoAdvanceTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            if !isPaused {
                withAnimation(.easeInOut(duration: 0.5)) {
                    currentIndex = currentIndex + 1
                }
            }
        }
    }
    
    private func stopAutoAdvance() {
        autoAdvanceTimer?.invalidate()
        autoAdvanceTimer = nil
        pauseTimer?.invalidate()
        pauseTimer = nil
    }
    
    private func pauseAutoAdvance() {
        isPaused = true
        pauseTimer?.invalidate()
        
        // Resume after 2 seconds of idle
        pauseTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            isPaused = false
        }
    }
}

// MARK: - Featured Carousel Card Component
struct FeaturedCarouselCard: View {
    // MARK: - Properties
    let tool: Tool
    let onTap: () -> Void
    
    // MARK: - State
    @State private var isPressed = false
    @StateObject private var creditManager = CreditManager.shared
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        DesignTokens.Brand.primary(.light).opacity(0.8),
                        DesignTokens.Brand.primary(.light).opacity(0.6)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Content overlay
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    // Featured Badge
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Text("Featured")
                            .font(DesignTokens.Typography.caption1)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.2))
                            )
                        
                        Spacer()
                    }
                    
                    Spacer()
                    
                    // Tool info
                    VStack(alignment: .leading, spacing: 4) {
                        // Icon
                        Image(systemName: tool.placeholderIcon)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white)
                        
                        // Title
                        Text(tool.name)
                            .font(DesignTokens.Typography.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(DesignTokens.Spacing.md)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(height: 200)
        .cornerRadius(DesignTokens.CornerRadius.lg)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(minimumDuration: 0) { pressing in
            isPressed = pressing
        } perform: {}
        .padding(.horizontal, DesignTokens.Spacing.md)
    }
}

// MARK: - Preview
#if DEBUG
#Preview {
    FeaturedCarouselView(
        tools: Array(Theme.mockThemes.prefix(5)),
        onToolTap: { _ in }
    )
    .environmentObject(ThemeManager())
}
#endif