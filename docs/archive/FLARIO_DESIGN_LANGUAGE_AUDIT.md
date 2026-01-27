# Flario App - Design Language Audit

**Date:** 2026-01-27
**Version:** 1.0
**Prepared for:** Onboarding Redesign Initiative

---

## Executive Summary

Flario is a **fun, energetic AI photo editor** with a bold Electric Lime + Charcoal color palette. The design language prioritizes approachability, modern iOS aesthetics, and OLED optimization. The brand personality is playful yet professional, targeting creative users who want quick, viral-worthy content. The design system is comprehensive and well-documented in `DesignTokens.swift`.

---

## Brand Identity

| Attribute | Description |
|-----------|-------------|
| **Personality** | Fun, Energetic, Approachable, Modern |
| **Target Audience** | Creative users (18-45), social media enthusiasts, content creators |
| **Core Value** | Transform photos into viral content in seconds |
| **Emotional Goal** | Excitement, empowerment, instant gratification |
| **Tagline Vibe** | "AI magic at your fingertips" |

### Brand Pillars
1. **Speed** - Quick transformations, fast processing
2. **Fun** - Playful effects, engaging interactions
3. **Quality** - Professional outputs, AI-powered precision
4. **Accessibility** - Credit-based model, no subscriptions

---

## Color System

### Primary Brand Colors

| Token | Light Mode | Dark Mode | Usage | Psychology |
|-------|-----------|-----------|-------|-----------|
| `Brand.primary` | `#7DD321` (Darker Lime) | `#A4FC3C` (Electric Lime) | CTAs, active states, progress | Energy, action, growth |
| `Brand.secondary` | `#2E3440` (Charcoal) | `#E5E7EB` (Light Gray) | Secondary elements, text | Stability, professionalism |
| `Brand.accent` | `#5FB3D3` (Ice Blue) | `#7DD3FC` (Ice Blue Light) | Highlights, badges, links | Trust, calm, premium |
| `Brand.lime` (legacy) | `#A4FC3C` | `#A4FC3C` | Static lime reference | - |

### Background Colors

| Token | Light Mode | Dark Mode | Usage |
|-------|-----------|-----------|-------|
| `Background.primary` | `#FFFFFF` | `#121417` (Deep Charcoal) | Main screen backgrounds |
| `Background.secondary` | `#F8F9FA` | `#1E2228` | Cards, sections |
| `Background.tertiary` | `#F1F3F5` | `#282D36` | Nested elements |
| `Background.elevated` | `#FFFFFF` | `#252A33` | Floating elements |

### Surface Colors

| Token | Light Mode | Dark Mode | Usage |
|-------|-----------|-----------|-------|
| `Surface.primary` | `#F8F9FA` | `#1A1E24` | Cards, containers |
| `Surface.secondary` | `#F8F9FA` | `#22272F` | Nested cards |
| `Surface.elevated` | `#FFFFFF` | `#2A303A` | Modals, sheets |
| `Surface.input` | `#F1F3F5` | `#1A1E24` | Text fields |

### Text Colors

| Token | Light Mode | Dark Mode | Usage |
|-------|-----------|-----------|-------|
| `Text.primary` | `#1A1D23` | `#F9FAFB` | Main content |
| `Text.secondary` | `#6B7280` | `#9CA3AF` | Supporting text |
| `Text.tertiary` | `#9CA3AF` | `#6B7280` | Hints, placeholders |
| `Text.accent` | `#059669` | `#A4FC3C` | Highlighted text |
| `Text.onBrand` | `#1A1D23` | `#1A1D23` | Text on lime buttons |

### Semantic Colors

| Token | Value | Usage |
|-------|-------|-------|
| `Semantic.success` | `#10B981` (Emerald) | Success states, confirmations |
| `Semantic.error` | `#EF4444` (Red) | Errors, destructive actions |
| `Semantic.warning` | `#F59E0B` (Amber) | Warnings, low credits |
| `Semantic.info` | `#3B82F6` (Blue) | Information, tips |

### Gradients

| Gradient | Start | End | Usage |
|----------|-------|-----|-------|
| **Primary** | `#A4FC3C` | `#7DD321` | Primary CTAs |
| **Energetic** | `#A4FC3C` | `#7DD3FC` (Ice Blue) | Premium features |
| **Shimmer** | `#A4FC3C` → `#C8FD6D` → `#A4FC3C` | VIP badges, loading |

---

## Typography System

### Font Scale (iOS System Fonts)

| Style | Size | Weight | Usage |
|-------|------|--------|-------|
| `largeTitle` | 34pt | Bold | Screen titles, hero text |
| `title1` | 28pt | Bold | Section headers |
| `title2` | 22pt | Bold | Card titles, category names |
| `title3` | 20pt | Semibold | Subsection headers |
| `headline` | 17pt | Semibold | Button text, card headlines |
| `body` | 17pt | Regular | Main body text |
| `callout` | 16pt | Regular | Secondary body, descriptions |
| `subheadline` | 15pt | Regular | Supporting text |
| `footnote` | 13pt | Regular | Small print, metadata |
| `caption1` | 12pt | Regular | Labels, timestamps |
| `caption2` | 11pt | Regular | Micro labels |

