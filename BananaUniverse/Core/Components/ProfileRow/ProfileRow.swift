//
//  ProfileRow.swift
//  BananaUniverse
//
//  Modern profile row component with icon, title, subtitle, and chevron.
//  Extracted from ProfilePreview for reuse across the app.
//  Apple HIG-compliant design with circular icon background.
//
//  Created: 2025-11-02
//  Migration: Phase 1.1 - Extract ProfileRow Component
//

import SwiftUI

// MARK: - Profile Row Component

struct ProfileRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var iconColor: Color? = nil
    let showChevron: Bool
    var action: (() -> Void)? = nil
    
    @Environment(\.colorScheme) var colorScheme
    
    // MARK: - Computed Properties
    
    private var resolvedIconColor: Color {
        if let iconColor = iconColor {
            return iconColor
        }
        return DesignTokens.Brand.primary(colorScheme)
    }
    
    // MARK: - Body
    
    var body: some View {
        Button(action: action ?? {}) {
            HStack(spacing: DesignTokens.Spacing.md) {
                // Icon with circular background
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(resolvedIconColor)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(resolvedIconColor.opacity(0.1))
                    )
                
                // Text Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(DesignTokens.Text.primary(colorScheme))
                        .multilineTextAlignment(.leading)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(DesignTokens.Typography.subheadline)
                            .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                            .multilineTextAlignment(.leading)
                    }
                }
                
                Spacer()
                
                // Chevron (optional)
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignTokens.Text.tertiary(colorScheme))
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.md)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Xcode Preview

#Preview("Profile Row") {
    VStack(spacing: DesignTokens.Spacing.md) {
        ProfileRow(
            icon: "person.circle.fill",
            title: "Username",
            subtitle: "Jan Söğancı",
            showChevron: false
        )
        
        ProfileRow(
            icon: "envelope.fill",
            title: "Email",
            subtitle: "jan@example.com",
            showChevron: false
        )
        
        ProfileRow(
            icon: "star.fill",
            title: "Credits",
            subtitle: "10 credits available",
            iconColor: DesignTokens.Brand.primary(.light),
            showChevron: true,
            action: {
                print("Credits tapped")
            }
        )
        
        ProfileRow(
            icon: "paintbrush.fill",
            title: "Theme",
            subtitle: "Auto",
            showChevron: true,
            action: {
                print("Theme tapped")
            }
        )
    }
    .padding()
    .background(DesignTokens.Background.primary(.light))
}

#Preview("Profile Row - Dark") {
    VStack(spacing: DesignTokens.Spacing.md) {
        ProfileRow(
            icon: "person.circle.fill",
            title: "Username",
            subtitle: "Jan Söğancı",
            showChevron: false
        )
        
        ProfileRow(
            icon: "envelope.fill",
            title: "Email",
            subtitle: "jan@example.com",
            showChevron: false
        )
        
        ProfileRow(
            icon: "star.fill",
            title: "Credits",
            subtitle: "10 credits available",
            iconColor: DesignTokens.Brand.primary(.dark),
            showChevron: true,
            action: {
                print("Credits tapped")
            }
        )
        
        ProfileRow(
            icon: "paintbrush.fill",
            title: "Theme",
            subtitle: "Auto",
            showChevron: true,
            action: {
                print("Theme tapped")
            }
        )
    }
    .padding()
    .background(DesignTokens.Background.primary(.dark))
    .preferredColorScheme(.dark)
}

#Preview("Profile Row - Destructive") {
    ProfileRow(
        icon: "trash",
        title: "Delete Account",
        iconColor: DesignTokens.Semantic.error(.light),
        showChevron: true,
        action: {
            print("Delete account tapped")
        }
    )
    .padding()
    .background(DesignTokens.Background.primary(.light))
}

