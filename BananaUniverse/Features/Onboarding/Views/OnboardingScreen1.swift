//
//  OnboardingScreen1.swift
//  BananaUniverse
//
//  Created by Claude on 2025-11-22.
//  Purpose: Welcome screen with hero image showcase
//

import SwiftUI

struct OnboardingScreen1: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            Spacer()

            // Hero Image - Medieval Painting
            AsyncImage(url: URL(string: "https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/theme-thumbnails/medieval-painting.jpg")) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 280, height: 180)
                        .cornerRadius(DesignTokens.CornerRadius.lg)
                        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
                case .empty:
                    placeholderView
                case .failure:
                    placeholderView
                @unknown default:
                    placeholderView
                }
            }
            .frame(width: 280, height: 180)

            // Title
            Text("Welcome to BananaUniverse")
                .font(DesignTokens.Typography.largeTitle)
                .foregroundColor(DesignTokens.Text.primary(colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.md)

            // Subtitle
            Text("Transform your photos into viral content in seconds")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.lg)

            Spacer()
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
    }

    // MARK: - Placeholder View

    private var placeholderView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                .fill(
                    LinearGradient(
                        colors: [
                            DesignTokens.Brand.primary(colorScheme).opacity(0.3),
                            DesignTokens.Brand.secondary(colorScheme).opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 8) {
                Image(systemName: "figure.stand")
                    .font(.system(size: 60))
                    .foregroundColor(DesignTokens.Brand.primary(colorScheme))

                Text("Loading...")
                    .font(DesignTokens.Typography.caption1)
                    .foregroundColor(DesignTokens.Text.secondary(colorScheme))
            }
        }
        .frame(width: 280, height: 180)
    }
}

// MARK: - Preview
#if DEBUG
#Preview {
    OnboardingScreen1()
        .background(Color.black)
}
#endif
