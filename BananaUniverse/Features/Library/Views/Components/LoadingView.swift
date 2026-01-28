//
//  LoadingView.swift
//  noname_banana
//
//  Created by AI Assistant on 16.10.2025.
//  Loading state view for Library screen
//

import SwiftUI

// MARK: - Loading View
struct LoadingView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.lg) {
                // Recent Activity Skeleton
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    SkeletonView()
                        .frame(width: 150, height: 24)
                        .cornerRadius(4)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DesignTokens.Spacing.md) {
                            ForEach(0..<3) { _ in
                                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                                    SkeletonView()
                                        .frame(width: 120, height: 120)
                                        .cornerRadius(DesignTokens.CornerRadius.md)
                                    
                                    SkeletonView()
                                        .frame(width: 100, height: 16)
                                        .cornerRadius(4)
                                    
                                    SkeletonView()
                                        .frame(width: 60, height: 12)
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                }
                .padding(.top, DesignTokens.Spacing.md)
                .padding(.horizontal, DesignTokens.Spacing.md)
                
                // All History Skeleton
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    SkeletonView()
                        .frame(width: 120, height: 24)
                        .cornerRadius(4)
                    
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        SkeletonView()
                            .frame(width: 80, height: 16)
                            .cornerRadius(4)
                            .padding(.horizontal, DesignTokens.Spacing.md)
                        
                        VStack(spacing: 0) {
                            ForEach(0..<3) { index in
                                HStack(spacing: DesignTokens.Spacing.sm) {
                                    SkeletonView()
                                        .frame(width: 80, height: 80)
                                        .cornerRadius(DesignTokens.CornerRadius.sm)
                                    
                                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                                        SkeletonView()
                                            .frame(width: 150, height: 18)
                                            .cornerRadius(4)
                                        
                                        SkeletonView()
                                            .frame(width: 60, height: 14)
                                            .cornerRadius(4)
                                        
                                        SkeletonView()
                                            .frame(width: 100, height: 12)
                                            .cornerRadius(4)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, DesignTokens.Spacing.md)
                                .padding(.vertical, DesignTokens.Spacing.sm)
                                
                                if index < 2 {
                                    Divider()
                                        .background(DesignTokens.Surface.secondary(themeManager.resolvedColorScheme))
                                        .padding(.leading, 80 + DesignTokens.Spacing.md + DesignTokens.Spacing.sm)
                                }
                            }
                        }
                        .background(DesignTokens.Surface.secondary(themeManager.resolvedColorScheme))
                        .cornerRadius(DesignTokens.CornerRadius.md)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
            }
        }
        .background(DesignTokens.Background.primary(themeManager.resolvedColorScheme))
        .accessibilityLabel("accessibility_loading_history".localized)
    }
}
