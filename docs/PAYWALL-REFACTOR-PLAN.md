# Paywall Refactor Plan - BananaUniverse

**Version:** 2.0
**Date:** January 2026
**Status:** Ready for Implementation

---

## Overview

Complete paywall redesign with conversion-optimized layout:
- **1 Featured Card** (100 credits - Best Value) - Large, prominent
- **3 Standard Cards** (10, 25, 50 credits) - Smaller, horizontal row
- **Reusable Components** - Same component, different sizes
- **Dynamic CTA** - Shows selected credit amount
- **Full i18n** - No hardcoded strings

---

## Visual Layout

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   "Unlock AI Creation"                    [X] Close     │
│   "Credits never expire. No subscription."              │
│                                                         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│   ┌─────────────────────────────────────────────────┐   │
│   │  [BEST VALUE]                        SAVE 44%   │   │
│   │                                                 │   │
│   │  🎨 100 Credits                                 │   │
│   │                                                 │   │
│   │  $0.50/credit                                   │   │
│   │  = 100 AI creations                             │   │
│   │                                                 │   │
│   │                                    $49.99       │   │
│   └─────────────────────────────────────────────────┘   │
│                         ↑                               │
│              Featured Card (Pre-selected)               │
│                                                         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│   ┌───────────┐   ┌───────────┐   ┌───────────┐        │
│   │ 50 Credits│   │ 25 Credits│   │ 10 Credits│        │
│   │           │   │           │   │           │        │
│   │ $0.60/cr  │   │ $0.72/cr  │   │ $0.90/cr  │        │
│   │ Save 33%  │   │ Save 20%  │   │           │        │
│   │           │   │           │   │           │        │
│   │  $29.99   │   │  $17.99   │   │  $8.99    │        │
│   └───────────┘   └───────────┘   └───────────┘        │
│         ↑               ↑               ↑               │
│              Standard Cards (3 columns)                 │
│                                                         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│         [      Get 100 Credits      ]                   │
│                    ↑                                    │
│         Dynamic CTA (shows selected amount)             │
│                                                         │
│              Restore Purchases                          │
│                                                         │
│            Terms  •  Privacy                            │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Component Architecture

### File Structure

```
Features/Paywall/
├── Views/
│   ├── PaywallView.swift              # Main paywall screen
│   └── Components/
│       ├── CreditPackageCard.swift    # Reusable card (both sizes)
│       ├── PaywallHeader.swift        # Title + subtitle
│       ├── PaywallCTAButton.swift     # Dynamic CTA button
│       └── PaywallFooter.swift        # Restore + Terms/Privacy
└── ViewModels/
    └── PaywallViewModel.swift         # Selection state, purchase logic
```

### Component: CreditPackageCard

**Single component with two variants via `CardSize` enum.**

```swift
enum CardSize {
    case featured    // Large card for 100 credits
    case standard    // Small cards for 10, 25, 50 credits
}

struct CreditPackageCard: View {
    let package: StoreKitProduct
    let size: CardSize
    let isSelected: Bool
    let onTap: () -> Void

    // Computed properties
    var credits: Int
    var price: Decimal
    var perCreditPrice: Decimal
    var savingsPercent: Int?
    var badgeText: String?  // "BEST VALUE" for 100 credits only
}
```

---

## Featured Card Specifications (100 Credits)

### Layout (Vertical Stack)

```
┌─────────────────────────────────────────────────────────┐
│ HStack:                                                 │
│   [BEST VALUE] badge (left)         SAVE 44% (right)   │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ 100 Credits                              (24pt, bold)   │
│                                                         │
│ $0.50/credit                    (16pt, green, semibold) │
│                                                         │
│ = 100 AI creations                   (14pt, secondary)  │
│                                                         │
│                                          $49.99 (right) │
│                                          (28pt, bold)   │
└─────────────────────────────────────────────────────────┘
```

### Styling

| Property | Value |
|----------|-------|
| Height | ~160pt (auto) |
| Padding | 20pt |
| Corner Radius | 16pt |
| Background (selected) | `Color.green.opacity(0.08)` |
| Background (unselected) | `DesignTokens.Background.secondary` |
| Border (selected) | 3pt green |
| Border (unselected) | 1pt gray |

### Badge: "BEST VALUE"

```swift
Text("paywall_badge_best_value".localized)
    .font(.system(size: 11, weight: .bold))
    .foregroundColor(.white)
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(DesignTokens.Brand.primary)
    .cornerRadius(4)
```

### Savings Badge: "SAVE 44%"

```swift
Text("paywall_card_save".localized(44))
    .font(.system(size: 13, weight: .semibold))
    .foregroundColor(DesignTokens.Brand.primary)
```

