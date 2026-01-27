//
//  DesignTokens.swift
//  Flario
//
//  Flario Brand Palette - Electric Lime + Charcoal
//  Date: 2026-01-27
//  Theme: Fun, Energetic, Approachable
//

import SwiftUI

// MARK: - FLARIO DESIGN TOKENS

/// **Design Philosophy**: Fun AI Photo Editor for Everyone
/// - Electric Lime for energy and action
/// - Clean modern iOS design following Apple HIG
/// - OLED-optimized deep charcoal for battery efficiency
/// - WCAG AA accessibility compliance (AAA where possible)
struct DesignTokens {

    // MARK: - Color Palette

    /// **Background Colors** - Deep charcoal for modern dark mode
    struct Background {
        static func primary(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "121417") : Color(hex: "FFFFFF")
        }

        static func secondary(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "1E2228") : Color(hex: "F8F9FA")
        }

        static func tertiary(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "282D36") : Color(hex: "F1F3F5")
        }

        static func elevated(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "252A33") : Color(hex: "FFFFFF")
        }
    }

    /// **Surface Colors** - Card and container backgrounds
    struct Surface {
        static func primary(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "1A1E24") : Color(hex: "F8F9FA")
        }

        static func secondary(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "22272F") : Color(hex: "F8F9FA")
        }

        static func elevated(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "2A303A") : Color(hex: "FFFFFF")
        }

        static func overlay(_ colorScheme: ColorScheme) -> Color {
            Color.black.opacity(colorScheme == .dark ? 0.7 : 0.4)
        }

        static func input(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "1A1E24") : Color(hex: "F1F3F5")
        }

        // Chat-specific surfaces
        static func chatBubbleIncoming(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "22272F") : Color(hex: "F1F3F5")
        }

        static func chatBubbleOutgoing(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "A4FC3C").opacity(0.2) : Color(hex: "A4FC3C").opacity(0.15)
        }

        // Dividers
        static func dividerSubtle(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "2A303A") : Color(hex: "E5E7EB")
        }

        static func dividerStrong(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "3A424D") : Color(hex: "9CA3AF")
        }
    }

    /// **Brand Colors** - Electric Lime + Ice Blue
    struct Brand {
        // Primary brand color - Electric Lime (Action, Energy)
        static func primary(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "A4FC3C") : Color(hex: "7DD321") // Darker lime in light mode for better contrast
        }

        // Primary pressed state
        static func primaryPressed(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "8AE025") : Color(hex: "7DD321")
        }

        // Primary hover/dark variant
        static func primaryHover(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "C8FD6D") : Color(hex: "7DD321")
        }

        // Primary disabled
        static func primaryDisabled(_ colorScheme: ColorScheme) -> Color {
            Color(hex: "A4FC3C").opacity(0.4)
        }

        // Secondary - Charcoal/Light Gray
        static func secondary(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "E5E7EB") : Color(hex: "2E3440")
        }

        // Accent - Ice Blue (highlights, badges)
        static func accent(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "7DD3FC") : Color(hex: "5FB3D3")
        }

        // Premium/VIP Badge - use accent for premium features
        static func premiumVIP(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "A4FC3C") : Color(hex: "7DD321")
        }

        // Legacy support (for gradual migration)
        static let lime = Color(hex: "A4FC3C")
        static let limeLight = Color(hex: "C8FD6D")
        static let limeDark = Color(hex: "7DD321")
        static let iceBlue = Color(hex: "5FB3D3")
        static let iceBlueDark = Color(hex: "7DD3FC")
    }

    /// **Text Colors** - High contrast for readability
    struct Text {
        static func primary(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "F9FAFB") : Color(hex: "1A1D23")
        }

        static func secondary(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "9CA3AF") : Color(hex: "6B7280")
        }

        static func tertiary(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "6B7280") : Color(hex: "9CA3AF")
        }

        static func quaternary(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "4B5563") : Color(hex: "D1D5DB")
        }

        static func accent(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "A4FC3C") : Color(hex: "059669")
        }

        static func link(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "7DD3FC") : Color(hex: "5FB3D3")
        }

        static let inverse = Color.white

        static func onColor(_ colorScheme: ColorScheme) -> Color {
            Color(hex: "1A1D23") // Dark text on colored backgrounds
        }

        static func onBrand(_ colorScheme: ColorScheme) -> Color {
            Color(hex: "1A1D23") // Dark text on lime buttons
        }
    }

    /// **Semantic Colors** - Consistent across modes
    struct Semantic {
        static func success(_ colorScheme: ColorScheme) -> Color {
            Color(hex: "10B981") // Emerald
        }

        static func error(_ colorScheme: ColorScheme) -> Color {
            Color(hex: "EF4444") // Red
        }

        static func warning(_ colorScheme: ColorScheme) -> Color {
            Color(hex: "F59E0B") // Amber
        }

        static func info(_ colorScheme: ColorScheme) -> Color {
            Color(hex: "3B82F6") // Blue
        }
    }

    /// **Gradient Colors** - Energetic and fun
    struct Gradients {
        // Primary Gradient (Lime → Lime Dark)
        static func primaryStart(_ colorScheme: ColorScheme) -> Color {
            Color(hex: "A4FC3C")
        }

        static func primaryEnd(_ colorScheme: ColorScheme) -> Color {
            Color(hex: "7DD321")
        }

        // Energetic Gradient (Lime → Ice Blue)
        static func energeticStart(_ colorScheme: ColorScheme) -> Color {
            Color(hex: "A4FC3C")
        }

        static func energeticEnd(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "7DD3FC") : Color(hex: "5FB3D3")
        }

        // Shimmer Effect (for premium badges)
        static func shimmerStart(_ colorScheme: ColorScheme) -> Color {
            Color(hex: "A4FC3C")
        }

        static func shimmerMid(_ colorScheme: ColorScheme) -> Color {
            Color(hex: "C8FD6D")
        }

        static func shimmerEnd(_ colorScheme: ColorScheme) -> Color {
            Color(hex: "A4FC3C")
        }

        // Success Gradient
        static func successStart(_ colorScheme: ColorScheme) -> Color {
            Color(hex: "10B981")
        }

        static func successEnd(_ colorScheme: ColorScheme) -> Color {
            Color(hex: "059669")
        }
    }

    /// **Special Colors** - Loading, progress, borders
    struct Special {
        static func loadingIndicator(_ colorScheme: ColorScheme) -> Color {
            Color(hex: "A4FC3C")
        }

        static func progressBarFill(_ colorScheme: ColorScheme) -> Color {
            Color(hex: "A4FC3C")
        }

        static func progressBarTrack(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "2A303A") : Color(hex: "E5E7EB")
        }

        static func borderDefault(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "2A303A") : Color(hex: "E5E7EB")
        }

        static func borderStrong(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "3A424D") : Color(hex: "9CA3AF")
        }

        static func focusRing(_ colorScheme: ColorScheme) -> Color {
            Color(hex: "A4FC3C")
        }
    }

    /// **Shadow Colors**
    struct ShadowColors {
        static func `default`(_ colorScheme: ColorScheme) -> Color {
            Color.black.opacity(colorScheme == .dark ? 0.4 : 0.1)
        }

        static func elevated(_ colorScheme: ColorScheme) -> Color {
            Color.black.opacity(colorScheme == .dark ? 0.6 : 0.15)
        }

        // Lime glow for CTA buttons
        static func primary(_ colorScheme: ColorScheme) -> Color {
            Color(hex: "A4FC3C").opacity(colorScheme == .dark ? 0.3 : 0.2)
        }
    }

    // MARK: - 📏 Spacing System (8pt Grid)

    /// **Steve Jobs Rule**: "Every pixel matters"
    struct Spacing {
        static let xs: CGFloat = 4      // Micro spacing
        static let sm: CGFloat = 8      // Small spacing
        static let md: CGFloat = 16     // Medium spacing
        static let lg: CGFloat = 24     // Large spacing
        static let xl: CGFloat = 32     // Extra large spacing
        static let xxl: CGFloat = 48    // Huge spacing
    }

    // MARK: - 🔤 Typography System

    /// **Typography Scale** - iOS native fonts, perfect hierarchy
    struct Typography {
        // Headers
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .default)
        static let title1 = Font.system(size: 28, weight: .bold, design: .default)
        static let title2 = Font.system(size: 22, weight: .bold, design: .default)
        static let title3 = Font.system(size: 20, weight: .semibold, design: .default)

        // Body
        static let headline = Font.system(size: 17, weight: .semibold, design: .default)
        static let body = Font.system(size: 17, weight: .regular, design: .default)
        static let callout = Font.system(size: 16, weight: .regular, design: .default)
        static let subheadline = Font.system(size: 15, weight: .regular, design: .default)
        static let footnote = Font.system(size: 13, weight: .regular, design: .default)
        static let caption1 = Font.system(size: 12, weight: .regular, design: .default)
        static let caption2 = Font.system(size: 11, weight: .regular, design: .default)
    }

    // MARK: - Corner Radius System

    struct CornerRadius {
        static let xs: CGFloat = 4      // Small elements
        static let sm: CGFloat = 8      // Buttons, inputs
        static let md: CGFloat = 12     // Cards
        static let lg: CGFloat = 16     // Large cards
        static let xl: CGFloat = 20     // Modals
        static let round: CGFloat = 50  // Pills, circles
    }

    // MARK: - Shadow System

    struct Shadow {
        static let none = Shadow(color: .clear, radius: 0, x: 0, y: 0)
        static let sm = Shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        static let md = Shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        static let lg = Shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        static let xl = Shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 8)

        // Lime glow shadow for CTA
        static let glow = Shadow(color: Color(hex: "A4FC3C").opacity(0.3), radius: 12, x: 0, y: 4)

        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    // MARK: - Animation System

    /// **Steve Jobs Rule**: "Animation should feel alive, not mechanical"
    struct Animation {
        // Timing curves - natural, organic
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let gentle = SwiftUI.Animation.easeInOut(duration: 0.4)
        static let spring = SwiftUI.Animation.spring(response: 0.6, dampingFraction: 0.8)
        static let bouncy = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.6)
    }

    // MARK: - Haptic System

    struct Haptics {
        private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
        private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
        private static let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
        private static let notification = UINotificationFeedbackGenerator()
        private static let selection = UISelectionFeedbackGenerator()

        static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
            let generator: UIImpactFeedbackGenerator
            switch style {
            case .light:
                generator = lightImpact
            case .medium:
                generator = mediumImpact
            case .heavy:
                generator = heavyImpact
            case .soft:
                generator = lightImpact
            case .rigid:
                generator = heavyImpact
            @unknown default:
                generator = mediumImpact
            }
            generator.prepare()
            generator.impactOccurred()
        }

        static func success() {
            notification.prepare()
            notification.notificationOccurred(.success)
        }

        static func warning() {
            notification.prepare()
            notification.notificationOccurred(.warning)
        }

        static func error() {
            notification.prepare()
            notification.notificationOccurred(.error)
        }

        static func selectionChanged() {
            selection.prepare()
            selection.selectionChanged()
        }
    }

    // MARK: - Layout Constants

    struct Layout {
        static let headerHeight: CGFloat = 56
        static let tabBarHeight: CGFloat = 83
        static let inputHeight: CGFloat = 44
        static let buttonHeight: CGFloat = 44
        static let cardMinHeight: CGFloat = 120
        static let imageAspectRatio: CGFloat = 16/9
    }
}

// MARK: - View Modifiers for Consistent Styling

extension View {
    /// Apply shadow with design tokens
    func designShadow(_ shadow: DesignTokens.Shadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }

    /// Apply haptic feedback
    func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) -> some View {
        self.onTapGesture {
            DesignTokens.Haptics.impact(style)
        }
    }

    /// Apply success haptic
    func successHaptic() -> some View {
        self.onTapGesture {
            DesignTokens.Haptics.success()
        }
    }
}
