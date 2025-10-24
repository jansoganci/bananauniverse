//
//  QuotaDisplayView.swift
//  BananaUniverse
//
//  Created by AI Assistant
//  Unified quota display component for consistent UI across the app
//

import SwiftUI

struct QuotaDisplayView: View {
    let creditManager: HybridCreditManager
    @EnvironmentObject var themeManager: ThemeManager
    let style: QuotaDisplayStyle
    let action: (() -> Void)?
    
    init(
        creditManager: HybridCreditManager? = nil,
        style: QuotaDisplayStyle = .compact,
        action: (() -> Void)? = nil
    ) {
        self.creditManager = creditManager ?? HybridCreditManager.shared
        self.style = style
        self.action = action
    }
    
    var body: some View {
        Group {
            switch style {
            case .compact:
                compactView
            case .detailed:
                detailedView
            case .badge:
                badgeView
            }
        }
    }
    
    // MARK: - Compact Style (for headers)
    private var compactView: some View {
        Button(action: action ?? {}) {
            HStack(spacing: 8) {
                iconView
                textView
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(DesignTokens.Surface.primary(themeManager.resolvedColorScheme))
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Detailed Style (for profile sections)
    private var detailedView: some View {
        Button(action: action ?? {}) {
            HStack {
                iconView
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    titleView
                    valueView
                }
                
                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.md)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Badge Style (for notifications/alerts)
    private var badgeView: some View {
        Button(action: action ?? {}) {
            HStack(spacing: 4) {
                iconView
                textView
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(DesignTokens.Brand.primary(.light).opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Subviews
    private var iconView: some View {
        Image(systemName: creditManager.isPremiumUser ? "infinity" : "star.fill")
            .font(.system(size: style == .compact ? 13 : 20))
            .foregroundColor(DesignTokens.Brand.primary(.light))
    }
    
    private var titleView: some View {
        Text(creditManager.isPremiumUser ? "Credits" : "Daily Credits")
            .font(.system(size: 16))
            .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
    }
    
    private var valueView: some View {
        Text(creditManager.isPremiumUser ? "Unlimited" : "\(creditManager.dailyQuotaUsed) / \(creditManager.dailyQuotaLimit)")
            .font(.system(size: style == .compact ? 13 : 14))
            .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
    }
    
    private var textView: some View {
        HStack(spacing: 4) {
            // Warning icon when quota is low
            if creditManager.shouldShowQuotaWarning {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.orange)
            }
            
            Text(creditManager.isPremiumUser ? "∞" : "Daily Credits: \(creditManager.remainingQuota) / \(creditManager.dailyQuotaLimit)")
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .foregroundColor(creditManager.shouldShowQuotaWarning ? .orange : DesignTokens.Text.primary(themeManager.resolvedColorScheme))
        }
    }
}

// MARK: - Display Styles
enum QuotaDisplayStyle {
    case compact    // For headers (like UnifiedHeaderBar)
    case detailed   // For profile sections
    case badge      // For notifications/alerts
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        // Compact style (header)
        QuotaDisplayView(style: .compact, action: {})
        
        // Detailed style (profile)
        QuotaDisplayView(style: .detailed, action: {})
        
        // Badge style (notification)
        QuotaDisplayView(style: .badge, action: {})
        
        Spacer()
    }
    .padding()
    .background(DesignTokens.Background.primary(.dark))
}
