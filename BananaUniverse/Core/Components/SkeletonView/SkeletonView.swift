//
//  SkeletonView.swift
//  BananaUniverse
//
//  Created by AI Assistant on 26.01.2026.
//  Reusable skeleton loading animation component.
//

import SwiftUI

struct SkeletonView: View {
    @State private var isAnimating = false
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        DesignTokens.Surface.secondary(themeManager.resolvedColorScheme),
                        DesignTokens.Surface.elevated(themeManager.resolvedColorScheme),
                        DesignTokens.Surface.secondary(themeManager.resolvedColorScheme)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .opacity(isAnimating ? 0.3 : 0.6)
            .animation(
                .easeInOut(duration: 1.0)
                .repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

#Preview {
    SkeletonView()
        .frame(width: 200, height: 200)
        .environmentObject(ThemeManager())
}
