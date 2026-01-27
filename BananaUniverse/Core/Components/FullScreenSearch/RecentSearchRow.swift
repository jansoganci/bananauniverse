//
//  RecentSearchRow.swift
//  BananaUniverse
//
//  Created by AI Assistant on 2026-01-27.
//  Recent search row component for FullScreenSearchView
//

import SwiftUI

struct RecentSearchRow: View {
    let query: String
    let onTap: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignTokens.Spacing.md) {
                // Clock icon
                Image(systemName: "clock")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(DesignTokens.Text.tertiary(colorScheme))
                
                // Search query text
                Text(query)
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(DesignTokens.Text.primary(colorScheme))
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Recent search: \(query). Double tap to search again.")
    }
}

#Preview {
    VStack {
        RecentSearchRow(query: "background remover", onTap: {})
        Divider()
        RecentSearchRow(query: "anime style", onTap: {})
        Divider()
        RecentSearchRow(query: "upscale", onTap: {})
    }
    .padding()
}
