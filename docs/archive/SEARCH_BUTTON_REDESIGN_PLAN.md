# Search Button Redesign Plan

**Date:** 2026-01-27  
**Status:** Planning Phase - No Implementation Yet

---

## Current State Analysis

### Current Search Button Implementation

**Location:** `BananaUniverse/Features/Home/Views/HomeView.swift` (lines 30-41)

**Current Design:**
```swift
Button {
    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
        isSearchPresented = true
    }
} label: {
    Image(systemName: "magnifyingglass")
        .font(.system(size: 22, weight: .medium))
        .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
}
.accessibilityLabel("Search tools")
.accessibilityHint("Double tap to open search")
```

**Current Issues:**
- ❌ No background (looks "naked")
- ❌ No padding (touches edges)
- ❌ No border/shadow (no visual depth)
- ❌ Doesn't match QuotaDisplayView design
- ❌ Icon-only (no visual container)
- ❌ Inconsistent with header component style

---

## Reference Components

### QuotaDisplayView (Compact Style)

**Design Pattern:**
- Background: `Surface.primary` (card-like)
- Padding: `.horizontal(.md)` (16pt) + `.vertical(.sm)` (8pt)
- Border: `.stroke` with `borderDefault` (dark mode only)
- Corner Radius: `CornerRadius.md` (12pt)
- Shadow: None (header has shadow)
- Height: Auto (based on content + padding)

**Visual Result:**
- Looks like a badge/button
- Matches header background but has subtle separation
- Professional, polished appearance

---

## Design Options

### Option 1: Match QuotaDisplayView Style (Recommended)

**Approach:** Make search button identical to QuotaDisplayView compact style

**Design Specs:**

**Light Mode:**
- Background: `Surface.primary` → `#F8F9FA` (light gray card)
- Icon Color: `Text.secondary` → `#6B7280` (medium gray)
- Border: None (matches QuotaDisplayView light mode)
- Padding: `.horizontal(.md)` (16pt) + `.vertical(.sm)` (8pt)
- Corner Radius: `CornerRadius.md` (12pt)
- Icon Size: 18pt (slightly smaller to fit in container)
- Icon Weight: `.medium`

**Dark Mode:**
- Background: `Surface.primary` → `#1A1E24` (dark card)
- Icon Color: `Text.secondary` → `#9CA3AF` (light gray)
- Border: `.stroke` with `borderDefault` → `#2A303A` (subtle border)
- Padding: `.horizontal(.md)` (16pt) + `.vertical(.sm)` (8pt)
- Corner Radius: `CornerRadius.md` (12pt)
- Icon Size: 18pt
- Icon Weight: `.medium`

**Visual Result:**
- ✅ Matches QuotaDisplayView perfectly
- ✅ Consistent header design
- ✅ Professional appearance
- ✅ Clear visual hierarchy

**Implementation:**
```swift
Button {
    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
        isSearchPresented = true
    }
} label: {
    Image(systemName: "magnifyingglass")
        .font(.system(size: 18, weight: .medium))
        .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
}
.padding(.horizontal, DesignTokens.Spacing.md)
.padding(.vertical, DesignTokens.Spacing.sm)
.background(
    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
        .fill(DesignTokens.Surface.primary(themeManager.resolvedColorScheme))
)
.overlay(
    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
        .stroke(
            themeManager.resolvedColorScheme == .dark
                ? DesignTokens.Special.borderDefault(themeManager.resolvedColorScheme)
                : Color.clear,
            lineWidth: 0.5
        )
)
.accessibilityLabel("Search tools")
.accessibilityHint("Double tap to open search")
```

---

### Option 2: Circular Icon Button

**Approach:** Circular background with icon centered

**Design Specs:**

**Light Mode:**
- Background: `Surface.secondary` → `#F8F9FA` (light gray)
- Icon Color: `Text.secondary` → `#6B7280`
- Border: None
- Size: 40pt × 40pt (fixed square)
- Corner Radius: `CornerRadius.round` (50pt = perfect circle)
- Icon Size: 18pt
- Icon Weight: `.medium`

**Dark Mode:**
- Background: `Surface.secondary` → `#F8F9FA` (same as light)
- Icon Color: `Text.secondary` → `#9CA3AF`
- Border: `.stroke` with `borderDefault` → `#2A303A`
- Size: 40pt × 40pt
- Corner Radius: `CornerRadius.round` (50pt)
- Icon Size: 18pt
- Icon Weight: `.medium`

