//
//  PaywallCTAButton.swift
//  BananaUniverse
//
//  CTA button for paywall - dynamic text showing selected credits
//

import SwiftUI
import RevenueCat

struct PaywallCTAButton: View {
    let selectedPackage: Package?
    let selectedCredits: Int
    let isLoading: Bool
    let onPurchase: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: onPurchase) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.9)
                        .tint(DesignTokens.Text.onBrand(colorScheme))
                } else {
                    Text("paywall_button_cta_dynamic".localized(selectedCredits))
                        .font(.system(size: 18, weight: .bold))
                }
            }
            .foregroundColor(DesignTokens.Text.onBrand(colorScheme))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(buttonBackground)
            .cornerRadius(16)
            .shadow(
                color: selectedPackage != nil && !isLoading
                    ? Color(hex: "34C759").opacity(0.4)
                    : Color.clear,
                radius: 8,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(selectedPackage == nil || isLoading)
        .opacity((selectedPackage != nil && !isLoading) ? 1.0 : 0.5)
        .animation(.easeInOut(duration: 0.2), value: selectedPackage != nil)
        .accessibilityLabel("paywall_button_cta_dynamic".localized(selectedCredits))
        .accessibilityHint(selectedPackage != nil ? "paywall_button_cta_dynamic".localized(selectedCredits) : "paywall_error_no_package_title".localized)
    }

    private var buttonBackground: some View {
        Group {
            if selectedPackage != nil && !isLoading {
                LinearGradient(
                    colors: [
                        Color(hex: "4CD964"), // iOS Green Start
                        Color(hex: "2EBD4A")  // iOS Green End
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                LinearGradient(
                    colors: [
                        DesignTokens.Gradients.primaryStart(colorScheme).opacity(0.4),
                        DesignTokens.Gradients.primaryEnd(colorScheme).opacity(0.4)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        }
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0), value: configuration.isPressed)
    }
}
