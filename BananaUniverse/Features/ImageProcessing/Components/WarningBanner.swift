//
//  WarningBanner.swift
//  BananaUniverse
//
//  Purpose: Warning banner for result page
//

import SwiftUI

struct WarningBanner: View {
    @Binding var isVisible: Bool
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        if isVisible {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.black)
                    .font(.system(size: 14, weight: .semibold))
                
                Text("image_processing_warning_save".localized)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, 8)
            .background(
                DesignTokens.Semantic.warning(themeManager.resolvedColorScheme)
            )
            .cornerRadius(8)
            .padding(.top, DesignTokens.Spacing.sm)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isVisible)
        }
    }
}

