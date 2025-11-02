//
//  DesignTokens.swift
//  BananaUniverse
//
//  Refactored with Perplexity Research Palette
//  Date: 2025-11-02
//  Theme: Premium Gold with Modern iOS Design
//

import SwiftUI

// MARK: - 🎨 DESIGN TOKENS - Perplexity Research Palette

/// **Design Philosophy**: Professional AI Image Processing Suite
/// - Premium gold for brand identity and VIP features
/// - Clean iOS-native design following Apple HIG
/// - OLED-optimized true blacks for battery efficiency
/// - WCAG AAA accessibility compliance
struct DesignTokens {

    // MARK: - 🌈 Color Palette (OLED Optimized + Theme Aware)

    /// **Background Colors** - Rich charcoal for premium dark mode (Canva-inspired)
    struct Background {
        static func primary(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "1A1A1D") : Color(hex: "FFFFFF")
        }

        static func secondary(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "27272A") : Color(hex: "F5F5F5")
        }

        static func tertiary(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "3A3A3F") : Color(hex: "EBEBEB")
        }

        static func elevated(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "52525B") : Color(hex: "FFFFFF")
        }
    }

    /// **Surface Colors** - Apple system grays for native iOS feel
    struct Surface {
        static func primary(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "1C1C1E") : Color(hex: "FFFFFF")
        }

        static func secondary(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "2C2C2E") : Color(hex: "F2F2F7")
        }

        static func elevated(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "3A3A3C") : Color(hex: "FFFFFF")
        }

        static func overlay(_ colorScheme: ColorScheme) -> Color {
            Color.black.opacity(colorScheme == .dark ? 0.75 : 0.4)
        }

        static func input(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "1C1C1E") : Color(hex: "F2F2F7")
        }

        // Chat-specific surfaces
        static func chatBubbleIncoming(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "2C2C2E") : Color(hex: "E9E9EB")
        }

        static func chatBubbleOutgoing(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "0A7AFF") : Color(hex: "007AFF")
        }

        // Dividers
        static func dividerSubtle(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "38383A") : Color(hex: "C6C6C8")
        }

        static func dividerStrong(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "48484A") : Color(hex: "8E8E93")
        }
    }

    /// **Brand Colors** - Refined purple for balanced dark mode
    struct Brand {
        // Primary brand color - Creative Purple (AI Magic) - Desaturated for harmony
        static func primary(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "9D7FD6") : Color(hex: "6B21C0")
        }

        // Secondary brand color - Electric Cyan (Digital accent)
        static func secondary(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "00E5FF") : Color(hex: "007580")
        }

        // Accent color - Warm Amber (Canva-inspired)
        static func accent(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "FFC93E") : Color(hex: "B36200")
        }

        // Premium/VIP Badge - Creative Purple (gradient anchor)
        static func premiumVIP(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "9D7FD6") : Color(hex: "6B21C0")
        }

        // Interactive states (Purple-based) - Recalculated for softer base
        static func primaryPressed(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "7D5FB0") : Color(hex: "52189C")
        }

        static func primaryHover(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "B8A5E8") : Color(hex: "8338E6")
        }

        static func primaryDisabled(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "9D7FD6").opacity(0.4) : Color(hex: "6B21C0").opacity(0.4)
        }

        // Legacy support
        static let gold = Color(hex: "F4B731")
        static let teal = Color(hex: "33C3A4")
        static let purple = Color(hex: "8B5CF6")
        static let lightBlue = Color(hex: "60A5FA")
        static let crownIcon = Color(hex: "EFBF04")
        static let vipBadge = Color(hex: "F4B731")
        static let goldShimmer = Color(hex: "FFFFFF")
    }

    /// **Text Colors** - iOS system text with perfect contrast
    struct Text {
        static func primary(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color.white : Color.black
        }

        static func secondary(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark
                ? Color(hex: "EBEBF5").opacity(0.6)
                : Color(hex: "3C3C43")  // No opacity for better contrast
        }

        static func tertiary(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark
                ? Color(hex: "EBEBF5").opacity(0.3)
                : Color(hex: "636366")  // Solid color for better contrast
        }

        static func quaternary(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark
                ? Color(hex: "EBEBF5").opacity(0.18)
                : Color(hex: "8E8E93")  // Solid color for better contrast
        }

        static func accent(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "9D7FD6") : Color(hex: "6B21C0")
        }

        static func link(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "9D7FD6") : Color(hex: "6B21C0")
        }

        static let inverse = Color.white  // For dark backgrounds

        static func onColor(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color.white : Color.black
        }

        static func onBrand(_ colorScheme: ColorScheme) -> Color {
            Color.black  // Dark text on gold buttons
        }
    }

    /// **Semantic Colors** - Context-aware with light/dark variants
    struct Semantic {
        static func success(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "34C759") : Color(hex: "28A745")
        }

        static func error(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "FF453A") : Color(hex: "DC3545")
        }

        static func warning(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "FFD60A") : Color(hex: "FFC107")
        }

        static func info(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "64D2FF") : Color(hex: "17A2B8")
        }
    }

    /// **Gradient Colors** - For premium features and paywall
    struct Gradients {
        // Premium Gradient (Purple → Cyan) - Desaturated purple in dark mode
        static func premiumStart(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "9D7FD6") : Color(hex: "6B21C0")
        }

        static func premiumEnd(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "00E5FF") : Color(hex: "007580")
        }

        // Energetic Gradient (Amber → Cyan)
        static func energeticStart(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "FFC93E") : Color(hex: "B36200")
        }

        static func energeticEnd(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "00E5FF") : Color(hex: "007580")
        }

        // Legacy: Gold Shimmer Effect (deprecated - use energetic gradient)
        static func goldShimmerStart(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "FFC93E") : Color(hex: "B36200")
        }

        static func goldShimmerMid(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "FFD85C") : Color(hex: "D67F00")
        }

        static func goldShimmerEnd(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "FFC93E") : Color(hex: "B36200")
        }

        // Success Gradient (Green → Teal)
        static func successStart(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "34C759") : Color(hex: "28A745")
        }

        static func successEnd(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "2DD4BF") : Color(hex: "14B8A6")
        }
    }

    /// **Special Colors** - Loading, progress, borders, focus
    struct Special {
        static func loadingIndicator(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "D4AF37") : Color(hex: "C19B2F")
        }

        static func progressBarFill(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "D4AF37") : Color(hex: "007AFF")
        }

        static func progressBarTrack(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "3A3A3C") : Color(hex: "E5E5EA")
        }

        static func borderDefault(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "38383A") : Color(hex: "C6C6C8")
        }

        static func borderStrong(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "48484A") : Color(hex: "8E8E93")
        }

        static func focusRing(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "0A84FF") : Color(hex: "007AFF")
        }
    }

    /// **Shadow Colors** - Depth and elevation
    struct ShadowColors {
        static func `default`(_ colorScheme: ColorScheme) -> Color {
            Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1)
        }

        static func elevated(_ colorScheme: ColorScheme) -> Color {
            Color.black.opacity(colorScheme == .dark ? 0.5 : 0.15)
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

    // MARK: - 🎭 Corner Radius System

    struct CornerRadius {
        static let xs: CGFloat = 4      // Small elements
        static let sm: CGFloat = 8      // Buttons, inputs
        static let md: CGFloat = 12     // Cards
        static let lg: CGFloat = 16     // Large cards
        static let xl: CGFloat = 20     // Modals
        static let round: CGFloat = 50  // Pills, circles
    }

    // MARK: - 🌟 Shadow System

    struct Shadow {
        static let none = Shadow(color: .clear, radius: 0, x: 0, y: 0)
        static let sm = Shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        static let md = Shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        static let lg = Shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        static let xl = Shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 8)

        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    // MARK: - ⚡ Animation System

    /// **Steve Jobs Rule**: "Animation should feel alive, not mechanical"
    struct Animation {
        // Timing curves - natural, organic
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let gentle = SwiftUI.Animation.easeInOut(duration: 0.4)
        static let spring = SwiftUI.Animation.spring(response: 0.6, dampingFraction: 0.8)
        static let bouncy = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.6)
    }

    // MARK: - 📳 Haptic System

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

    // MARK: - 📱 Layout Constants

    struct Layout {
        static let headerHeight: CGFloat = 56
        static let tabBarHeight: CGFloat = 83
        static let inputHeight: CGFloat = 44
        static let buttonHeight: CGFloat = 44
        static let cardMinHeight: CGFloat = 120
        static let imageAspectRatio: CGFloat = 16/9
    }
}

// MARK: - 🌟 View Modifiers for Consistent Styling

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
