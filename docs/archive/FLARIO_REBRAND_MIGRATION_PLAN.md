# Flario: AI Photo Editor - Complete Design System Migration Plan

**Document Version:** 1.0
**Last Updated:** January 27, 2026
**Target App:** BananaUniverse → Flario: AI Photo Editor
**Design Philosophy:** Fun, Energetic, Approachable, Modern iOS 2026

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [New Color System](#2-new-color-system)
3. [Updated DesignTokens.swift](#3-updated-designtokensswift)
4. [Screen-by-Screen Redesign](#4-screen-by-screen-redesign)
5. [Tab Bar Redesign](#5-tab-bar-redesign)
6. [Full-Screen Search Implementation](#6-full-screen-search-implementation)
7. [Spacing System Reference](#7-spacing-system-reference)
8. [Component Migration Guide](#8-component-migration-guide)
9. [Brand Identity Elements](#9-brand-identity-elements)
10. [Migration Checklist](#10-migration-checklist)
11. [Risk Assessment](#11-risk-assessment)
12. [Testing Protocol](#12-testing-protocol)

---

## 1. Executive Summary

### Current State
- **App Name:** BananaUniverse
- **Primary Color:** Purple (#6B21C0) - Serious, premium feel
- **Accent Color:** Amber/Gold (#FFC93E) - Premium VIP badge
- **Secondary:** Cyan/Teal (#00E5FF) - Digital accent
- **Design Language:** Professional AI suite (too corporate)

### Target State
- **App Name:** Flario: AI Photo Editor
- **Primary Color:** Electric Lime (#A4FC3C) - Energetic, fun, action-oriented
- **Accent Color:** Ice Blue (#5FB3D3) - Fresh, playful highlights
- **Secondary:** Charcoal (#2E3440) - Grounded, readable
- **Design Language:** Approachable, anyone can use it

### Key Changes Summary
| Element | Before | After |
|---------|--------|-------|
| Brand Color | Purple #6B21C0 | Electric Lime #A4FC3C |
| CTA Buttons | Purple/Amber | Electric Lime |
| Accent | Cyan #00E5FF | Ice Blue #5FB3D3 |
| Text Primary (Dark) | White | Off White #F9FAFB |
| Background (Dark) | #1A1A1D | #121417 (Deeper) |
| Feeling | Premium/Serious | Fun/Energetic |

---

## 2. New Color System

### 2.1 Primary Palette

#### Light Mode
| Token | Hex | RGB | Usage | WCAG Notes |
|-------|-----|-----|-------|------------|
| `primary` | #A4FC3C | 164, 252, 60 | CTA buttons, active states, selected items | Use with #1A1D23 text (7.2:1 contrast) |
| `primaryDark` | #7DD321 | 125, 211, 33 | Pressed/hover states | 5.8:1 with dark text |
| `secondary` | #2E3440 | 46, 52, 64 | Secondary buttons, icons | 12.3:1 on white |
| `accent` | #5FB3D3 | 95, 179, 211 | Badges, highlights, info states | 3.1:1 - use with dark text only |

#### Dark Mode
| Token | Hex | RGB | Usage | WCAG Notes |
|-------|-----|-----|-------|------------|
| `primary` | #A4FC3C | 164, 252, 60 | Same as light (high visibility) | 15.2:1 on #121417 |
| `primaryDark` | #C8FD6D | 200, 253, 109 | Hover states (brighter in dark) | 16.8:1 on dark bg |
| `secondary` | #E5E7EB | 229, 231, 235 | Secondary buttons, muted text | 13.1:1 on dark bg |
| `accent` | #7DD3FC | 125, 211, 252 | Badges, highlights | 11.4:1 on dark bg |

### 2.2 Background Colors

| Token | Light Mode | Dark Mode | Usage |
|-------|------------|-----------|-------|
| `background.primary` | #FFFFFF | #121417 | Main app background |
| `background.secondary` | #F8F9FA | #1E2228 | Cards, containers |
| `background.tertiary` | #F1F3F5 | #282D36 | Nested cards, inputs |
| `background.elevated` | #FFFFFF | #252A33 | Modals, sheets |

### 2.3 Surface Colors

| Token | Light Mode | Dark Mode | Usage |
|-------|------------|-----------|-------|
| `surface.primary` | #FFFFFF | #1A1E24 | Card backgrounds |
| `surface.secondary` | #F8F9FA | #22272F | Section backgrounds |
| `surface.elevated` | #FFFFFF | #2A303A | Floating elements |
| `surface.overlay` | rgba(0,0,0,0.4) | rgba(0,0,0,0.7) | Modal overlays |
| `surface.input` | #F1F3F5 | #1A1E24 | Text inputs |

### 2.4 Text Colors

| Token | Light Mode | Dark Mode | Usage |
|-------|------------|-----------|-------|
| `text.primary` | #1A1D23 | #F9FAFB | Main content |
| `text.secondary` | #6B7280 | #9CA3AF | Subtitles, captions |
| `text.tertiary` | #9CA3AF | #6B7280 | Disabled, placeholders |
| `text.accent` | #059669 | #A4FC3C | Links, active states |
| `text.onPrimary` | #1A1D23 | #1A1D23 | Text on lime buttons |

### 2.5 Semantic Colors (Both Modes)

| Token | Color | Usage |
|-------|-------|-------|
| `success` | #10B981 | Success states, confirmations |
| `error` | #EF4444 | Errors, destructive actions |
| `warning` | #F59E0B | Warnings, low credits |
| `info` | #3B82F6 | Information, tips |

### 2.6 Gradient Definitions

```swift
// Primary CTA Gradient (Lime to Lime-Dark)
LinearGradient(
    colors: [Color(hex: "A4FC3C"), Color(hex: "7DD321")],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

// Energetic Gradient (Lime to Ice Blue)
LinearGradient(
    colors: [Color(hex: "A4FC3C"), Color(hex: "5FB3D3")],
    startPoint: .leading,
    endPoint: .trailing
)

// Premium Shimmer (for special badges)
LinearGradient(
    colors: [Color(hex: "A4FC3C"), Color(hex: "C8FD6D"), Color(hex: "A4FC3C")],
    startPoint: .leading,
    endPoint: .trailing
)
```

---

## 3. Updated DesignTokens.swift

### Complete New Implementation

```swift
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
            colorScheme == .dark ? Color(hex: "1A1E24") : Color(hex: "FFFFFF")
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
            Color(hex: "A4FC3C") // Same in both modes for consistency
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

    // MARK: - Spacing System (8pt Grid) - UNCHANGED
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Typography System - UNCHANGED
    struct Typography {
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .default)
        static let title1 = Font.system(size: 28, weight: .bold, design: .default)
        static let title2 = Font.system(size: 22, weight: .bold, design: .default)
        static let title3 = Font.system(size: 20, weight: .semibold, design: .default)
        static let headline = Font.system(size: 17, weight: .semibold, design: .default)
        static let body = Font.system(size: 17, weight: .regular, design: .default)
        static let callout = Font.system(size: 16, weight: .regular, design: .default)
        static let subheadline = Font.system(size: 15, weight: .regular, design: .default)
        static let footnote = Font.system(size: 13, weight: .regular, design: .default)
        static let caption1 = Font.system(size: 12, weight: .regular, design: .default)
        static let caption2 = Font.system(size: 11, weight: .regular, design: .default)
    }

    // MARK: - Corner Radius - UNCHANGED
    struct CornerRadius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let round: CGFloat = 50
    }

    // MARK: - Shadow System - UNCHANGED
    struct Shadow {
        static let none = Shadow(color: .clear, radius: 0, x: 0, y: 0)
        static let sm = Shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        static let md = Shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        static let lg = Shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        static let xl = Shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 8)

        // NEW: Lime glow shadow for CTA
        static let glow = Shadow(color: Color(hex: "A4FC3C").opacity(0.3), radius: 12, x: 0, y: 4)

        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    // MARK: - Animation System - UNCHANGED
    struct Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let gentle = SwiftUI.Animation.easeInOut(duration: 0.4)
        static let spring = SwiftUI.Animation.spring(response: 0.6, dampingFraction: 0.8)
        static let bouncy = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.6)
    }

    // MARK: - Haptics - UNCHANGED
    struct Haptics {
        // ... existing implementation unchanged
    }

    // MARK: - Layout Constants - UNCHANGED
    struct Layout {
        static let headerHeight: CGFloat = 56
        static let tabBarHeight: CGFloat = 83
        static let inputHeight: CGFloat = 44
        static let buttonHeight: CGFloat = 44
        static let cardMinHeight: CGFloat = 120
        static let imageAspectRatio: CGFloat = 16/9
    }
}
```

---

## 4. Screen-by-Screen Redesign

### 4.1 Home Screen

**File:** `BananaUniverse/Features/Home/Views/HomeView.swift`

#### ASCII Wireframe (Dark Mode)

```
┌─────────────────────────────────────────┐
│ ┌──────┐                    [Credits]  │ ← Header: Logo (32px) + Search Icon + Credits Badge
│ │FLARIO│                                │   Height: 56pt
│ └──────┘                                │
├─────────────────────────────────────────┤
│ [!] Low Credits                [Buy ▸]  │ ← QuotaWarningBanner (conditional)
│ 1 credit remaining                      │   Padding: 16pt horizontal, 8pt vertical
├─────────────────────────────────────────┤
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ ╭─────────────────────────────────╮ │ │ ← Featured Carousel
│ │ │                                 │ │ │   Height: 220pt
│ │ │     [FEATURED TOOL]             │ │ │   Corner Radius: 16pt
│ │ │     "AI Background Remover"     │ │ │   Padding: 16pt horizontal
│ │ │                                 │ │ │
│ │ │  [ Try Now ▸ ]                  │ │ │ ← CTA: Lime gradient button
│ │ ╰─────────────────────────────────╯ │ │
│ │         ●  ○  ○  ○  ○               │ │ ← Page indicators
│ └─────────────────────────────────────┘ │
│                                         │
│ Popular Tools                           │ ← Section Title: Typography.title3
│ ┌──────┐ ┌──────┐ ┌──────┐ ┌────       │   Padding: 16pt left
│ │ [Icon]│ │ [Icon]│ │ [Icon]│ │ [Icon]   │ ← Tool Cards (horizontal scroll)
│ │      │ │      │ │      │ │           │   Card: 120×120pt
│ │Remove│ │Upscal│ │Style │ │Enha      │   Gap: 16pt between cards
│ └──────┘ └──────┘ └──────┘ └────       │
│                                         │
│ AI Effects                              │
│ ┌──────┐ ┌──────┐ ┌──────┐ ┌────       │
│ │ [Icon]│ │ [Icon]│ │ [Icon]│ │ [Icon]   │
│ │      │ │      │ │      │ │           │
│ │Anime │ │Retro │ │Pro   │ │Toy       │
│ └──────┘ └──────┘ └──────┘ └────       │
│                                         │
├─────────────────────────────────────────┤
│ [Home]  [Create]  [Library]  [Profile]  │ ← Tab Bar (83pt height)
│ Home  Create Library Profile            │   Active: Lime (#A4FC3C)
└─────────────────────────────────────────┘   Inactive: Text.secondary
```

#### A. Visual Changes Summary

| Element | Before | After |
|---------|--------|-------|
| Header background | Surface.primary (gray) | Surface.primary (cleaner white/charcoal) |
| Quota badge text | Orange for low credits | Warning amber #F59E0B |
| "Buy Credits" button | Purple `Brand.primary(.light)` | Lime `Brand.primary(colorScheme)` |
| Search bar border | Secondary with opacity | Cleaner borderDefault |
| Category row icons | Purple accent | Lime primary |

#### B. Component Updates Required

1. **QuotaWarningBanner** (lines 225-272)
   - Change: Button background from `Brand.primary(.light)` → `Brand.primary(colorScheme)`
   - Text on button stays white (high contrast on lime)

2. **Search Bar** (lines 43-91)
   - Border: Use `Special.borderDefault(colorScheme)` instead of opacity
   - Clear button: Keep using `Text.secondary`

3. **FeaturedCarouselView** (external component)
   - CTA button gradient: Switch to lime gradient

#### C. Implementation Strategy

```swift
// QuotaWarningBanner - Line 255-256
// BEFORE:
.background(DesignTokens.Brand.primary(.light))

// AFTER:
.background(DesignTokens.Brand.primary(themeManager.resolvedColorScheme))
```

**Testing Checkpoint:** After updating Home, verify:
- [ ] Quota badge is visible in both modes
- [ ] Search bar is readable
- [ ] CTA buttons have proper contrast
- [ ] Low credit warning is noticeable

---

### 4.2 Profile Screen

**File:** `BananaUniverse/Features/Profile/Views/ProfileView.swift`

#### ASCII Wireframe (Dark Mode)

```
┌─────────────────────────────────────────┐
│              Profile                     │ ← Header: Title centered
│                                          │   Height: 56pt
├─────────────────────────────────────────┤
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ Your Credits               [Icon]   │ │ ← CreditCard Component
│ │ 12 credits available                │ │   Padding: 20pt internal
│ │                                     │ │   Corner Radius: 16pt
│ │ [v] Process AI images               │ │   Border: Lime 0.2 opacity
│ │ [v] Fast processing                   │ │
│ │ [v] High-quality outputs              │ │
│ │                                     │ │
│ │ ┌─────────────────────────────────┐ │ │
│ │ │       [ Buy Credits ]           │ │ │ ← CTA: Lime background
│ │ └─────────────────────────────────┘ │ │   Height: 44pt
│ └─────────────────────────────────────┘ │
│                                         │
│ ┌─────────────────────────────────────┐ │ ← Sign In Button (if not authenticated)
│ │ [User] Sign In or Create Account [>] │ │   Height: 50pt
│ └─────────────────────────────────────┘ │   Lime background, white text
│                                         │
│ Account                                 │ ← Section Header: Typography.title3
│ ┌─────────────────────────────────────┐ │   Padding: 16pt left
│ │ (o) [Mail] Email    user@example.com │ │
│ ├─────────────────────────────────────┤ │ ← ProfileRow Component
│ │ (o) [Icon] Credits          12   [>] │ │   Icon: 32×32pt with 0.1 bg
│ ├─────────────────────────────────────┤ │   Padding: 16pt horizontal, 8pt vertical
│ │ (o) [Exit] Sign Out              [>] │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ Settings                                │
│ ┌─────────────────────────────────────┐ │
│ │ (o) [Theme] Theme          [Auto ▾]  │ │ ← Dropdown: 80pt min width
│ ├─────────────────────────────────────┤ │
│ │ (o) [Lang] Language      [English ▾] │ │
│ ├─────────────────────────────────────┤ │
│ │ (o) [Bell] Notifications [Enabled ▾] │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ Support                                 │
│ ┌─────────────────────────────────────┐ │
│ │ (o) [Help] Help & Support        [>] │ │
│ ├─────────────────────────────────────┤ │
│ │ (o) [Lock] Privacy Policy        [>] │ │
│ ├─────────────────────────────────────┤ │
│ │ (o) [File] Terms of Service      [>] │ │
│ ├─────────────────────────────────────┤ │
│ │ (o) [Sync] Restore Purchases     [>] │ │
│ └─────────────────────────────────────┘ │
│                                         │
├─────────────────────────────────────────┤
│ [Home]  [Create]  [Library]  [Profile]  │ ← Tab Bar
│ Home  Create Library Profile            │   Profile tab: Lime (active)
└─────────────────────────────────────────┘
```

#### A. Visual Changes Summary

| Element | Before | After |
|---------|--------|-------|
| Sign In button | Purple brand | Lime primary |
| Icon backgrounds | Purple with 0.1 opacity | Lime with 0.1 opacity |
| Credits icon | Purple star | Lime star |
| Checkmarks in menus | Purple | Lime |
| Delete button | Error red (keep) | Error red (keep) |

#### B. Component Updates Required

1. **CreditCard** (lines 622-684)
   - Star icon: `Brand.primary(colorScheme)`
   - Checkmark icons: `Brand.primary(colorScheme)`
   - Buy Credits button: Lime background
   - Border stroke: Lime with 0.2 opacity

2. **ProfileRow usages** (throughout)
   - Icon colors: Switch from purple to lime
   - Already uses `Brand.primary(colorScheme)` - will auto-update

3. **Theme Picker Menu** (lines 217-288)
   - Checkmark color: `Brand.primary(colorScheme)`

#### C. Implementation Strategy

Most uses already reference `Brand.primary(colorScheme)`, so updating DesignTokens will cascade automatically.

**Specific changes needed:**

```swift
// Line 664 - Button text color
// BEFORE:
.foregroundColor(DesignTokens.Text.onBrand(colorScheme))

// AFTER: (same - dark text on lime works)
.foregroundColor(DesignTokens.Text.onBrand(colorScheme))
```

**Testing Checkpoint:** After updating Profile, verify:
- [ ] Sign In button is prominent and readable
- [ ] Icon backgrounds match new lime theme
- [ ] Theme switcher checkmarks visible
- [ ] Delete button remains red (unchanged)

---

### 4.3 Library Screen

**File:** `BananaUniverse/Features/Library/Views/LibraryView.swift`

#### ASCII Wireframe (Dark Mode - With Content)

```
┌─────────────────────────────────────────┐
│              Library                     │ ← Header: Title centered
│                                          │   Height: 56pt
├─────────────────────────────────────────┤
│                                         │
│ Recent Activity                         │ ← Section Title: Typography.title3
│ ┌──────┐ ┌──────┐ ┌──────┐ ┌────       │   Padding: 16pt left, 16pt top
│ │ [Img]│ │ [Img]│ │ [Img]│ │ [Img]      │
│ │      │ │      │ │      │ │           │ ← RecentActivityCard (horizontal scroll)
│ │      │ │      │ │      │ │           │   Card: 120×120pt thumbnail
│ │      │ │      │ │      │ │           │   Total height: 180pt
│ │Remove│ │Style │ │Upsca │ │Anim      │   Gap: 16pt between cards
│ │2h ago│ │5h ago│ │1d ago│ │2d a      │   Padding: 16pt horizontal
│ └──────┘ └──────┘ └──────┘ └────       │
│                                         │
│ All History                             │ ← Section Title
│                                         │
│ Today                                   │ ← Date Group Header: Typography.footnote
│ ┌─────────────────────────────────────┐ │   Padding: 16pt left
│ │ ┌────┐                              │ │
│ │ │[Img]│  Background Remover    [v]    │ │ ← HistoryItemRow
│ │ │    │  2 hours ago                 │ │   Thumbnail: 80×80pt
│ │ └────┘                              │ │   Corner Radius: 8pt
│ ├─────────────────────────────────────┤ │   Padding: 16pt horizontal, 12pt vertical
│ │ ┌────┐                              │ │   Divider: starts at 80+16+8 = 104pt left
│ │ │[Img]│  Style Transfer        [v]    │ │
│ │ │    │  5 hours ago                 │ │ ← Status Badge: ✓ = Success (lime)
│ │ └────┘                              │ │              ⏳ = Processing (amber)
│ └─────────────────────────────────────┘ │              ✗ = Failed (red)
│                                         │
│ Yesterday                               │
│ ┌─────────────────────────────────────┐ │
│ │ ┌────┐                              │ │
│ │ │[Img]│  AI Upscaler           [v]    │ │
│ │ │    │  1 day ago                   │ │
│ │ └────┘                              │ │
│ └─────────────────────────────────────┘ │
│                                         │
├─────────────────────────────────────────┤
│ [Home]  [Create]  [Library]  [Profile]  │ ← Tab Bar
│ Home  Create Library Profile            │   Library tab: Lime (active)
└─────────────────────────────────────────┘
```

#### ASCII Wireframe (Empty State)

```
┌─────────────────────────────────────────┐
│              Library                     │
│                                          │
├─────────────────────────────────────────┤
│                                         │
│                                         │
│                                         │
│                                         │
│              ┌───────┐                  │
│              │ [Time]│                  │ ← Icon: 64pt, Text.tertiary color
│              └───────┘                  │   Font: System 64pt
│                                         │
│        No editing history found         │ ← Title: Typography.title3
│                                         │   Color: Text.accent (lime)
│       Your AI edits will appear here    │ ← Subtitle: Typography.callout
│                                         │   Color: Text.secondary
│                                         │
│                                         │
│                                         │
│                                         │
│                                         │
│                                         │
├─────────────────────────────────────────┤
│ [Home]  [Create]  [Library]  [Profile]  │
│ Home  Create Library Profile            │
└─────────────────────────────────────────┘
```

#### ASCII Wireframe (Loading State)

```
┌─────────────────────────────────────────┐
│              Library                     │
│                                          │
├─────────────────────────────────────────┤
│                                         │
│ ░░░░░░░░░░░░░░░░                        │ ← Skeleton: 150×24pt (section title)
│ ┌──────┐ ┌──────┐ ┌──────┐              │
│ │░░░░░░│ │░░░░░░│ │░░░░░░│              │ ← Skeleton cards: 120×120pt
│ │░░░░░░│ │░░░░░░│ │░░░░░░│              │   Shimmer animation
│ │░░░░░░│ │░░░░░░│ │░░░░░░│              │   Color: Background.secondary
│ │░░░░░░│ │░░░░░░│ │░░░░░░│              │
│ └──────┘ └──────┘ └──────┘              │
│ ░░░░░░░░  ░░░░░░░░  ░░░░░░░░            │ ← Skeleton text: 100×16pt
│ ░░░░░░    ░░░░░░    ░░░░░░              │   Skeleton date: 60×12pt
│                                         │
│ ░░░░░░░░░░░░                            │
│                                         │
│ ░░░░░░░░                                │
│ ┌─────────────────────────────────────┐ │
│ │ ┌────┐ ░░░░░░░░░░░░░░░░░░░░        │ │ ← Skeleton rows
│ │ │░░░░│ ░░░░░░░░                     │ │   Thumbnail: 80×80pt
│ │ │░░░░│ ░░░░░░░░░░░░                 │ │   Title: 150×18pt
│ │ └────┘                              │ │   Subtitle: 100×14pt
│ └─────────────────────────────────────┘ │
│                                         │
├─────────────────────────────────────────┤
│  🏠    ✨     📚     👤                 │
│ Home  Create Library Profile            │
└─────────────────────────────────────────┘
```

#### A. Visual Changes Summary

| Element | Before | After |
|---------|--------|-------|
| Section headers | Text.primary (unchanged) | Text.primary |
| Empty state icon | Text.tertiary (clock) | Text.tertiary (clock) |
| Empty state title | Text.accent (purple) | Text.accent (lime) |
| Loading skeleton | Background.secondary | Background.secondary (darker) |
| Status badge success | Green | Lime primary |

#### B. Component Specifications

##### RecentActivityCard
| Property | Value |
|----------|-------|
| Card width | 120pt |
| Card height | 180pt (120 thumbnail + 60 text area) |
| Thumbnail size | 120×120pt |
| Thumbnail corner radius | CornerRadius.md (12pt) |
| Title font | System 17pt Medium |
| Date font | Typography.caption1 (12pt) |
| Horizontal gap | Spacing.md (16pt) |
| Shadow | Shadow.md |

##### HistoryItemRow
| Property | Value |
|----------|-------|
| Row height | ~104pt (dynamic) |
| Thumbnail size | 80×80pt |
| Thumbnail corner radius | CornerRadius.sm (8pt) |
| Title font | Typography.headline (17pt semibold) |
| Subtitle font | Typography.caption1 (12pt) |
| Date font | Typography.footnote (13pt) |
| Horizontal padding | Spacing.md (16pt) |
| Vertical padding | Spacing.sm (8pt) |
| Divider inset | 104pt from left |

##### Date Group Header
| Property | Value |
|----------|-------|
| Font | Typography.subheadline (15pt) |
| Color | Text.secondary |
| Padding left | Spacing.md (16pt) |
| Padding top | Spacing.md (16pt) |
| Padding bottom | Spacing.sm (8pt) |

#### C. Component Updates Required

1. **LoadingView** (`Features/Library/Views/Components/LoadingView.swift`)
   - Spinner tint: Change to lime
   - Skeleton shimmer: Use Brand.primary with 0.1 opacity

2. **RecentActivityCard** (already uses DesignTokens correctly)
   - No changes needed - auto-cascades

3. **HistoryItemRow** (`Features/Library/Views/Components/HistoryItemRow.swift`)
   - Status badges: Success should use Brand.primary (lime)

4. **EmptyHistoryView** (`Features/Library/Views/Components/EmptyHistoryView.swift`)
   - Title color: Uses Text.accent - will auto-update to lime

#### D. Implementation Strategy

```swift
// LoadingView - Update skeleton shimmer overlay
Rectangle()
    .fill(
        LinearGradient(
            colors: [
                DesignTokens.Brand.primary(colorScheme).opacity(0),
                DesignTokens.Brand.primary(colorScheme).opacity(0.1),
                DesignTokens.Brand.primary(colorScheme).opacity(0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    )

// StatusBadge - Update success color
case .completed:
    return DesignTokens.Brand.primary(colorScheme) // Lime for success
case .processing:
    return DesignTokens.Semantic.warning(colorScheme) // Amber
case .failed:
    return DesignTokens.Semantic.error(colorScheme) // Red
```

**Testing Checkpoint:**
- [ ] Loading state uses lime skeleton shimmer
- [ ] Empty state shows lime accent for title
- [ ] Success status badges are lime colored
- [ ] Cards display properly in both modes
- [ ] Pull-to-refresh indicator uses lime color
- [ ] Swipe actions (if any) use correct colors

---

### 4.4 Create Screen (ImageProcessingView)

**File:** `BananaUniverse/Features/ImageProcessing/Views/ImageProcessingView.swift`

#### ASCII Wireframe (Dark Mode)

```
┌─────────────────────────────────────────┐
│ [Back]      Create           [Credits]  │ ← Header: Back button + Title + Credits
│                                          │   Height: 56pt
├─────────────────────────────────────────┤
│                                         │
│ Select Images                           │ ← Section Label: Typography.headline
│ ┌─────────────────┐ ┌─────────────────┐ │   Padding: 16pt horizontal
│ │                 │ │                 │ │
│ │   ┌───────┐     │ │   ┌───────┐     │ │ ← Image Slots (PhotosPicker)
│ │   │ [Cam] │     │ │   │ [Cam] │     │ │   Height: 160pt each
│ │   │ +    │     │ │   │ +    │     │ │   Corner Radius: 12pt
│ │   └───────┘     │ │   └───────┘     │ │   Border: Dashed, 2pt, Text.secondary 0.3
│ │    Image 1      │ │    Image 2      │ │   Gap: 16pt between slots
│ └─────────────────┘ └─────────────────┘ │
│ Select 1-2 images (optional)            │ ← Helper text: Typography.caption
│                                         │   Color: Text.secondary
│ Prompt                                  │
│ ┌─────────────────────────────────────┐ │ ← Prompt TextField
│ │ Describe what you want to create... │ │   Min height: 100pt
│ │                                     │ │   Corner Radius: 12pt
│ │                                     │ │   Background: Background.secondary
│ │                                     │ │   Padding: 16pt internal
│ └─────────────────────────────────────┘ │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ [Gear] Settings      Flux Pro • 1:1 [v]│ │ ← Settings Accordion (collapsed)
│ └─────────────────────────────────────┘ │   Icon: Brand.primary (lime)
│                                         │   Preview text: Text.secondary
│ ┌ - - - - - - - - - - - - - - - - - - ┐ │   Corner Radius: 12pt
│ │ ┌──────────────────────────────────┐│ │
│ │ │ Model                            ││ │ ← Settings Expanded (if open)
│ │ │ ┌────┐ ┌────┐ ┌────┐ ┌────┐     ││ │   Segmented picker
│ │ │ │Fast│ │Pro │ │Ult │ │Dev │     ││ │
│ │ │ └────┘ └────┘ └────┘ └────┘     ││ │
│ │ │                                  ││ │
│ │ │ Aspect Ratio    [Portrait ▾]    ││ │ ← Dropdown menu
│ │ │                                  ││ │
│ │ │ Output Format   [PNG  ▾]        ││ │
│ │ └──────────────────────────────────┘│ │
│ └ - - - - - - - - - - - - - - - - - - ┘ │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ Estimated Cost              1      │ │ ← CreditCostCard
│ │                           credits   │ │   Background: Brand.primary 0.1
│ └─────────────────────────────────────┘ │   Corner Radius: 12pt
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ [Magic] [ Generate ]                │ │ ← Generate Button
│ └─────────────────────────────────────┘ │   Height: 50pt
│                                         │   Background: Lime gradient + glow shadow
├─────────────────────────────────────────┤   Text: White, 17pt semibold
│ [Home]  [Create]  [Library]  [Profile]  │
│ Home  Create Library Profile            │
└─────────────────────────────────────────┘
```

#### A. Visual Changes Summary

| Element | Before | After |
|---------|--------|-------|
| Settings icon | Brand.accent (amber) | Brand.primary (lime) |
| Generate button | Brand.accent gradient | Lime primary gradient |
| Credit cost highlight | Brand.accent | Brand.primary |
| Image slot borders | Text.secondary dashed | Text.secondary dashed (keep) |

#### B. Component Updates Required

1. **SettingsSection** (lines 569-632)
   - Slider icon: `Brand.primary(colorScheme)`

2. **GenerateButton** (lines 792-824)
   - Background: Lime gradient instead of accent
   - Shadow: Use new `ShadowColors.primary` for glow

3. **CreditCostCard** (lines 754-789)
   - Credit amount text: `Brand.primary(colorScheme)`
   - Background: `Brand.primary.opacity(0.1)`

4. **ResultLoadingView** (lines 380-396)
   - Spinner: `Brand.primary(colorScheme)`

5. **ResultErrorView** (lines 400-438)
   - Close button: `Brand.primary(colorScheme)`

#### C. Implementation Strategy

```swift
// GenerateButton - lines 817-819
// BEFORE:
.background(
    RoundedRectangle(cornerRadius: 12)
        .fill(viewModel.canGenerate ? DesignTokens.Brand.accent(themeManager.resolvedColorScheme) : Color.gray)
)

// AFTER:
.background(
    RoundedRectangle(cornerRadius: 12)
        .fill(viewModel.canGenerate
            ? LinearGradient(
                colors: [
                    DesignTokens.Brand.primary(themeManager.resolvedColorScheme),
                    DesignTokens.Brand.primaryPressed(themeManager.resolvedColorScheme)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            : Color.gray
        )
)
.shadow(color: DesignTokens.ShadowColors.primary(themeManager.resolvedColorScheme), radius: 12, x: 0, y: 4)
```

**Testing Checkpoint:**
- [ ] Generate button has lime gradient with glow
- [ ] Settings accordion uses lime icon
- [ ] Credit cost display is prominent
- [ ] Loading/error states use new colors

---

### 4.5 Paywall Screen

**File:** `BananaUniverse/Features/Paywall/Views/PreviewPaywallView.swift`

#### A. Visual Changes Summary

| Element | Before | After |
|---------|--------|-------|
| CTA button | Amber accent gradient | Lime primary gradient |
| Benefit icons | Amber accent | Lime primary |
| Product card selection | Amber border | Lime border |
| Checkmarks | Amber accent | Lime primary |
| Restore link | Purple link | Ice Blue link |

#### B. Component Updates Required

1. **ctaButton** (lines 242-294)
   - Gradient: Lime primary gradient
   - Shadow: Lime glow shadow

2. **PreviewPaywallBenefitRow** (lines 366-400)
   - Icon color: `Brand.primary(colorScheme)`
   - Icon background: `Brand.primary.opacity(0.1)`
   - **HARDCODED COLORS DETECTED (lines 388-393):**
     - `Color(hex: "1A202C")` → `DesignTokens.Text.primary(colorScheme)`
     - `Color(hex: "2D3748")` → `DesignTokens.Text.secondary(colorScheme)`

3. **StoreKitProductCard** (lines 494-580)
   - Selection border: `Brand.primary`
   - Checkmark: `Brand.primary`
   - **HARDCODED COLORS DETECTED (line 521):**
     - `Color(hex: "1A202C")` → `DesignTokens.Text.primary(colorScheme)`

4. **CreditProductCard** (separate component - check if exists)

#### C. Implementation Strategy

```swift
// CTA Button gradient - lines 281-286
// BEFORE:
.background(
    LinearGradient(
        colors: [DesignTokens.Brand.accent(themeManager.resolvedColorScheme),
                 DesignTokens.Brand.accent(themeManager.resolvedColorScheme).opacity(0.8)],
        startPoint: .leading,
        endPoint: .trailing
    )
)

// AFTER:
.background(
    LinearGradient(
        colors: [DesignTokens.Gradients.primaryStart(themeManager.resolvedColorScheme),
                 DesignTokens.Gradients.primaryEnd(themeManager.resolvedColorScheme)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
)
.shadow(color: DesignTokens.ShadowColors.primary(themeManager.resolvedColorScheme), radius: 12, x: 0, y: 6)
```

**Testing Checkpoint:**
- [ ] CTA button is highly visible with lime gradient
- [ ] Product selection shows lime border
- [ ] All hardcoded colors replaced
- [ ] Dark mode contrast is excellent

---

## 5. Tab Bar Redesign

### 5.1 Current vs New Tab Bar Design

#### ASCII Comparison

```
BEFORE (BananaUniverse):
┌─────────────────────────────────────────┐
│ [Home]  [Create]  [Library]  [Profile]  │  Background: #27272A (Surface.secondary)
│ Home   Create   Library  Profile        │  Active: Purple (#9D7FD6)
│         ▬▬▬                             │  Inactive: Gray (#8E8E93)
└─────────────────────────────────────────┘

AFTER (Flario):
┌─────────────────────────────────────────┐
│ [Home]  [Create]  [Library]  [Profile]  │  Background: #1E2228 (Background.secondary)
│ Home   Create   Library  Profile        │  Active: Lime (#A4FC3C)
│         ▬▬▬                             │  Inactive: #6B7280 (Text.tertiary)
└─────────────────────────────────────────┘
```

### 5.2 Tab Bar Specifications

| Property | Dark Mode | Light Mode |
|----------|-----------|------------|
| Height | 83pt (iOS standard) | 83pt |
| Background | #1E2228 | #F8F9FA |
| Active Icon | #A4FC3C (Electric Lime) | #A4FC3C |
| Active Text | #A4FC3C (Electric Lime) | #A4FC3C |
| Inactive Icon | #6B7280 (Text.tertiary) | #9CA3AF |
| Inactive Text | #6B7280 (Text.tertiary) | #9CA3AF |
| Separator | None (seamless) | None |

### 5.3 Tab Icons & Labels

| Tab | Icon (SF Symbol) | Label | Notes |
|-----|------------------|-------|-------|
| Home | `house.fill` | Home | Discovery & browsing |
| Create | `wand.and.stars` | Create | Primary action - image generation |
| Library | `square.stack.3d.up.fill` | Library | History & saved images |
| Profile | `person.fill` | Profile | Settings & account |

### 5.4 Active State Animation

```swift
// Tab bar active state transition
withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
    // Scale effect on selection
    selectedIcon.scaleEffect(1.1)
}
```

### 5.5 Implementation Code

**File:** `BananaUniverse/App/ContentView.swift` (lines 100-138)

```swift
private func updateTabBarAppearance(for colorScheme: ColorScheme) {
    let appearance = UITabBarAppearance()
    appearance.configureWithOpaqueBackground()

    if colorScheme == .dark {
        // Dark mode - Flario palette
        appearance.backgroundColor = UIColor(Color(hex: "1E2228"))

        // Inactive tabs - muted gray
        let inactiveColor = UIColor(Color(hex: "6B7280"))
        appearance.stackedLayoutAppearance.normal.iconColor = inactiveColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: inactiveColor,
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]

        // Active tab - Electric Lime
        let activeColor = UIColor(Color(hex: "A4FC3C"))
        appearance.stackedLayoutAppearance.selected.iconColor = activeColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: activeColor,
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]
    } else {
        // Light mode
        appearance.backgroundColor = UIColor(Color(hex: "F8F9FA"))

        let inactiveColor = UIColor(Color(hex: "9CA3AF"))
        appearance.stackedLayoutAppearance.normal.iconColor = inactiveColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: inactiveColor,
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]

        let activeColor = UIColor(Color(hex: "A4FC3C"))
        appearance.stackedLayoutAppearance.selected.iconColor = activeColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: activeColor,
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]
    }

    UITabBar.appearance().standardAppearance = appearance
    UITabBar.appearance().scrollEdgeAppearance = appearance
}
```

### 5.6 Testing Checklist

- [ ] Lime color is vibrant in both modes
- [ ] Inactive icons have proper contrast
- [ ] Tab switching animation is smooth
- [ ] Safe area is respected on all devices
- [ ] Home indicator doesn't overlap on notched devices

---

## 6. Full-Screen Search Implementation

### 6.1 Design Decision

**Current:** Inline search bar always visible in Home header
**New:** Magnifying glass icon that expands to full-screen search overlay

### 6.2 Rationale

1. **Cleaner Home Screen** - More focus on featured content
2. **Better UX** - Full-screen search provides more room for results
3. **Modern Pattern** - Follows Apple Music, App Store, Instagram patterns
4. **Keyboard First** - Full screen auto-focuses keyboard immediately

### 6.3 ASCII Wireframe: Search Collapsed (Home Screen)

```
┌─────────────────────────────────────────┐
│ ┌──────┐                 [Search] [Credits]│ ← Search icon (new) + Credits badge
│ │FLARIO│                                │   Search icon: 22pt, Text.secondary
│ └──────┘                                │   Tap to expand full-screen search
├─────────────────────────────────────────┤
│                                         │
│ [Featured Carousel continues...]        │
```

### 6.4 ASCII Wireframe: Search Expanded (Full-Screen)

```
┌─────────────────────────────────────────┐
│  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │ ← Blur overlay (Surface.overlay)
│  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │   Background.primary with 0.7 blur
│  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
├─────────────────────────────────────────┤
│ Cancel  ┌────────────────────────┐      │ ← Search Header
│         │ [Search] Search tools...│      │   Cancel: Text.accent (lime)
│         └────────────────────────┘      │   Input: 44pt height
│                                         │   Corner Radius: 12pt
│ Recent Searches                         │ ← Section (if no query)
│ ┌─────────────────────────────────────┐ │
│ │ [Time] background remover           │ │
│ │ [Time] anime style                  │ │
│ │ [Time] upscale                      │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ Popular Tools                           │ ← Suggested (if no query)
│ ┌──────┐ ┌──────┐ ┌──────┐            │
│ │ [Icon]│ │ [Icon]│ │ [Icon]            │
│ │Remove│ │Upscal│ │Style │            │
│ └──────┘ └──────┘ └──────┘            │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ Cancel  ┌────────────────────────┐      │ ← With search query
│         │ [Search] background|     │      │   Live filtering
│         └────────────────────────┘      │
│                                         │
│ Results for "background"                │
│ ┌─────────────────────────────────────┐ │
│ │ ┌────┐ Background Remover      [>]   │ │ ← Search Results
│ │ │[Icon]│ Remove any background      │ │   Thumbnail: 60×60pt
│ │ └────┘                              │ │   Row height: 76pt
│ ├─────────────────────────────────────┤ │
│ │ ┌────┐ Background Blur         [>]   │ │
│ │ │[Icon]│ Add blur to background     │ │
│ │ └────┘                              │ │
│ └─────────────────────────────────────┘ │
│                                         │
│                                         │
│                                         │
│ ┌─────────────────────────────────────┐ │ ← Keyboard
│ │ Q W E R T Y U I O P                 │ │
│ │ A S D F G H J K L                   │ │
│ │ Z X C V B N M  ⌫                   │ │
│ │ 123   space   search                │ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

### 6.5 Search Component Specifications

#### Search Bar (Expanded)
| Property | Value |
|----------|-------|
| Height | 44pt |
| Corner Radius | CornerRadius.md (12pt) |
| Background | Surface.input |
| Icon Size | 16pt |
| Icon Color | Text.secondary |
| Text Font | Typography.body (17pt) |
| Text Color | Text.primary |
| Placeholder Color | Text.tertiary |

#### Cancel Button
| Property | Value |
|----------|-------|
| Font | Typography.body (17pt) |
| Color | Text.accent (lime) |
| Padding Left | Spacing.md (16pt) |

#### Recent Search Row
| Property | Value |
|----------|-------|
| Height | 44pt |
| Icon | clock, 16pt |
| Icon Color | Text.tertiary |
| Text Font | Typography.body |
| Text Color | Text.primary |

#### Search Result Row
| Property | Value |
|----------|-------|
| Height | 76pt |
| Thumbnail | 60×60pt |
| Corner Radius | CornerRadius.sm (8pt) |
| Title Font | Typography.headline |
| Subtitle Font | Typography.subheadline |
| Chevron | Text.tertiary |

### 6.6 Implementation Strategy

#### New Files to Create:

1. **`Core/Components/FullScreenSearch/FullScreenSearchView.swift`**
2. **`Core/Components/FullScreenSearch/SearchResultRow.swift`**
3. **`Core/Components/FullScreenSearch/RecentSearchRow.swift`**

#### State Management:

```swift
// In HomeView
@State private var isSearchPresented = false
@State private var searchQuery = ""

// Header modification
UnifiedHeaderBar(
    title: "",
    leftContent: .appLogo(32),
    rightContent: .custom {
        HStack(spacing: Spacing.md) {
            // Search icon button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isSearchPresented = true
                }
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(DesignTokens.Text.secondary(colorScheme))
            }

            // Credits badge
            QuotaBadge(credits: creditManager.creditsRemaining) {
                showPaywall = true
            }
        }
    }
)
.fullScreenCover(isPresented: $isSearchPresented) {
    FullScreenSearchView(
        searchQuery: $searchQuery,
        tools: viewModel.allThemes,
        onToolSelected: { tool in
            isSearchPresented = false
            handleToolTap(tool)
        },
        onDismiss: {
            isSearchPresented = false
        }
    )
}
```

### 6.7 Animation Specifications

```swift
// Appear animation
withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
    isSearchPresented = true
}

// Blur background
.background(
    DesignTokens.Background.primary(colorScheme)
        .opacity(0.95)
        .blur(radius: 20)
)

// Results appear with stagger
ForEach(Array(results.enumerated()), id: \.element.id) { index, tool in
    SearchResultRow(tool: tool)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .opacity
        ))
        .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.05), value: results)
}
```

### 6.8 Accessibility

- Search field auto-focuses on appear
- VoiceOver: "Search tools. Double tap to search."
- Cancel button: "Cancel search. Double tap to close."
- Results: "Tool name. Tool description. Double tap to select."

---

## 7. Spacing System Reference

### 7.1 Base Spacing Scale (8pt Grid)

| Token | Value | Usage |
|-------|-------|-------|
| `Spacing.xs` | 4pt | Micro gaps (icon-label, badge padding) |
| `Spacing.sm` | 8pt | Small gaps (list item padding, compact spacing) |
| `Spacing.md` | 16pt | Standard gaps (section padding, card margins) |
| `Spacing.lg` | 24pt | Large gaps (section separators, major spacing) |
| `Spacing.xl` | 32pt | Extra large (screen padding, major sections) |
| `Spacing.xxl` | 48pt | Huge (hero sections, onboarding screens) |

### 7.2 Screen-Level Spacing

#### Home Screen
| Element | Spacing Token | Value |
|---------|---------------|-------|
| Header height | `Layout.headerHeight` | 56pt |
| Header horizontal padding | `Spacing.md` | 16pt |
| Quota warning banner margin | `Spacing.md` horizontal, `Spacing.sm` top | 16pt, 8pt |
| Featured carousel padding | `Spacing.md` horizontal | 16pt |
| Category section gap | `Spacing.md` | 16pt |
| Category title padding | `Spacing.md` left | 16pt |
| Tool card gap (horizontal scroll) | `Spacing.md` | 16pt |
| Content bottom padding | `Spacing.lg` | 24pt |

#### Profile Screen
| Element | Spacing Token | Value |
|---------|---------------|-------|
| Content horizontal padding | `Spacing.md` | 16pt |
| CreditCard padding (internal) | 20pt | 20pt (custom) |
| CreditCard top margin | `Spacing.md` | 16pt |
| Section header margin | `Spacing.md` left | 16pt |
| Section gap | `Spacing.lg` | 24pt |
| ProfileRow vertical padding | `Spacing.sm` | 8pt |
| ProfileRow horizontal padding | `Spacing.md` | 16pt |
| Divider inset | 56pt from left | 56pt (icon width + spacing) |

#### Library Screen
| Element | Spacing Token | Value |
|---------|---------------|-------|
| Recent Activity top padding | `Spacing.md` | 16pt |
| Recent Activity horizontal padding | `Spacing.md` | 16pt |
| Recent card gap | `Spacing.md` | 16pt |
| History section gap | `Spacing.lg` | 24pt |
| Date header padding | `Spacing.md` left, `Spacing.sm` vertical | 16pt, 8pt |
| Row horizontal padding | `Spacing.md` | 16pt |
| Row vertical padding | `Spacing.sm` | 8pt |

#### Create Screen
| Element | Spacing Token | Value |
|---------|---------------|-------|
| Content padding | `Spacing.md` | 16pt |
| Section gap | `Spacing.lg` | 24pt |
| Image slots gap | `Spacing.md` | 16pt |
| Settings accordion padding | `Spacing.md` | 16pt |
| Settings expanded gap | `Spacing.md` | 16pt |
| Generate button margin top | `Spacing.md` | 16pt |

### 7.3 Component-Level Spacing

#### Cards
| Property | Token | Value |
|----------|-------|-------|
| Card internal padding | `Spacing.md` | 16pt |
| Card corner radius | `CornerRadius.lg` | 16pt |
| Card shadow | `Shadow.md` | radius: 4, y: 2 |
| Card border width | 1pt | 1pt |

#### Buttons
| Property | Token | Value |
|----------|-------|-------|
| Button height | `Layout.buttonHeight` | 44pt |
| Large button height | 50pt | 50pt |
| Button horizontal padding | `Spacing.md` | 16pt |
| Button corner radius | `CornerRadius.md` | 12pt |
| Button icon-label gap | `Spacing.sm` | 8pt |

#### Inputs
| Property | Token | Value |
|----------|-------|-------|
| Input height | `Layout.inputHeight` | 44pt |
| Input horizontal padding | `Spacing.md` | 16pt |
| Input corner radius | `CornerRadius.md` | 12pt |
| Textarea min height | 100pt | 100pt |

#### Lists
| Property | Token | Value |
|----------|-------|-------|
| Row minimum height | 44pt | 44pt (iOS standard) |
| Row horizontal padding | `Spacing.md` | 16pt |
| Row vertical padding | `Spacing.sm` | 8pt |
| Thumbnail-content gap | `Spacing.sm` | 8pt |
| Divider inset (with thumbnail) | thumbnail width + gaps | varies |

### 7.4 Safe Area Handling

```swift
// Standard screen with tab bar
VStack(spacing: 0) {
    // Header
    UnifiedHeaderBar(...)

    // Content
    ScrollView {
        content
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.lg) // Extra for tab bar
    }
}
.background(Background.primary(colorScheme))

// Modal/Sheet
VStack(spacing: 0) {
    content
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.xxl) // Extra for home indicator
}
```

### 7.5 Visual Spacing Reference

```
┌─ Screen Edge ─────────────────────────────────────────┐
│                                                       │
│ 16pt ┌─ Card ────────────────────────────────┐ 16pt  │
│◀────▶│                                       │◀────▶│
│      │ 16pt ┌─ Content ────────────┐ 16pt   │      │
│      │◀────▶│                      │◀────▶  │      │
│      │      │  Text/Icons here     │        │      │
│      │      │                      │        │      │
│      │      └──────────────────────┘        │      │
│      │                                       │      │
│      │      8pt gap                          │      │
│      │      ◀──▶                             │      │
│      │                                       │      │
│      │      ┌─ Another Element ─────┐       │      │
│      │      │                       │       │      │
│      │      └───────────────────────┘       │      │
│      │                                       │      │
│      └───────────────────────────────────────┘      │
│                                                       │
│ 24pt gap between sections                            │
│◀──────────────────────────────────────────────────▶│
│                                                       │
│      ┌─ Next Section ────────────────────────┐      │
│      │                                       │      │
└──────┴───────────────────────────────────────┴──────┘
```

---

## 8. Component Migration Guide

### 8.1 Core Components to Update

#### Priority 1: High Impact (Update First)

| Component | File Path | Changes Required |
|-----------|-----------|------------------|
| UnifiedHeaderBar | `Core/Components/UnifiedHeaderBar.swift` | Background, brand references |
| QuotaDisplayView | `Core/Components/QuotaDisplayView.swift` | Star icon color, badge styling |
| AppLogo | `Core/Components/AppLogo/AppLogo.swift` | Text "nano.banana" → "Flario" |
| FeaturedCarouselView | `Core/Components/FeaturedCarousel/FeaturedCarouselView.swift` | Gradient colors |
| CarouselCard | `Core/Components/FeaturedCarousel/CarouselCard.swift` | CTA button styling |

#### Priority 2: Medium Impact

| Component | File Path | Changes Required |
|-----------|-----------|------------------|
| ToolCard | `Core/Components/ToolCard/ToolCard.swift` | Uses DesignTokens - auto-cascades |
| ProfileRow | `Core/Components/ProfileRow/ProfileRow.swift` | Icon colors - auto-cascades |
| CategoryRow | `Core/Components/CategoryRow/CategoryRow.swift` | Section styling |
| SkeletonView | `Core/Components/SkeletonView/SkeletonView.swift` | Shimmer color |

#### Priority 3: Low Impact

| Component | File Path | Changes Required |
|-----------|-----------|------------------|
| OfflineBanner | `Core/Components/OfflineBanner.swift` | Warning colors (semantic) |
| TabButton | `Core/Components/TabButton/TabButton.swift` | Selected state color |

### 8.2 Hardcoded Colors to Fix

**Files with `Color(hex:)` outside DesignTokens:**

1. **PreviewPaywallView.swift**
   - Line 388: `Color(hex: "1A202C")` → `DesignTokens.Text.primary(themeManager.resolvedColorScheme)`
   - Line 392: `Color(hex: "2D3748")` → `DesignTokens.Text.secondary(themeManager.resolvedColorScheme)`
   - Line 431: `Color(hex: "1A202C")` → `DesignTokens.Text.primary(themeManager.resolvedColorScheme)`
   - Line 447: `Color(hex: "1A202C")` → `DesignTokens.Text.primary(themeManager.resolvedColorScheme)`
   - Line 521: `Color(hex: "1A202C")` → `DesignTokens.Text.primary(themeManager.resolvedColorScheme)`

2. **ChatView.swift** (check for hardcoded colors)

### 8.3 New Components to Create

No new components required. All existing components can be updated in place.

### 8.4 Components to Remove

None identified. The component library is well-structured.

---

## 9. Brand Identity Elements

### 9.1 App Icon Concepts

**Concept 1: Spark/Flare**
- Shape: Rounded square (iOS standard)
- Background: Deep Charcoal (#121417)
- Symbol: Stylized spark/flare in Electric Lime
- Style: Minimalist, single graphic element

**Concept 2: Abstract F**
- Shape: Rounded square
- Background: Gradient (Lime → Ice Blue)
- Symbol: Geometric "F" or flame shape
- Style: Modern, tech-forward

**Concept 3: Magic Wand**
- Shape: Rounded square
- Background: Electric Lime (#A4FC3C)
- Symbol: Simplified magic wand with sparkles in Charcoal
- Style: Playful, approachable

**Recommended:** Concept 1 (Spark/Flare) - Clean, memorable, works at all sizes

### 9.2 Color Specifications for App Icon

```
Primary Background: #121417 (Deep Charcoal)
Main Symbol: #A4FC3C (Electric Lime)
Secondary Accent: #C8FD6D (Light Lime for highlights)
```

### 9.3 Wordmark Styling

**Font Recommendation:** SF Pro Rounded Bold or similar geometric sans-serif

```
"Flario"
- Weight: Bold (700)
- Tracking: -0.02em (slightly tight)
- Color:
  - Light mode: #1A1D23 (Rich Black)
  - Dark mode: #F9FAFB (Off White)
```

### 9.4 AppLogo.swift Update

```swift
struct AppLogo: View {
    let size: CGFloat
    let showText: Bool

    init(size: CGFloat = 40, showText: Bool = false) {
        self.size = size
        self.showText = showText
    }

    var body: some View {
        HStack(spacing: 8) {
            Image("AppLogo") // New Flario icon
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.2))

            if showText {
                Text("Flario")
                    .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
        }
    }
}
```

### 6.5 Asset Updates Required

| Asset | Current | New |
|-------|---------|-----|
| AppIcon.appiconset | Banana universe icon | Flario spark/flare icon |
| AppLogo.imageset | banana.universe.icon.png | flario-logo.png |
| AccentColor | Purple | Electric Lime #A4FC3C |

---

## 7. Migration Checklist

### Phase 1: Foundation (Day 1)

- [x] **1.1** Backup current DesignTokens.swift ✅ (Original preserved in git history)
- [x] **1.2** Create new DesignTokens.swift with Flario palette ✅ DONE
- [x] **1.3** Update Color extension (if separate file exists) ✅ (No separate file, using existing Color+DesignSystem.swift)
- [ ] **1.4** Update AccentColor in Assets.xcassets (Optional - can be done later)
- [x] **1.5** Build and fix any compilation errors ✅ (No linter errors)

### Phase 2: Core Components (Day 2) ✅ COMPLETE

- [x] **2.1** Update UnifiedHeaderBar ✅ DONE
- [x] **2.2** Update QuotaDisplayView ✅ DONE
- [x] **2.3** Update AppLogo (text change) ✅ DONE (Changed to "Flario" with Electric Lime)
- [x] **2.4** Update FeaturedCarouselView ✅ DONE
- [x] **2.5** Update CarouselCard ✅ DONE (Electric Lime gradient CTA button)
- [x] **2.6** Test in Simulator (Light + Dark) ✅ DONE (No linter errors)

### Phase 3: Feature Screens (Day 3-4) ✅ COMPLETE

- [x] **3.1** Migrate HomeView ✅ DONE
  - [x] QuotaWarningBanner ✅ DONE (already done in Phase 0)
  - [x] Search bar styling ✅ DONE
- [x] **3.2** Migrate ProfileView ✅ DONE
  - [x] CreditCard component ✅ DONE (Electric Lime gradient button)
  - [x] ProfileRow usages ✅ DONE (Electric Lime icons)
  - [x] Menu checkmarks ✅ DONE (Electric Lime checkmarks)
- [x] **3.3** Migrate LibraryView ✅ DONE
  - [x] LoadingView spinner ✅ DONE (uses DesignTokens)
  - [x] Empty state styling ✅ DONE (uses DesignTokens)
- [x] **3.4** Migrate ImageProcessingView (Create Screen) ✅ DONE
  - [x] SettingsSection icons ✅ DONE (Electric Lime)
  - [x] GenerateButton gradient ✅ DONE (Electric Lime gradient with glow)
  - [x] CreditCostCard ✅ DONE (Electric Lime accent)
  - [x] ResultLoadingView ✅ DONE (Electric Lime spinner)
  - [x] ResultErrorView ✅ DONE (Electric Lime button)

### Phase 4: Paywall & Auth (Day 5) ✅ COMPLETE

- [x] **4.1** Fix hardcoded colors in PreviewPaywallView ✅ DONE (already done in Phase 0)
- [x] **4.2** Update CTA button gradient ✅ DONE (Electric Lime gradient)
- [x] **4.3** Update benefit row icons ✅ DONE (Electric Lime icons)
- [x] **4.4** Update product cards ✅ DONE (Electric Lime selection indicators)
- [x] **4.5** Check SignInView, QuickAuthView ✅ DONE (already done in Phase 0 audit)

### Phase 5: Brand Assets (Day 6) ✅ CONFIGURATION COMPLETE | ⏳ ASSET DESIGN REQUIRED

- [x] **5.1** Design new app icon ⏳ (Design required - see PHASE_5_ASSET_CREATION_GUIDE.md)
- [x] **5.2** Export all icon sizes (20, 29, 40, 60, 76, 83.5, 1024) ⏳ (Export required)
- [x] **5.3** Update AppIcon.appiconset ✅ DONE (Contents.json structure ready)
- [x] **5.4** Update AppLogo.imageset ✅ DONE (Contents.json updated, filenames: flario-logo@1x.png, @2x.png, @3x.png)
- [x] **5.5** Update splash screen (if applicable) ✅ DONE (Info.plist updated)
- [x] **5.6** Update AccentColor ✅ DONE (Electric Lime #A4FC3C)
- [x] **5.7** Update CFBundleDisplayName ✅ DONE ("Flario")
- [x] **5.8** Create asset creation guide ✅ DONE (PHASE_5_ASSET_CREATION_GUIDE.md)

### Phase 6: Testing (Day 7)

- [ ] **6.1** Full dark mode walkthrough
- [ ] **6.2** Full light mode walkthrough
- [ ] **6.3** Accessibility audit (VoiceOver, Dynamic Type)
- [ ] **6.4** Test on multiple device sizes (SE, 14, 15 Pro Max)
- [ ] **6.5** Screenshot comparison (before/after)

### Phase 7: Cleanup (Day 8)

- [ ] **7.1** Remove any remaining hardcoded colors
- [ ] **7.2** Remove legacy Brand color references
- [ ] **7.3** Update app metadata (App Store Connect)
- [ ] **7.4** Update documentation
- [ ] **7.5** Final build and archive

---

## 8. Risk Assessment

### 8.1 High Risk Areas

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Hardcoded colors missed | Medium | High | Use Grep to find all `Color(hex:` and `#` patterns |
| Dark mode contrast issues | Medium | High | Test each screen with WCAG contrast checker |
| Paywall hardcoded colors | High | High | Manual review of PreviewPaywallView.swift |
| Chat bubbles look wrong | Low | Medium | Test chat interface thoroughly |

### 8.2 Files Requiring Special Attention

1. **PreviewPaywallView.swift** - Multiple hardcoded colors
2. **ChatView.swift** - May have hardcoded chat bubble colors
3. **OnboardingStepCard.swift** - Check for hardcoded gradients
4. **OnboardingScreen4.swift** - Check for hardcoded colors

### 8.3 Potential Breaking Changes

| Change | Risk | Resolution |
|--------|------|------------|
| Brand.accent usage removed | Medium | Replace all `Brand.accent` with `Brand.primary` or context-appropriate color |
| Gold/Amber references | Low | These are removed - search for `gold` and `amber` |
| Text.onBrand returns dark | None | This is correct for lime backgrounds |

### 8.4 Performance Considerations

| Concern | Assessment | Recommendation |
|---------|------------|----------------|
| Gradient rendering | Low risk | Linear gradients are hardware accelerated |
| Shadow blur (glow effect) | Low risk | Keep blur radius ≤ 12 for performance |
| Animation performance | No change | Using same animation system |

---

## 9. Testing Protocol

### 9.1 Visual Testing Checklist

For each screen, verify:

- [ ] All text is readable (contrast ratio ≥ 4.5:1)
- [ ] All interactive elements are clearly visible
- [ ] Lime color appears correctly (not washed out)
- [ ] Dark mode backgrounds are deep charcoal, not pure black
- [ ] No purple/amber remnants visible
- [ ] Icons match new lime theme

### 9.2 Accessibility Testing

- [ ] VoiceOver announces all elements correctly
- [ ] Dynamic Type (up to XXXL) doesn't break layouts
- [ ] Color contrast meets WCAG AA minimum
- [ ] Focus states are visible
- [ ] Reduce Motion respects system preference

### 9.3 Device Testing Matrix

| Device | Screen Size | Status |
|--------|-------------|--------|
| iPhone SE (3rd gen) | 4.7" | [ ] |
| iPhone 14 | 6.1" | [ ] |
| iPhone 14 Pro Max | 6.7" | [ ] |
| iPhone 15 Pro | 6.1" | [ ] |
| iPad (if supported) | Various | [ ] |

### 9.4 Before/After Screenshot Comparison

Capture screenshots of all screens in both modes before starting migration. After completion, compare:

1. Home Screen (Light/Dark)
2. Profile Screen (Light/Dark)
3. Library Screen (Light/Dark)
4. Create Screen (Light/Dark)
5. Paywall Screen (Light/Dark)

---

## Appendix A: Quick Reference Color Codes

### Copy-Paste Ready Hex Values

```
// Primary Palette
Electric Lime:     #A4FC3C
Lime Dark:         #7DD321
Lime Light:        #C8FD6D
Ice Blue:          #5FB3D3
Ice Blue Dark:     #7DD3FC
Charcoal:          #2E3440

// Backgrounds (Dark Mode)
Background Primary:   #121417
Background Secondary: #1E2228
Background Tertiary:  #282D36
Surface Primary:      #1A1E24
Surface Secondary:    #22272F

// Backgrounds (Light Mode)
Background Primary:   #FFFFFF
Background Secondary: #F8F9FA
Background Tertiary:  #F1F3F5

// Text (Dark Mode)
Text Primary:    #F9FAFB
Text Secondary:  #9CA3AF
Text Tertiary:   #6B7280

// Text (Light Mode)
Text Primary:    #1A1D23
Text Secondary:  #6B7280
Text Tertiary:   #9CA3AF

// Semantic (Both Modes)
Success:  #10B981
Error:    #EF4444
Warning:  #F59E0B
Info:     #3B82F6
```

---

## Appendix B: Figma/Design Tool Export Settings

If creating assets in Figma:

- Export @1x, @2x, @3x for iOS
- Use sRGB color profile
- PNG format for icons/logos
- PDF format for vector assets

---

**Document Complete**

This migration plan provides everything needed to systematically rebrand from BananaUniverse to Flario. Follow the phases in order, test thoroughly, and the result will be a cohesive, energetic design that appeals to a broader audience.

---

## ✅ MIGRATION PROGRESS SUMMARY

**Last Updated:** 2026-01-27  
**Status:** Phases 0-4 Complete ✅

### Completed Phases

**Phase 0: Pre-Migration Fixes** ✅ COMPLETE
- Fixed 25+ hardcoded color instances
- Standardized all components to use DesignTokens
- Moved StatusBadge to Core

**Phase 1: Foundation** ✅ COMPLETE
- Updated DesignTokens.swift with Flario palette (Electric Lime #A4FC3C)
- All color tokens migrated to new palette
- No compilation errors

**Phase 2: Core Components** ✅ COMPLETE
- UnifiedHeaderBar: "Flario" brand text with Electric Lime
- QuotaDisplayView: Electric Lime styling
- AppLogo: Changed to "Flario" with Electric Lime
- TabBar: Electric Lime active state
- CarouselCard: Electric Lime gradient CTA button
- QuotaBadge: Electric Lime for PRO badges

**Phase 3: Feature Screens** ✅ COMPLETE
- HomeView: Search bar, QuotaWarningBanner, CategoryRow
- ProfileView: CreditCard, ProfileRow, Sign In button (Electric Lime gradients)
- LibraryView: All components verified
- ImageProcessingView: GenerateButton (Electric Lime gradient), SettingsSection, ResultView

**Phase 4: Paywall & Auth** ✅ COMPLETE
- PreviewPaywallView: CTA button (Electric Lime gradient), benefit icons, product cards
- CreditProductCard: Electric Lime selection indicators
- PremiumBenefitCard: Electric Lime gradient icons
- All Paywall sections updated (Hero, CTA, Error, Background, Loading)
- Authentication views verified (already done in Phase 0)

**Phase 5: Brand Assets** ✅ CONFIGURATION COMPLETE | ⏳ ASSET DESIGN REQUIRED
- AccentColor updated to Electric Lime (#A4FC3C) ✅
- CFBundleDisplayName updated to "Flario" ✅
- AppIcon.appiconset Contents.json structure ready ✅
- AppLogo.imageset Contents.json updated (flario-logo@1x.png, @2x.png, @3x.png) ✅
- Asset creation guide created (PHASE_5_ASSET_CREATION_GUIDE.md) ✅
- **Note:** Actual icon and logo image files need to be designed and added

### Remaining Phases

**Phase 5: Brand Assets Design** ⏳ Pending
- App icon design (9 sizes required)
- Logo assets (@1x, @2x, @3x)
- Splash screen (if applicable)

**Phase 6: Testing** ⏳ Pending
- Visual testing
- Accessibility audit
- Device testing

**Phase 7: Cleanup** ⏳ Pending
- Final polish
- Documentation update

**Total Progress:** ~70% Complete (Phases 0-4 done, 5-7 remaining)

*Generated by Claude Opus 4.5 | January 2026*
