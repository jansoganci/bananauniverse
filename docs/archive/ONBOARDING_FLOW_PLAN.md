# BananaUniverse Onboarding Flow - Complete Plan

**Created:** November 22, 2025
**Purpose:** First-time user onboarding to increase activation and reduce confusion
**Target:** 80%+ completion rate, 40%+ first transformation rate

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [User Flow & Trigger Logic](#user-flow--trigger-logic)
3. [Screen-by-Screen Breakdown](#screen-by-screen-breakdown)
4. [Technical Implementation](#technical-implementation)
5. [Design Specifications](#design-specifications)
6. [Files to Create](#files-to-create)
7. [Testing Checklist](#testing-checklist)
8. [Success Metrics](#success-metrics)

---

## Overview

### Goals
- ✅ Educate new users about app capabilities
- ✅ Explain credit system upfront (prevent confusion)
- ✅ Showcase viral potential (Collectible Figure Style example)
- ✅ Increase first transformation completion rate
- ✅ Set clear expectations

### Philosophy
- **Show, don't tell** - Use visuals over text
- **Quick & skippable** - Respect user's time
- **Value-first** - Lead with benefits, not features
- **Mobile-optimized** - Designed for iPhone screens

---

## User Flow & Trigger Logic

### When Onboarding Shows

```swift
// BananaUniverseApp.swift
@AppStorage("hasSeenOnboarding") var hasSeenOnboarding = false
@State private var showOnboarding = false

var body: some Scene {
    WindowGroup {
        ContentView()
            .onAppear {
                // Check if user has ever seen onboarding
                if !hasSeenOnboarding {
                    showOnboarding = true
                }
            }
            .sheet(isPresented: $showOnboarding) {
                OnboardingView(onComplete: {
                    showOnboarding = false
                })
            }
    }
}
```

### Trigger Conditions

**Show onboarding when:**
1. ✅ First app launch (hasSeenOnboarding = false)
2. ✅ User has never seen onboarding before
3. ✅ App reinstalled (UserDefaults cleared)

**DO NOT show onboarding when:**
1. ❌ User has already seen it once (hasSeenOnboarding = true)
2. ❌ Skip OR complete doesn't matter - once seen = never show again

### Storage Mechanism (Option 1 - Recommended)

**Key Insight:** Flag is set immediately when onboarding appears, NOT when user completes it.

```swift
// Use @AppStorage for persistent storage
@AppStorage("hasSeenOnboarding") var hasSeenOnboarding: Bool = false

// OnboardingView sets flag on appear
struct OnboardingView: View {
    var onComplete: () -> Void

    var body: some View {
        ZStack {
            // ... onboarding UI
        }
        .onAppear {
            // ✅ Set flag IMMEDIATELY when onboarding shows
            // This ensures user NEVER sees it again (skip or complete)
            UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        }
    }
}
```

**Key:** `hasSeenOnboarding`
**Type:** Boolean
**Default:** `false`
**Set When:** OnboardingView `.onAppear` (immediately when shown)
**Result:** User sees onboarding exactly once, whether they skip or complete it
**Location:** UserDefaults.standard (persists across app launches)
**Cleared when:** User deletes app

### User Journey Summary

**First Launch:**
1. User opens app → `hasSeenOnboarding = false`
2. Onboarding sheet appears
3. `.onAppear` sets `hasSeenOnboarding = true` (immediately!)
4. User sees 3 screens, then either:
   - Taps "Skip" → sheet dismisses
   - Taps "Get Started" → sheet dismisses

**Second Launch (and forever):**
1. User opens app → `hasSeenOnboarding = true`
2. Onboarding NEVER shows again ✅

**Key Insight:** Flag is set when onboarding **appears**, NOT when user completes it. This ensures one-time viewing regardless of user action.

---

## Screen-by-Screen Breakdown

### Screen 1: Welcome 🎉

**Goal:** Hook user with viral potential, set excitement

**Visual Layout:**
```
┌─────────────────────────────────────┐
│                                     │
│   [Skip]                            │ ← Top-right, subtle
│                                     │
│                                     │
│   ┌─────────────────────────────┐   │
│   │                             │   │
│   │  [Collectible Figure Img]   │   │ ← Hero image (280×180)
│   │   Before/After Comparison   │   │   Side-by-side or slider
│   │                             │   │
│   └─────────────────────────────┘   │
│                                     │
│   Welcome to                        │ ← Title (32pt bold)
│   BananaUniverse                    │
│                                     │
│   Transform your photos into        │ ← Subtitle (18pt regular)
│   viral content in seconds          │
│                                     │
│                                     │
│                                     │
│   ⚫⚪⚪                              │ ← Progress dots
│                                     │
│   ┌─────────────────────────────┐   │
│   │      Next →                 │   │ ← Primary button
│   └─────────────────────────────┘   │
│                                     │
└─────────────────────────────────────┘
```

**Content:**
- **Title:** "Welcome to BananaUniverse"
- **Subtitle:** "Transform your photos into viral content in seconds"
- **Hero Visual:** Collectible Figure Style before/after comparison
  - Option A: Side-by-side images (before | after)
  - Option B: Image slider (swipe to reveal)
  - Option C: Animated transition (before → after)
- **CTA:** "Next →" (purple primary button)
- **Skip:** "Skip" (top-right, subtle gray text)

**Design Details:**
- Background: Clean white (light) / dark (#1A1A1D) gradient
- Hero image: 280×220pt card with rounded corners (16pt)
- Title: 32pt bold, primary text color
- Subtitle: 18pt regular, secondary text color
- Progress dots: 8pt circles, primary color for active
- Button: Full-width primary button (DesignTokens.Brand.primary)

**Interactions:**
- Tap "Next" → Navigate to Screen 2 (slide left animation)
- Tap "Skip" → Dismiss onboarding (do NOT set hasCompletedOnboarding)
- Swipe left → Navigate to Screen 2

**Why this works:**
- Shows BEST example first (Collectible Figure Style = most viral)
- Visual proof > text descriptions
- Sets expectation: "This app creates viral content"

---

### Screen 2: How It Works 🎨

**Goal:** Explain the 3-step process, reduce friction

**Visual Layout:**
```
┌─────────────────────────────────────┐
│                                     │
│   [Skip]                            │ ← Top-right, subtle
│                                     │
│   How It Works                      │ ← Title (28pt bold)
│                                     │
│   ┌─────────────────────────────┐   │
│   │  ┌────┐                     │   │
│   │  │ 1  │  Choose your style  │   │ ← Step 1
│   │  └────┘                     │   │   Icon: 🎨 (48pt)
│   │                             │   │   Title: 16pt bold
│   │  Browse 19+ AI themes:      │   │   Description: 14pt
│   │  toys, art, pro photos      │   │
│   └─────────────────────────────┘   │
│                                     │
│   ┌─────────────────────────────┐   │
│   │  ┌────┐                     │   │
│   │  │ 2  │  Upload your photo  │   │ ← Step 2
│   │  └────┘                     │   │   Icon: 📸 (48pt)
│   │                             │   │
│   │  Take a picture or choose   │   │
│   │  from your photo library    │   │
│   └─────────────────────────────┘   │
│                                     │
│   ┌─────────────────────────────┐   │
│   │  ┌────┐                     │   │
│   │  │ 3  │  Generate & share   │   │ ← Step 3
│   │  └────┘                     │   │   Icon: ✨ (48pt)
│   │                             │   │
│   │  Customize settings, hit    │   │
│   │  generate, and share!       │   │
│   └─────────────────────────────┘   │
│                                     │
│   ⚪⚫⚪                              │ ← Progress dots
│                                     │
│   ┌──────────┐  ┌─────────────────┐ │
│   │ ← Back   │  │     Next →      │ │ ← Buttons
│   └──────────┘  └─────────────────┘ │
│                                     │
└─────────────────────────────────────┘
```

**Content:**

**Step 1: Choose your style**
- Icon: 🎨 (paintpalette.fill, 48pt, accent color)
- Title: "Choose your style" (16pt bold)
- Description: "Browse 19+ AI themes: toys, art, pro photos" (14pt regular)

**Step 2: Upload your photo**
- Icon: 📸 (camera.fill, 48pt, primary color)
- Title: "Upload your photo" (16pt bold)
- Description: "Take a picture or choose from your photo library" (14pt regular)

**Step 3: Generate & share**
- Icon: ✨ (sparkles, 48pt, secondary color)
- Title: "Generate & share" (16pt bold)
- Description: "Customize settings, hit generate, and share!" (14pt regular)

**Design Details:**
- Background: Same as Screen 1 (consistent)
- Step cards: Light cards with 12pt corner radius
- Numbered badges: 32pt circles with gradient background
- Icons: SF Symbols, 48pt size
- Spacing between steps: 16pt
- Title: 28pt bold centered
- Buttons: "Back" (secondary) + "Next" (primary)

**Interactions:**
- Tap "Next" → Navigate to Screen 3 (slide left)
- Tap "Back" → Navigate to Screen 1 (slide right)
- Tap "Skip" → Dismiss onboarding
- Swipe left/right → Navigate between screens

**Why this works:**
- Simple 3-step process (not overwhelming)
- Visual numbers + icons (scannable)
- Matches actual app flow: choose style → upload → generate & share
- Emphasizes the fun part first (browsing cool themes!)

---

### Screen 3: Credits & Get Started 💎

**Goal:** Explain credit system, convert to first transformation

**Visual Layout:**
```
┌─────────────────────────────────────┐
│                                     │
│   [Skip]                            │ ← Top-right (grayed out)
│                                     │
│                                     │
│       ┌───────┐                     │
│       │  💎   │                     │ ← Animated credit badge
│       │  10   │                     │   (scale in animation)
│       └───────┘                     │   80pt size
│                                     │
│   Start with 10 Free Credits        │ ← Title (28pt bold)
│                                     │
│   Each transformation uses          │ ← Description (16pt)
│   1 credit. Buy more anytime.       │   Center-aligned
│                                     │
│   ┌─────────────────────────────┐   │
│   │  ✅  Collectible Figure      │   │ ← Example costs
│   │      1 credit                │   │
│   │                              │   │
│   │  ✅  Professional Headshot   │   │
│   │      1 credit                │   │
│   │                              │   │
│   │  ✅  All tools included      │   │
│   │      No hidden fees          │   │
│   └─────────────────────────────┘   │
│                                     │
│   ⚪⚪⚫                              │ ← Progress dots
│                                     │
│   ┌─────────────────────────────┐   │
│   │   Get Started 🚀            │   │ ← Primary CTA (prominent)
│   └─────────────────────────────┘   │
│                                     │
│   ┌──────────┐                      │
│   │ ← Back   │                      │ ← Back button (secondary)
│   └──────────┘                      │
│                                     │
└─────────────────────────────────────┘
```

**Content:**

**Hero:**
- Large credit badge: 💎 10 (80pt icon + 40pt number)
- Animation: Scale in + pulse effect on appear

**Title:**
- "Start with 10 Free Credits" (28pt bold, centered)

**Description:**
- "Each transformation uses 1 credit. Buy more anytime." (16pt regular, centered)
- Secondary color for less emphasis

**Example List:**
- ✅ Collectible Figure — 1 credit
- ✅ Professional Headshot — 1 credit
- ✅ All tools included — No hidden fees

**Design Details:**
- Background: Subtle gradient (purple → accent)
- Credit badge: Circle with gradient fill, white icon/number
- Example list: Light card with checkmarks
- Spacing: Extra generous (24pt between elements)
- CTA button: Extra prominent (48pt height, bold text)

**Interactions:**
- Tap "Get Started" →
  1. Set `hasCompletedOnboarding = true`
  2. Dismiss onboarding sheet
  3. Show HomeView with welcome animation
  4. Optional: Show tooltip pointing to first featured tool
- Tap "Back" → Navigate to Screen 2
- Tap "Skip" → Dismissed (grayed out, discouraged)

**Why this works:**
- Transparent about credit system (no surprises later)
- Emphasizes FREE credits (10 transformations to start)
- Examples show value (all tools cost same, no tiers)
- Strong CTA creates urgency

---

## Technical Implementation

### File Structure

```
BananaUniverse/
├── Features/
│   └── Onboarding/
│       ├── Views/
│       │   ├── OnboardingView.swift              ← Main container
│       │   ├── OnboardingScreen1.swift           ← Welcome screen
│       │   ├── OnboardingScreen2.swift           ← How it works
│       │   └── OnboardingScreen3.swift           ← Credits & CTA
│       ├── ViewModels/
│       │   └── OnboardingViewModel.swift         ← State management
│       └── Components/
│           ├── OnboardingProgressDots.swift      ← Progress indicator
│           ├── OnboardingStepCard.swift          ← Step component
│           └── CreditBadgeAnimation.swift        ← Animated badge
```

### State Management

**OnboardingViewModel.swift:**
```swift
import SwiftUI

@MainActor
class OnboardingViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var currentScreen: OnboardingScreen = .welcome
    @Published var isPresentingOnboarding = false

    // MARK: - Types

    enum OnboardingScreen: Int, CaseIterable {
        case welcome = 0
        case howItWorks = 1
        case credits = 2

        var title: String {
            switch self {
            case .welcome: return "Welcome to BananaUniverse"
            case .howItWorks: return "How It Works"
            case .credits: return "Start with 10 Free Credits"
            }
        }
    }

    // MARK: - Computed Properties

    var isFirstScreen: Bool {
        currentScreen.rawValue == 0
    }

    var isLastScreen: Bool {
        currentScreen.rawValue == OnboardingScreen.allCases.count - 1
    }

    var progressPercentage: Double {
        Double(currentScreen.rawValue + 1) / Double(OnboardingScreen.allCases.count)
    }

    // MARK: - Actions

    func nextScreen() {
        guard !isLastScreen else { return }

        withAnimation(DesignTokens.Animation.smooth) {
            currentScreen = OnboardingScreen(rawValue: currentScreen.rawValue + 1) ?? .welcome
        }

        DesignTokens.Haptics.impact(.light)
    }

    func previousScreen() {
        guard !isFirstScreen else { return }

        withAnimation(DesignTokens.Animation.smooth) {
            currentScreen = OnboardingScreen(rawValue: currentScreen.rawValue - 1) ?? .welcome
        }

        DesignTokens.Haptics.impact(.light)
    }

    func complete() {
        DesignTokens.Haptics.success()

        // Note: hasSeenOnboarding flag already set in OnboardingView.onAppear
        // No need to set it again here

        // Just dismiss the sheet
        isPresentingOnboarding = false
    }

    func skip() {
        DesignTokens.Haptics.impact(.light)

        // Note: hasSeenOnboarding flag already set in OnboardingView.onAppear
        // User will never see onboarding again (skip or complete doesn't matter)

        // Just dismiss the sheet
        isPresentingOnboarding = false
    }
}
```

### Main Container

**OnboardingView.swift:**
```swift
import SwiftUI

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @Environment(\.colorScheme) var colorScheme

    let onComplete: () -> Void

    var body: some View {
        ZStack {
            // Background
            DesignTokens.Background.primary(colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button
                if !viewModel.isLastScreen {
                    HStack {
                        Spacer()
                        Button("Skip") {
                            viewModel.skip()
                            onComplete()
                        }
                        .font(DesignTokens.Typography.callout)
                        .foregroundColor(DesignTokens.Text.tertiary(colorScheme))
                    }
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.top, DesignTokens.Spacing.md)
                }

                // Content (TabView with paging)
                TabView(selection: $viewModel.currentScreen) {
                    OnboardingScreen1()
                        .tag(OnboardingViewModel.OnboardingScreen.welcome)

                    OnboardingScreen2()
                        .tag(OnboardingViewModel.OnboardingScreen.howItWorks)

                    OnboardingScreen3(onComplete: {
                        viewModel.complete()
                        onComplete()
                    })
                    .tag(OnboardingViewModel.OnboardingScreen.credits)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Progress dots
                OnboardingProgressDots(
                    currentIndex: viewModel.currentScreen.rawValue,
                    totalCount: OnboardingViewModel.OnboardingScreen.allCases.count
                )
                .padding(.bottom, DesignTokens.Spacing.md)

                // Navigation buttons
                HStack(spacing: DesignTokens.Spacing.md) {
                    // Back button
                    if !viewModel.isFirstScreen {
                        SecondaryButton(
                            title: "Back",
                            icon: "chevron.left",
                            action: { viewModel.previousScreen() }
                        )
                        .frame(maxWidth: 100)
                    }

                    Spacer()

                    // Next button (only if not last screen)
                    if !viewModel.isLastScreen {
                        PrimaryButton(
                            title: "Next",
                            icon: "arrow.right",
                            action: { viewModel.nextScreen() }
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.bottom, DesignTokens.Spacing.lg)
            }
        }
        .environmentObject(viewModel)
        .onAppear {
            // ✅ CRITICAL: Set flag IMMEDIATELY when onboarding appears
            // This ensures user NEVER sees onboarding again (skip or complete)
            UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        }
    }
}
```

### Completion Logic

**Where to add in BananaUniverseApp.swift:**
```swift
@main
struct BananaUniverseApp: App {
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var authService = HybridAuthService.shared
    @StateObject private var creditManager = CreditManager.shared

    // MARK: - Onboarding State
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding = false
    @State private var showOnboarding = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
                .environmentObject(authService)
                .environmentObject(creditManager)
                .onAppear {
                    // Check if user has ever seen onboarding
                    if !hasSeenOnboarding {
                        // Small delay to let app fully load
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showOnboarding = true
                        }
                    }
                }
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView(onComplete: {
                        // Note: hasSeenOnboarding already set in OnboardingView.onAppear
                        showOnboarding = false
                    })
                }
        }
    }
}
```

### Persistence Details

**Key:** `hasSeenOnboarding`
**Storage:** UserDefaults.standard
**Type:** Boolean
**Default:** `false`
**Set When:** OnboardingView `.onAppear` (immediately when sheet appears)
**Behavior:** Once set to `true`, user will NEVER see onboarding again (regardless of skip or complete)

**How it works:**
1. App launches → checks `hasSeenOnboarding` (false by default)
2. If false → shows onboarding sheet
3. OnboardingView appears → `.onAppear` sets `hasSeenOnboarding = true`
4. User skips OR completes → sheet dismisses
5. App launches again → `hasSeenOnboarding = true` → onboarding never shows ✅

**Reset to false when:**
- User deletes app (UserDefaults cleared)
- Developer manually resets (for testing)

**Check location:**
- BananaUniverseApp.swift → onAppear

**Testing reset:**
```swift
// For development/testing only
#if DEBUG
UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
#endif
```

---

## Design Specifications

### Colors

**Backgrounds:**
- Primary: `DesignTokens.Background.primary(colorScheme)`
- Cards: `DesignTokens.Background.secondary(colorScheme)`
- Elevated: `DesignTokens.Background.elevated(colorScheme)`

**Text:**
- Titles: `DesignTokens.Text.primary(colorScheme)` (32pt bold)
- Body: `DesignTokens.Text.primary(colorScheme)` (16pt regular)
- Secondary: `DesignTokens.Text.secondary(colorScheme)` (14pt regular)
- Skip button: `DesignTokens.Text.tertiary(colorScheme)` (16pt regular)

**Accents:**
- Primary CTA: `DesignTokens.Brand.primary(colorScheme)` background, white text
- Secondary button: `DesignTokens.Brand.primary(colorScheme)` border, transparent background
- Progress dots (active): `DesignTokens.Brand.primary(colorScheme)`
- Progress dots (inactive): `DesignTokens.Background.tertiary(colorScheme)`

**Icons:**
- Step 1: `DesignTokens.Brand.primary(colorScheme)` (purple)
- Step 2: `DesignTokens.Brand.accent(colorScheme)` (amber)
- Step 3: `DesignTokens.Brand.secondary(colorScheme)` (cyan)

### Typography

**Screen 1:**
- Title: 32pt bold (DesignTokens.Typography.largeTitle)
- Subtitle: 18pt regular (DesignTokens.Typography.callout)

**Screen 2:**
- Title: 28pt bold (DesignTokens.Typography.title1)
- Step titles: 16pt bold (DesignTokens.Typography.headline)
- Step descriptions: 14pt regular (DesignTokens.Typography.subheadline)

**Screen 3:**
- Title: 28pt bold (DesignTokens.Typography.title1)
- Description: 16pt regular (DesignTokens.Typography.callout)
- Example items: 14pt regular (DesignTokens.Typography.subheadline)

### Spacing

**Vertical spacing:**
- Between sections: 32pt (DesignTokens.Spacing.xl)
- Between elements: 16pt (DesignTokens.Spacing.md)
- Card padding: 16pt (DesignTokens.Spacing.md)
- Button padding: 16pt horizontal (DesignTokens.Spacing.md)

**Horizontal padding:**
- Screen edges: 20pt
- Card content: 16pt (DesignTokens.Spacing.md)

### Corner Radius

- Cards: 12pt (DesignTokens.CornerRadius.md)
- Buttons: 12pt (DesignTokens.CornerRadius.md)
- Hero image: 16pt (DesignTokens.CornerRadius.lg)
- Progress dots: 50pt (fully round)

### Shadows

- Cards: `DesignTokens.Shadow.md`
- Hero image: `DesignTokens.Shadow.lg`
- Buttons: `DesignTokens.Shadow.sm`

### Animations

**Transitions:**
- Screen changes: `DesignTokens.Animation.smooth` (0.3s easeInOut)
- Progress dots: `DesignTokens.Animation.quick` (0.2s easeInOut)
- Credit badge: `DesignTokens.Animation.spring` (spring animation)

**Effects:**
- Button press: Scale to 0.96
- Credit badge entrance: Scale from 0.8 to 1.0 with spring
- Progress dots: Fade + scale

---

## Files to Create

### SwiftUI Views (7 files)

1. **OnboardingView.swift** (Main container)
   - Location: `BananaUniverse/Features/Onboarding/Views/`
   - Purpose: TabView container, navigation, progress
   - Lines: ~150

2. **OnboardingScreen1.swift** (Welcome)
   - Location: `BananaUniverse/Features/Onboarding/Views/`
   - Purpose: Welcome screen with hero image
   - Lines: ~100

3. **OnboardingScreen2.swift** (How It Works)
   - Location: `BananaUniverse/Features/Onboarding/Views/`
   - Purpose: 3-step process explanation
   - Lines: ~150

4. **OnboardingScreen3.swift** (Credits)
   - Location: `BananaUniverse/Features/Onboarding/Views/`
   - Purpose: Credit explanation + CTA
   - Lines: ~120

5. **OnboardingProgressDots.swift** (Component)
   - Location: `BananaUniverse/Features/Onboarding/Components/`
   - Purpose: Progress indicator dots
   - Lines: ~40

6. **OnboardingStepCard.swift** (Component)
   - Location: `BananaUniverse/Features/Onboarding/Components/`
   - Purpose: Reusable step card for Screen 2
   - Lines: ~80

7. **CreditBadgeAnimation.swift** (Component)
   - Location: `BananaUniverse/Features/Onboarding/Components/`
   - Purpose: Animated credit badge for Screen 3
   - Lines: ~60

### ViewModels (1 file)

8. **OnboardingViewModel.swift**
   - Location: `BananaUniverse/Features/Onboarding/ViewModels/`
   - Purpose: State management, navigation logic
   - Lines: ~100

### Modified Files (1 file)

9. **BananaUniverseApp.swift** (Modify existing)
   - Add: `@AppStorage("hasCompletedOnboarding")`
   - Add: `.sheet(isPresented: $showOnboarding)`
   - Add: Onboarding trigger logic in `.onAppear`
   - Lines added: ~20

**Total:** 8 new files + 1 modified file

---

## Testing Checklist

### Functional Testing

- [ ] **First Launch**
  - [ ] Onboarding shows automatically on first launch
  - [ ] All 3 screens load correctly
  - [ ] Images/icons display properly

- [ ] **Navigation**
  - [ ] "Next" button advances to next screen
  - [ ] "Back" button goes to previous screen
  - [ ] Swipe left/right navigates screens
  - [ ] TabView paging works smoothly

- [ ] **Completion Flow**
  - [ ] "Get Started" on Screen 3 dismisses onboarding
  - [ ] `hasCompletedOnboarding` set to true
  - [ ] App shows HomeView after completion
  - [ ] Onboarding does NOT show on second launch

- [ ] **Skip Flow**
  - [ ] "Skip" button dismisses onboarding
  - [ ] `hasCompletedOnboarding` remains false
  - [ ] Onboarding CAN show again on next launch (optional)

- [ ] **Progress Indication**
  - [ ] Progress dots update on screen change
  - [ ] Correct dot highlighted for each screen
  - [ ] 3 dots total (one per screen)

### Visual Testing

- [ ] **Design Consistency**
  - [ ] DesignTokens used for all colors
  - [ ] DesignTokens used for all spacing
  - [ ] DesignTokens used for all typography
  - [ ] Matches app's design language

- [ ] **Dark/Light Mode**
  - [ ] All screens look good in light mode
  - [ ] All screens look good in dark mode
  - [ ] Text readable in both modes
  - [ ] Proper contrast ratios

- [ ] **Animations**
  - [ ] Screen transitions smooth
  - [ ] Credit badge animates in
  - [ ] Progress dots animate
  - [ ] Button press feedback works

- [ ] **Responsive Design**
  - [ ] Works on iPhone SE (small screen)
  - [ ] Works on iPhone 16 Pro Max (large screen)
  - [ ] No text truncation
  - [ ] Images scale properly

### Edge Cases

- [ ] **State Persistence**
  - [ ] UserDefaults survives app restart
  - [ ] Completion flag persists after quit
  - [ ] Works after app update

- [ ] **Interruptions**
  - [ ] Handles phone call during onboarding
  - [ ] Handles app backgrounding
  - [ ] Resumes correctly when foregrounded

- [ ] **Accessibility**
  - [ ] VoiceOver reads all elements
  - [ ] All buttons have accessibility labels
  - [ ] Text scales with Dynamic Type
  - [ ] Sufficient tap targets (44pt minimum)

### Development Testing

- [ ] **Reset Testing**
  - [ ] Can reset `hasCompletedOnboarding` for testing
  - [ ] Debug flag works to force show onboarding
  - [ ] UserDefaults can be cleared manually

- [ ] **Build Testing**
  - [ ] No compile errors
  - [ ] No SwiftUI preview errors
  - [ ] No runtime crashes
  - [ ] Clean build succeeds

---

## Success Metrics

### Primary Metrics (Track These)

**Completion Rate:**
- **Target:** >80%
- **Measure:** Users who tap "Get Started" / Users who see onboarding
- **Why:** High completion = engaging onboarding

**Skip Rate:**
- **Target:** <20%
- **Measure:** Users who tap "Skip" / Users who see onboarding
- **Why:** Low skip = valuable content

**First Transformation Rate:**
- **Target:** >40%
- **Measure:** Users who generate image within 5 min / Completed onboarding users
- **Why:** Main goal = activate users

### Secondary Metrics

**Time to Complete:**
- **Target:** <60 seconds average
- **Measure:** Time from Screen 1 shown to "Get Started" tap
- **Why:** Fast = respects user time

**Screen Drop-off:**
- **Measure:** Which screen has highest abandonment
- **Why:** Identify weak screens for improvement

**Day 1 Retention:**
- **Target:** >30%
- **Measure:** Onboarded users who return next day / All onboarded users
- **Why:** Good onboarding = better retention

---

## Implementation Timeline

### Phase 1: Core Views (Week 1)
- [ ] Create OnboardingViewModel
- [ ] Build OnboardingView container
- [ ] Build Screen 1 (Welcome)
- [ ] Build Screen 2 (How It Works)
- [ ] Build Screen 3 (Credits)
- [ ] Test navigation flow

### Phase 2: Components (Week 1)
- [ ] Build OnboardingProgressDots
- [ ] Build OnboardingStepCard
- [ ] Build CreditBadgeAnimation
- [ ] Test in preview

### Phase 3: Integration (Week 2)
- [ ] Add to BananaUniverseApp.swift
- [ ] Test first launch flow
- [ ] Test completion logic
- [ ] Test persistence

### Phase 4: Polish (Week 2)
- [ ] Add animations
- [ ] Test dark/light mode
- [ ] Add haptic feedback
- [ ] Accessibility audit
- [ ] Final testing

**Total Time:** ~2 weeks (part-time) or ~1 week (full-time)

---

## FAQ

### Q: What if user skips onboarding?
**A:** They will NEVER see it again. The `hasSeenOnboarding` flag is set immediately when onboarding appears, so skip and complete have the same result.

### Q: Can users re-watch onboarding later?
**A:** Yes! Add a "View Tutorial" button in Profile settings that sets `showOnboarding = true` temporarily (without resetting `hasSeenOnboarding`).

### Q: What if user deletes and reinstalls app?
**A:** UserDefaults is cleared, so they'll see onboarding again. This is expected behavior.

### Q: Should authenticated users see onboarding?
**A:** Optional. You could skip it for signed-in users, or show a shorter version.

### Q: How do I test onboarding repeatedly during development?
**A:** Add debug button to reset:
```swift
#if DEBUG
Button("Reset Onboarding") {
    UserDefaults.standard.set(false, forKey: "hasSeenOnboarding")
}
#endif
```

---

## Next Steps

1. **Review this plan** - Make sure flow makes sense
2. **Approve design** - Confirm screens match your vision
3. **Create files** - Build SwiftUI views + ViewModel
4. **Test thoroughly** - Use checklist above
5. **Track metrics** - Monitor completion and activation rates
6. **Iterate** - Improve based on data

---

**Ready to build!** This onboarding will significantly improve your first-time user experience and increase activation rates. 🚀

**Questions?** Let me know if you want to adjust any screens or flows!
