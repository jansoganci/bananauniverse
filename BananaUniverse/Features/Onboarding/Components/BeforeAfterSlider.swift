//
//  BeforeAfterSlider.swift
//  BananaUniverse
//
//  Created by AI Assistant
//  Purpose: Interactive before/after image comparison slider
//

import SwiftUI

struct BeforeAfterSlider: View {
    @State private var sliderPosition: CGFloat = 0.5
    @State private var isDragging = false
    @State private var autoPlayTimer: Timer? = nil
    
    let beforeImageName: String?
    let afterImageName: String?
    let beforeImageURL: String?
    let afterImageURL: String?
    
    @Environment(\.colorScheme) var colorScheme
    
    init(
        beforeImageName: String? = nil,
        afterImageName: String? = nil,
        beforeImageURL: String? = nil,
        afterImageURL: String? = nil
    ) {
        self.beforeImageName = beforeImageName
        self.afterImageName = afterImageName
        self.beforeImageURL = beforeImageURL
        self.afterImageURL = afterImageURL
    }
    
    var body: some View {
        GeometryReader { geometry in
            let width = max(1, geometry.size.width)
            let height = max(1, geometry.size.height)
            let maskWidth = max(0, width * sliderPosition)
            let handleOffset = max(0, width * sliderPosition - 20)
            let dividerOffset = width * sliderPosition - 1
            
            ZStack(alignment: .leading) {
                // Before image (background)
                if let beforeImageName = beforeImageName {
                    Image(beforeImageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: width, height: height)
                        .clipped()
                } else {
                    CachedAsyncImage(url: beforeImageURL != nil ? URL(string: beforeImageURL!) : nil)
                        .frame(width: width, height: height)
                        .clipped()
                }
                
                // After image (masked based on slider position)
                if let afterImageName = afterImageName {
                    Image(afterImageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: width, height: height)
                        .clipped()
                        .mask(
                            Rectangle()
                                .frame(width: maskWidth)
                        )
                } else {
                    CachedAsyncImage(url: afterImageURL != nil ? URL(string: afterImageURL!) : nil)
                        .frame(width: width, height: height)
                        .clipped()
                        .mask(
                            Rectangle()
                                .frame(width: maskWidth)
                        )
                }
                
                // Slider handle
                VStack {
                    Spacer()
                    HStack(spacing: 0) {
                        Spacer()
                            .frame(width: handleOffset)
                        
                        ZStack {
                            Circle()
                                .fill(DesignTokens.Surface.primary(colorScheme))
                                .frame(width: 40, height: 40)
                                .shadow(color: DesignTokens.ShadowColors.default(colorScheme), radius: 8, x: 0, y: 2)
                            
                            Image(systemName: "line.horizontal.3")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(DesignTokens.Text.tertiary(colorScheme))
                        }
                        
                        Spacer()
                    }
                    Spacer()
                }
                
                // Divider line
                Rectangle()
                    .fill(DesignTokens.Brand.primary(colorScheme).opacity(0.8))
                    .frame(width: 2)
                    .offset(x: dividerOffset)
            }
            .cornerRadius(DesignTokens.CornerRadius.lg)
            .shadow(color: DesignTokens.ShadowColors.primary(colorScheme), radius: 12, x: 0, y: 6)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard width > 0 else { return }
                        isDragging = true
                        autoPlayTimer?.invalidate()
                        autoPlayTimer = nil
                        let newPosition = max(0, min(1, value.location.x / width))
                        withAnimation(.interactiveSpring()) {
                            sliderPosition = newPosition
                        }
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .onAppear {
                startAutoPlay()
            }
            .onDisappear {
                autoPlayTimer?.invalidate()
                autoPlayTimer = nil
            }
        }
        .frame(height: 280)
    }

    private func startAutoPlay() {
        // Subtle back-and-forth animation to show the "magic"
        withAnimation(.easeInOut(duration: 1.5).delay(0.5)) {
            sliderPosition = 0.2
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 2.0)) {
                sliderPosition = 0.8
            }
        }

        // Periodic subtle movement if user hasn't touched it
        autoPlayTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            guard !isDragging else { return }
            withAnimation(.easeInOut(duration: 2.0)) {
                sliderPosition = sliderPosition > 0.5 ? 0.3 : 0.7
            }
        }
    }
}

// MARK: - Preview
#if DEBUG
#Preview {
    BeforeAfterSlider(
        beforeImageName: "OnboardingBefore",
        afterImageName: "OnboardingAfter"
    )
    .padding()
    .background(DesignTokens.Background.primary(.dark))
}
#endif