---

## Standard Card Specifications (10, 25, 50 Credits)

### Layout (Vertical Stack)

```
┌─────────────────┐
│                 │
│  50 Credits     │  (17pt, semibold)
│                 │
│  $0.60/credit   │  (13pt, secondary)
│  Save 33%       │  (12pt, secondary or green for 50)
│                 │
│    $29.99       │  (18pt, bold)
│                 │
└─────────────────┘
```

### Styling

| Property | Value |
|----------|-------|
| Width | Equal distribution (3 columns) |
| Height | ~120pt (auto) |
| Padding | 12pt |
| Corner Radius | 12pt |
| Background (selected) | `Color.green.opacity(0.08)` |
| Background (unselected) | `DesignTokens.Background.secondary` |
| Border (selected) | 2pt green |
| Border (unselected) | 1pt gray |

### Special Cases

| Credits | Savings | Show Savings? |
|---------|---------|---------------|
| 10 | 0% (base) | No |
| 25 | 20% | Yes |
| 50 | 33% | Yes (green text) |

---

## Pricing & Savings Calculation

### Base Reference
```
10 credits = $8.99 = $0.899/credit (display as $0.90)
```

### All Packages

| Credits | Price | Per Credit | Savings | Display |
|---------|-------|------------|---------|---------|
| 10 | $8.99 | $0.90 | 0% | No badge |
| 25 | $17.99 | $0.72 | 20% | "Save 20%" |
| 50 | $29.99 | $0.60 | 33% | "Save 33%" |
| 100 | $49.99 | $0.50 | 44% | "SAVE 44%" |

### Formula
```swift
let basePerCredit = 0.899  // $8.99 / 10 credits
let currentPerCredit = price / Double(credits)
let savingsPercent = Int(((basePerCredit - currentPerCredit) / basePerCredit) * 100)
```

---

## Dynamic CTA Button

### Behavior
- Shows selected credit amount: "Get 100 Credits"
- Updates when user taps different card
- Default: 100 credits pre-selected

### Implementation

```swift
struct PaywallCTAButton: View {
    let selectedCredits: Int
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isLoading {
                ProgressView()
                    .tint(.white)
            } else {
                Text("paywall_button_cta_dynamic".localized(selectedCredits))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(
            LinearGradient(
                colors: [Color(hex: "4CD964"), Color(hex: "2EBD4A")],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(16)
        .shadow(
            color: Color(hex: "34C759").opacity(0.4),
            radius: 8,
            y: 4
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
    }
}
```

---

## Header Component

```swift
struct PaywallHeader: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("paywall_title".localized)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(DesignTokens.Text.primary(colorScheme))

            Text("paywall_subtitle".localized)
                .font(.system(size: 16))
                .foregroundColor(DesignTokens.Text.secondary(colorScheme))
        }
    }
}
```

---

## Footer Component

```swift
struct PaywallFooter: View {
    let onRestore: () -> Void
    let onTerms: () -> Void
    let onPrivacy: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Restore Purchases
            Text("paywall_footer_restore".localized)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(DesignTokens.Brand.primary)
                .onTapGesture(perform: onRestore)

            // Terms & Privacy
            HStack(spacing: 4) {
                Text("paywall_footer_terms".localized)
                    .onTapGesture(perform: onTerms)

                Text("•")

                Text("paywall_footer_privacy".localized)
                    .onTapGesture(perform: onPrivacy)
            }
            .font(.system(size: 13))
            .foregroundColor(DesignTokens.Text.secondary(colorScheme))
        }
    }
}
```

---

## Localization Keys

### English (en.lproj/Localizable.strings)

```
// MARK: - Paywall

"paywall_title" = "Unlock AI Creation";
"paywall_subtitle" = "Credits never expire. No subscription.";

// Cards
"paywall_card_credits" = "%d Credits";
"paywall_card_per_credit" = "$%.2f/credit";
"paywall_card_save" = "Save %d%%";
"paywall_card_value_description" = "= %d AI creations";

// Badges
"paywall_badge_best_value" = "BEST VALUE";

// CTA
"paywall_button_cta_dynamic" = "Get %d Credits";

// Footer
"paywall_footer_restore" = "Restore Purchases";
"paywall_footer_terms" = "Terms";
"paywall_footer_privacy" = "Privacy";
```

### Turkish (tr.lproj/Localizable.strings)