### Typography Hierarchy Example
```
largeTitle: "Welcome to BananaUniverse" (34pt Bold)
    title1: "How It Works" (28pt Bold)
        headline: "Choose your style" (17pt Semibold)
            callout: "Browse 19+ AI themes" (16pt Regular)
                caption1: "1 credit per use" (12pt Regular)
```

---

## Spacing & Layout

### 8pt Grid System

| Token | Value | Usage |
|-------|-------|-------|
| `Spacing.xs` | 4pt | Micro spacing, icon gaps |
| `Spacing.sm` | 8pt | Small gaps, inline spacing |
| `Spacing.md` | 16pt | Standard padding, card padding |
| `Spacing.lg` | 24pt | Section spacing |
| `Spacing.xl` | 32pt | Large section gaps |
| `Spacing.xxl` | 48pt | Hero spacing |

### Layout Constants

| Token | Value | Usage |
|-------|-------|-------|
| `Layout.headerHeight` | 56pt | Navigation headers |
| `Layout.tabBarHeight` | 83pt | Bottom tab bar |
| `Layout.inputHeight` | 44pt | Text fields |
| `Layout.buttonHeight` | 44pt | Standard buttons |
| `Layout.cardMinHeight` | 120pt | Minimum card height |

---

## Corner Radius System

| Token | Value | Usage |
|-------|-------|-------|
| `CornerRadius.xs` | 4pt | Small elements, tags |
| `CornerRadius.sm` | 8pt | Buttons, inputs, chips |
| `CornerRadius.md` | 12pt | Cards, containers |
| `CornerRadius.lg` | 16pt | Large cards, modals |
| `CornerRadius.xl` | 20pt | Bottom sheets |
| `CornerRadius.round` | 50pt | Pills, circular elements |

---

## Shadow System

| Token | Color | Radius | Offset | Usage |
|-------|-------|--------|--------|-------|
| `Shadow.none` | Clear | 0 | 0, 0 | No shadow |
| `Shadow.sm` | Black 10% | 2pt | 0, 1 | Subtle elevation |
| `Shadow.md` | Black 15% | 4pt | 0, 2 | Cards, buttons |
| `Shadow.lg` | Black 20% | 8pt | 0, 4 | Modals, toasts |
| `Shadow.xl` | Black 25% | 16pt | 0, 8 | Large overlays |
| **`Shadow.glow`** | Lime 30% | 12pt | 0, 4 | **CTA buttons (signature!)** |

### Shadow Colors
- Default (dark): `Black 40%`
- Default (light): `Black 10%`
- Elevated (dark): `Black 60%`
- Elevated (light): `Black 15%`
- **Primary (glow)**: `Lime 30%` (dark) / `Lime 20%` (light)

---

## Animation Philosophy

> **"Animation should feel alive, not mechanical"** - Design principle

### Animation Presets

| Token | Duration | Curve | Usage |
|-------|----------|-------|-------|
| `Animation.quick` | 0.2s | easeInOut | Quick feedback, micro-interactions |
| `Animation.smooth` | 0.3s | easeInOut | Standard transitions |
| `Animation.gentle` | 0.4s | easeInOut | Slow reveals, page transitions |
| `Animation.spring` | 0.6s | Spring (0.8 damping) | Natural bounces |
| `Animation.bouncy` | 0.4s | Spring (0.6 damping) | Playful, energetic |

### Animation Patterns Observed
- **Button press**: Scale to 0.96 with quick animation
- **Card press**: Scale to 0.98 with quick animation
- **Page transitions**: easeInOut 0.25s
- **Carousel auto-advance**: easeInOut 0.5s
- **Toast entrance**: Move + opacity combined

---

## Component Catalog

### 1. CTA Buttons (Primary)

**Visual Spec:**
- Background: `Brand.primary` (Electric Lime)
- Text: `Text.onBrand` (Dark charcoal)
- Height: 44pt
- Corner radius: 8pt (`CornerRadius.sm`)
- Font: `headline` (17pt Semibold)
- Press animation: Scale 0.96
- **Signature**: Lime glow shadow on dark mode

**States:**
- Default: Lime background
- Pressed: Scale 0.96
- Disabled: Tertiary background, quaternary text
- Loading: Progress indicator

### 2. Secondary Buttons

**Visual Spec:**
- Background: Transparent with border
- Border: 1.5pt `Brand.primary` stroke
- Text: `Brand.primary`
- Height: 44pt
- Corner radius: 8pt

### 3. Cards (AppCard)

**Visual Spec:**
- Background: `Surface.primary`
- Padding: 16pt (`Spacing.md`)
- Corner radius: 12pt (`CornerRadius.md`)
- Shadow: `Shadow.md`
- Press animation: Scale 0.98

### 4. Tool Cards