**Visual Result:**
- ✅ Modern, iOS-style circular button
- ✅ Compact and clean
- ⚠️ Different from QuotaDisplayView (less consistent)

**Implementation:**
```swift
Button {
    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
        isSearchPresented = true
    }
} label: {
    Image(systemName: "magnifyingglass")
        .font(.system(size: 18, weight: .medium))
        .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
        .frame(width: 40, height: 40)
}
.background(
    Circle()
        .fill(DesignTokens.Surface.secondary(themeManager.resolvedColorScheme))
)
.overlay(
    Circle()
        .stroke(
            themeManager.resolvedColorScheme == .dark
                ? DesignTokens.Special.borderDefault(themeManager.resolvedColorScheme)
                : Color.clear,
            lineWidth: 0.5
        )
)
.accessibilityLabel("Search tools")
.accessibilityHint("Double tap to open search")
```

---

### Option 3: Minimal Border Style

**Approach:** Subtle border with no background (minimalist)

**Design Specs:**

**Light Mode:**
- Background: None (transparent)
- Icon Color: `Text.secondary` → `#6B7280`
- Border: `.stroke` with `borderDefault` → `#E5E7EB` (light gray border)
- Padding: `.horizontal(.md)` (16pt) + `.vertical(.sm)` (8pt)
- Corner Radius: `CornerRadius.md` (12pt)
- Icon Size: 18pt
- Icon Weight: `.medium`

**Dark Mode:**
- Background: None (transparent)
- Icon Color: `Text.secondary` → `#9CA3AF`
- Border: `.stroke` with `borderDefault` → `#2A303A` (dark border)
- Padding: `.horizontal(.md)` (16pt) + `.vertical(.sm)` (8pt)
- Corner Radius: `CornerRadius.md` (12pt)
- Icon Size: 18pt
- Icon Weight: `.medium`

**Visual Result:**
- ✅ Minimalist, clean
- ✅ Less visual weight
- ⚠️ Less prominent (might be harder to notice)
- ⚠️ Different from QuotaDisplayView

**Implementation:**
```swift
Button {
    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
        isSearchPresented = true
    }
} label: {
    Image(systemName: "magnifyingglass")
        .font(.system(size: 18, weight: .medium))
        .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
}
.padding(.horizontal, DesignTokens.Spacing.md)
.padding(.vertical, DesignTokens.Spacing.sm)
.overlay(
    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
        .stroke(
            DesignTokens.Special.borderDefault(themeManager.resolvedColorScheme),
            lineWidth: 1
        )
)
.accessibilityLabel("Search tools")
.accessibilityHint("Double tap to open search")
```

---

### Option 4: Brand Accent Style

**Approach:** Use brand lime color for icon (more prominent)

**Design Specs:**

**Light Mode:**
- Background: `Surface.primary` → `#F8F9FA`
- Icon Color: `Brand.primary` → `#7DD321` (darker lime for contrast)
- Border: None
- Padding: `.horizontal(.md)` (16pt) + `.vertical(.sm)` (8pt)
- Corner Radius: `CornerRadius.md` (12pt)
- Icon Size: 18pt
- Icon Weight: `.medium`

**Dark Mode:**
- Background: `Surface.primary` → `#1A1E24`
- Icon Color: `Brand.primary` → `#A4FC3C` (bright lime)
- Border: `.stroke` with `borderDefault` → `#2A303A`
- Padding: `.horizontal(.md)` (16pt) + `.vertical(.sm)` (8pt)
- Corner Radius: `CornerRadius.md` (12pt)
- Icon Size: 18pt
- Icon Weight: `.medium`

**Visual Result:**
- ✅ More prominent (brand color)
- ✅ Matches QuotaDisplayView structure
- ⚠️ Different icon color (might clash with QuotaDisplayView star icon)

**Implementation:**
```swift
Button {
    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
        isSearchPresented = true
    }
} label: {
    Image(systemName: "magnifyingglass")
        .font(.system(size: 18, weight: .medium))
        .foregroundColor(DesignTokens.Brand.primary(themeManager.resolvedColorScheme))
}
.padding(.horizontal, DesignTokens.Spacing.md)
.padding(.vertical, DesignTokens.Spacing.sm)
.background(
    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
        .fill(DesignTokens.Surface.primary(themeManager.resolvedColorScheme))
)
.overlay(
    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
        .stroke(
            themeManager.resolvedColorScheme == .dark
                ? DesignTokens.Special.borderDefault(themeManager.resolvedColorScheme)
                : Color.clear,
            lineWidth: 0.5
        )
)
.accessibilityLabel("Search tools")
.accessibilityHint("Double tap to open search")
```