```
// MARK: - Paywall

"paywall_title" = "AI Oluşturmayı Başlat";
"paywall_subtitle" = "Krediler süresiz. Abonelik yok.";

// Cards
"paywall_card_credits" = "%d Kredi";
"paywall_card_per_credit" = "$%.2f/kredi";
"paywall_card_save" = "%d%% Tasarruf";
"paywall_card_value_description" = "= %d AI oluşturma";

// Badges
"paywall_badge_best_value" = "EN İYİ DEĞER";

// CTA
"paywall_button_cta_dynamic" = "%d Kredi Al";

// Footer
"paywall_footer_restore" = "Satın Almaları Geri Yükle";
"paywall_footer_terms" = "Koşullar";
"paywall_footer_privacy" = "Gizlilik";
```

---

## Selection State Management

### Default State
- **100 credits is pre-selected** when paywall opens
- Green border + light green background on selected card

### User Interaction
1. User taps any card → that card becomes selected
2. CTA button text updates to show selected credits
3. Only one card can be selected at a time

### Implementation

```swift
@Published var selectedPackage: StoreKitProduct?

init() {
    // Pre-select 100 credits (best value)
    selectedPackage = packages.first { $0.credits == 100 }
}
```

---

## Analytics Events

Track these events for funnel analysis:

| Event | Parameters | When |
|-------|------------|------|
| `paywall_viewed` | `source` | Paywall opens |
| `package_selected` | `credits`, `price` | User taps card |
| `purchase_initiated` | `credits`, `price` | User taps CTA |
| `purchase_completed` | `credits`, `price`, `transaction_id` | Purchase succeeds |
| `purchase_failed` | `credits`, `error` | Purchase fails |
| `restore_tapped` | - | User taps restore |

---

## Dark Mode Support

| Element | Light Mode | Dark Mode |
|---------|------------|-----------|
| Background | `DesignTokens.Background.primary` | `DesignTokens.Background.primary` |
| Card BG (unselected) | `DesignTokens.Background.secondary` | `DesignTokens.Background.secondary` |
| Card BG (selected) | `Color.green.opacity(0.08)` | `Color.green.opacity(0.15)` |
| Card Border | Gray 200 | Gray 700 |
| Text Primary | Black | White |
| Text Secondary | Gray 600 | Gray 400 |

---

## Implementation Checklist

### Phase 1: Components
- [ ] Create `CreditPackageCard.swift` with `CardSize` enum
- [ ] Create `PaywallHeader.swift`
- [ ] Create `PaywallCTAButton.swift` with dynamic text
- [ ] Create `PaywallFooter.swift` with tappable links

### Phase 2: Main View
- [ ] Refactor `PaywallView.swift` to use new layout
- [ ] Featured card (100 credits) at top
- [ ] 3-column grid for standard cards below
- [ ] Integrate all components

### Phase 3: Localization
- [ ] Add all English keys to `en.lproj/Localizable.strings`
- [ ] Add all Turkish keys to `tr.lproj/Localizable.strings`
- [ ] Verify `.localized` extension works with format strings

### Phase 4: State & Logic
- [ ] Pre-select 100 credits on load
- [ ] Update CTA text on selection change
- [ ] Connect to `StoreKitService` for purchases
- [ ] Implement restore purchases

### Phase 5: Polish
- [ ] Add press animation to CTA (scale 0.98)
- [ ] Add haptic feedback on card selection
- [ ] Test light/dark mode
- [ ] Test all localizations
- [ ] Add analytics events

### Phase 6: Testing
- [ ] Test purchase flow in sandbox
- [ ] Verify all 4 products work
- [ ] Test restore purchases
- [ ] Test on different device sizes

---

## Files to Modify

| File | Action |
|------|--------|
| `Features/Paywall/Views/Components/CreditPackageCard.swift` | CREATE (new reusable component) |
| `Features/Paywall/Views/Components/PaywallHeader.swift` | CREATE |
| `Features/Paywall/Views/Components/PaywallCTAButton.swift` | CREATE |
| `Features/Paywall/Views/Components/PaywallFooter.swift` | CREATE |
| `Features/Paywall/Views/PaywallView.swift` | REFACTOR (use new components) |
| `Features/Paywall/ViewModels/PaywallViewModel.swift` | UPDATE (pre-select logic) |
| `Resources/Localizations/en.lproj/Localizable.strings` | UPDATE (add keys) |
| `Resources/Localizations/tr.lproj/Localizable.strings` | UPDATE (add keys) |

---

## Notes

1. **Pre-selection is critical** - 100 credits must be selected by default
2. **Value visualization** - "= 100 AI creations" helps users understand worth
3. **Trust in subtitle** - "Credits never expire" reduces purchase anxiety
4. **Dynamic CTA** - Reinforces the selection before purchase
5. **Consistent components** - Same `CreditPackageCard` for all cards, just different size

---

**Ready for Implementation**