**Visual Spec:**
- Thumbnail: 120x120pt with 8pt radius
- Total height: 180pt
- Width: 160pt (in horizontal scrolls)
- Title: `headline` weight, max 2 lines

### 5. Input Fields

**Visual Spec:**
- Height: 44pt
- Background: `Background.secondary`
- Border: 1pt `Background.tertiary` (2pt `Brand.primary` on focus)
- Corner radius: 8pt
- Icon color: Tertiary → Primary on focus

### 6. Progress Dots (Onboarding)

**Visual Spec:**
- Dot size: 8pt circles
- Active: `Brand.secondary` + 1.2x scale
- Inactive: `Text.tertiary` at 30% opacity
- Spacing: 8pt (`Spacing.sm`)

### 7. Toast Notifications

**Visual Spec:**
- Background: `Surface.primary`
- Shadow: `Shadow.lg`
- Corner radius: 12pt
- Auto-dismiss: 3 seconds
- Entrance: Slide + fade from top

---

## Haptic Feedback System

| Interaction | Haptic Style |
|-------------|--------------|
| Primary button tap | Medium impact |
| Secondary button tap | Light impact |
| Card tap | Light impact |
| Tab selection | Selection changed |
| Success action | Notification success |
| Error action | Notification error |
| Warning | Notification warning |

---

## Icon System

### Sizes
- **Small icons**: 12-14pt (chevrons, badges)
- **Medium icons**: 16-20pt (buttons, cards)
- **Large icons**: 22-28pt (step cards, features)
- **Hero icons**: 50pt+ (onboarding illustrations)

### Colors
- Active: `Brand.primary` (Lime)
- Inactive: `Text.tertiary`
- On cards: `Brand.primary` or semantic color
- Step numbers: `Brand.secondary` (Gray/Charcoal)

---

## Navigation Patterns

### Tab Bar
- Height: 83pt
- Background: `Surface.primary`
- Active icon: `Brand.primary`
- Inactive icon: `Text.tertiary`

### Header Bar (UnifiedHeaderBar)
- Height: 56pt
- Background: Transparent (inherits from content)
- Logo: 32pt app logo
- Right content: Credits badge, search icon

### Screen Transitions
- Push: Standard iOS push
- Modal: Sheet presentation
- Full screen: `.fullScreenCover`

---

## Current Design Gaps

### Identified Inconsistencies

1. **Onboarding uses `Brand.secondary` (gray)** instead of `Brand.primary` (lime) for accents
   - Main app: Lime everywhere
   - Onboarding: Gray/charcoal for buttons, badges, progress dots

2. **OnboardingScreen4 exists but is not used**
   - File exists with "Save Your Images" warning
   - Current flow only has 3 screens (welcome, howItWorks, credits)

3. **Inconsistent button accent colors**
   - Main app: Lime primary buttons
   - Onboarding: Uses `Brand.secondary` (gray) for primary buttons

4. **Missing wow moments**
   - No particle effects or celebrations
   - No animated illustrations
   - Static content vs. app's dynamic feel

5. **No lime glow in onboarding**
   - Main app uses lime glow shadow extensively
   - Onboarding cards have no glow effect

---

## Accessibility Compliance

| Standard | Status | Notes |
|----------|--------|-------|
| WCAG AA Contrast | Pass | Text colors meet 4.5:1 ratio |
| Touch Targets | Pass | 44pt minimum button height |
| Color Independence | Pass | Icons + text for states |
| Motion Preferences | Partial | Should respect `prefers-reduced-motion` |
| VoiceOver Labels | Present | Accessibility labels on interactive elements |

---

## OLED Optimization

| Element | Dark Mode Implementation |
|---------|-------------------------|
| Primary background | `#121417` (Deep charcoal, near-black) |
| True blacks | Used for overlays and shadows |
| OLED efficiency | Minimized bright pixels in dark mode |
| Battery impact | Optimized for OLED displays |

---

## Design Tokens Summary

### Quick Reference Card

```swift
// Colors
Brand.primary(colorScheme)        // Electric Lime - CTAs, active
Brand.secondary(colorScheme)      // Charcoal/Gray - Secondary
Brand.accent(colorScheme)         // Ice Blue - Premium

// Typography
DesignTokens.Typography.largeTitle  // 34pt Bold
DesignTokens.Typography.headline    // 17pt Semibold

// Spacing
DesignTokens.Spacing.md             // 16pt
DesignTokens.Spacing.lg             // 24pt

// Radius
DesignTokens.CornerRadius.sm        // 8pt - Buttons
DesignTokens.CornerRadius.md        // 12pt - Cards

// Animation
DesignTokens.Animation.quick        // 0.2s
DesignTokens.Animation.bouncy       // Spring
```

---

**Audit Complete**

This document serves as the baseline for the Onboarding Redesign Proposal. The key takeaway is that the main app has a **bold, energetic personality with Electric Lime as the signature color**, while the current onboarding uses a **muted gray palette** that doesn't match the app's energy.

---

*Last Updated: 2026-01-27*