---

## Comparison Table

| Option | Background | Icon Color | Border | Consistency | Prominence | Visual Weight |
|--------|-----------|-----------|--------|-------------|------------|---------------|
| **Option 1** | Surface.primary | Text.secondary | Dark mode only | ✅ Perfect match | Medium | Medium |
| **Option 2** | Surface.secondary | Text.secondary | Dark mode only | ⚠️ Different shape | Medium | Medium |
| **Option 3** | None | Text.secondary | Always visible | ⚠️ Different style | Low | Light |
| **Option 4** | Surface.primary | Brand.primary | Dark mode only | ✅ Structure match | High | Medium |

---

## Recommendation

### **Option 1: Match QuotaDisplayView Style** ⭐

**Why:**
1. ✅ **Perfect Consistency:** Matches QuotaDisplayView exactly
2. ✅ **Professional:** Card-like appearance fits header design
3. ✅ **Balanced:** Not too prominent, not too subtle
4. ✅ **Theme-Aware:** Adapts properly to light/dark mode
5. ✅ **Accessible:** Clear visual target for tapping

**Visual Hierarchy:**
```
Header:
├── App Logo (left) - Brand element
├── [Empty Title Space]
└── Right Content:
    ├── Search Button (Option 1) - Card style, secondary color
    └── Credits Badge - Card style, secondary color
```

**Result:** Both right-side elements look like a cohesive set of badges/buttons.

---

## Implementation Notes

### Spacing Between Elements

**Current:**
```swift
HStack(spacing: DesignTokens.Spacing.md) {  // 16pt spacing
    Search Button
    QuotaDisplayView
}
```

**Recommendation:** Keep `DesignTokens.Spacing.md` (16pt) - provides good separation between card-style elements.

### Animation

**Current:** Spring animation with `response: 0.35, dampingFraction: 0.85`

**Recommendation:** Keep current animation - feels natural and matches iOS patterns.

### Haptic Feedback

**Current:** None

**Recommendation:** Add light haptic feedback for better UX:
```swift
Button {
    DesignTokens.Haptics.impact(.light)  // Add this
    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
        isSearchPresented = true
    }
}
```

---

## Design Tokens Reference

### Colors Used

| Token | Light Mode | Dark Mode | Usage |
|-------|-----------|-----------|-------|
| `Surface.primary` | `#F8F9FA` | `#1A1E24` | Background |
| `Text.secondary` | `#6B7280` | `#9CA3AF` | Icon color |
| `Brand.primary` | `#7DD321` | `#A4FC3C` | Icon color (Option 4) |
| `Special.borderDefault` | `#E5E7EB` | `#2A303A` | Border |

### Spacing Used

| Token | Value | Usage |
|-------|-------|-------|
| `Spacing.md` | 16pt | Horizontal padding, element spacing |
| `Spacing.sm` | 8pt | Vertical padding |

### Corner Radius Used

| Token | Value | Usage |
|-------|-------|-------|
| `CornerRadius.md` | 12pt | Rounded rectangle (Option 1, 3, 4) |
| `CornerRadius.round` | 50pt | Perfect circle (Option 2) |

---

## Testing Checklist

After implementation:

- [ ] Search button matches QuotaDisplayView style
- [ ] Light mode appearance is correct
- [ ] Dark mode appearance is correct
- [ ] Border appears only in dark mode (Option 1)
- [ ] Padding matches QuotaDisplayView
- [ ] Icon size is appropriate (18pt)
- [ ] Spacing between search and credits badge is correct (16pt)
- [ ] Animation feels smooth
- [ ] Haptic feedback works (if added)
- [ ] Accessibility labels are correct
- [ ] Button is tappable (44pt minimum touch target)

---

## Next Steps

1. **Review Options:** User selects preferred option
2. **Implement:** Apply chosen design
3. **Test:** Verify in both light and dark modes
4. **Refine:** Adjust spacing/sizing if needed
5. **Document:** Update design system docs if creating reusable component

---

**Plan Complete** ✅  
**Awaiting User Approval for Implementation**
