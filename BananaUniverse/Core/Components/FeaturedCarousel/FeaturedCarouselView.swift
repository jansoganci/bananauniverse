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
                        CarouselCard(tool: tool)
                            .onTapGesture {
                                handleToolTap(tool)
                            }
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 220)
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

// NOTE: CarouselCard component is now in separate file
// See: BananaUniverse/Core/Components/FeaturedCarousel/CarouselCard.swift

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