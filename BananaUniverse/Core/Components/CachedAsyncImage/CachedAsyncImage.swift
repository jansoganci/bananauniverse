//
//  CachedAsyncImage.swift
//  BananaUniverse
//
//  Created by AI Assistant on 26.01.2026.
//  Centralized image component with Kingfisher caching, skeleton loading, and fallbacks.
//

import SwiftUI
import Kingfisher

struct CachedAsyncImage: View {
    let url: URL?
    var placeholderIcon: String = "photo"
    var contentMode: SwiftUI.ContentMode = .fill
    var showsProgressView: Bool = false
    
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        if let url = url {
            KFImage(url)
                .resizable()
                .placeholder {
                    SkeletonView()
                }
                .fade(duration: 0.25)
                .onFailure { error in
                    print("Error loading image from \(url): \(error.localizedDescription)")
                }
                .aspectRatio(contentMode: contentMode == .fill ? .fill : .fit)
        } else {
            fallbackView
        }
    }
    
    private var fallbackView: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: placeholderIcon)
                .font(.system(size: 24))
                .foregroundColor(DesignTokens.Text.tertiary(themeManager.resolvedColorScheme))
            
            if showsProgressView {
                Text("core_invalid_url".localized)
                    .font(DesignTokens.Typography.caption1)
                    .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Surface.secondary(themeManager.resolvedColorScheme))
    }
}

#Preview {
    Group {
        CachedAsyncImage(url: URL(string: "https://example.com/image.jpg"))
            .frame(width: 200, height: 200)
            .previewDisplayName("Valid URL (Skeleton)")
        
        CachedAsyncImage(url: nil)
            .frame(width: 200, height: 200)
            .previewDisplayName("Nil URL (Fallback)")
    }
    .environmentObject(ThemeManager())
}
