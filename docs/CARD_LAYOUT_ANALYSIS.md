# Card Layout Analysis Report

**Date:** 2026-01-27  
**Issue:** Cards blending with background and appearing full-width in light mode

---

## Analysis Results

### Issue Type: **BOTH** (Color Issue + Spacing Issue)

---

## Root Cause

### Primary Issue: Color Token Mismatch

**Problem:** In light mode, `Surface.primary` (card background) is identical to `Background.primary` (screen background), both returning `#FFFFFF` (pure white). This causes cards to visually blend with the background, making them appear flat and indistinguishable.

**Why Dark Mode Works:**
- `Background.primary` (dark): `#121417` (very dark charcoal)
- `Surface.primary` (dark): `#1A1E24` (lighter dark gray)
- **Result:** Clear visual contrast and separation ✅

**Why Light Mode Fails:**
- `Background.primary` (light): `#FFFFFF` (pure white)
- `Surface.primary` (light): `#FFFFFF` (pure white)
- **Result:** No visual contrast, cards blend with background ❌

### Secondary Issue: Shadow Visibility

Even though `AppCard` applies `DesignTokens.Shadow.md`, shadows are less visible on white backgrounds in light mode, further reducing visual separation.

### Tertiary Issue: Padding Perception

While padding values are correctly set (16pt horizontal), the lack of color contrast makes the padding less visually apparent. Cards appear to touch edges even though they technically have padding.

---

## Evidence

### Color Token Values

| Token | Light Mode | Dark Mode | Contrast? |
|-------|------------|-----------|-----------|
| `Background.primary` | `#FFFFFF` | `#121417` | - |
| `Surface.primary` | `#FFFFFF` | `#1A1E24` | ❌ Light: Same<br>✅ Dark: Different |
| `Surface.secondary` | `#F8F9FA` | `#22272F` | ✅ Different in both |

**Key Finding:** `Surface.primary` should use `Surface.secondary` color (`#F8F9FA`) in light mode to provide visual separation.

### Padding Values

| Component | Horizontal Padding | Location |
|-----------|-------------------|----------|
| HomeView ScrollView VStack | **0pt** (none) | Line 65 |
| FeaturedCarouselView | 16pt (`Spacing.md`) | Line 77 |
| CategoryRow title | 16pt (`Spacing.md`) | Line 71 |
| CategoryRow ScrollView LazyHStack | 16pt (`Spacing.md`) | Line 86 |
| AppCard (ToolCard wrapper) | 16pt (`Spacing.md`) internal | UIComponents.swift:236 |

**Key Finding:** Padding is correctly applied, but visual perception is affected by color blending.

---

## Affected Components

### 1. ToolCard (via AppCard)
- **File:** `Core/Components/ToolCard/ToolCard.swift`
- **Issue:** Uses `AppCard` which applies `Surface.primary` background
- **Current Background:** `#FFFFFF` (same as screen background)
- **Impact:** Cards blend with background in light mode
- **Evidence:** Image shows "Anime Manga Style" and "Building Block Character" cards appearing flat against white background

### 2. CarouselCard (Featured Carousel)
- **File:** `Core/Components/FeaturedCarousel/CarouselCard.swift`
- **Issue:** Uses image background, but card container has no distinct background
- **Current Background:** Image-based (no card background color)
- **Impact:** Less affected, but still lacks visual separation from screen edges
- **Evidence:** Image shows carousel card extending close to screen edges

### 3. CategoryRow Container
- **File:** `Core/Components/CategoryRow/CategoryRow.swift`
- **Issue:** ScrollView LazyHStack has padding, but cards inside still appear edge-to-edge
- **Current Padding:** 16pt horizontal on LazyHStack
- **Impact:** Cards appear full-width despite padding
- **Evidence:** Image shows cards in "Trending Now" section appearing to touch screen edges

### 4. AppCard Base Component
- **File:** `Core/Design/Components/UIComponents.swift` (lines 189-243)
- **Issue:** Uses `Surface.primary` which is white in light mode
- **Current Background:** `DesignTokens.Surface.primary(colorScheme)` → `#FFFFFF` in light mode
- **Impact:** All cards using AppCard blend with background
- **Evidence:** This is the root component affecting all card types

---

## Component Inventory

### Cards Used on Home Screen:

1. **CarouselCard** (`Core/Components/FeaturedCarousel/CarouselCard.swift`)
   - Used in: FeaturedCarouselView
   - Background: Image-based (no card background)
   - Padding: Applied via FeaturedCarouselView wrapper (16pt)

2. **ToolCard** (`Core/Components/ToolCard/ToolCard.swift`)
   - Used in: CategoryRow horizontal scroll
   - Background: `AppCard` → `Surface.primary` (`#FFFFFF` in light mode)
   - Padding: Internal 16pt via AppCard

3. **FeaturedToolCard** (`Core/Components/FeaturedToolCard/FeaturedToolCard.swift`)
   - Not currently used on HomeView (used elsewhere)
   - Background: `AppCard` → `Surface.primary` (`#FFFFFF` in light mode)

4. **AppCard** (`Core/Design/Components/UIComponents.swift`)
   - Base wrapper for all cards
   - Background: `Surface.primary(colorScheme)`
   - Shadow: `Shadow.md` (less visible on white)

---

## Layout Analysis

### HomeView Structure:

```swift
ScrollView {
    VStack(spacing: DesignTokens.Spacing.md) {  // ← NO horizontal padding
        FeaturedCarouselView(...)
            .padding(.horizontal, DesignTokens.Spacing.md)  // ✅ Has padding
        
        ForEach(categories) {
            CategoryRow(...)  // ← NO explicit padding wrapper
        }
    }
    .padding(.top, DesignTokens.Spacing.sm)
    .padding(.bottom, DesignTokens.Spacing.lg)
    // ← NO horizontal padding on VStack
}
```

### CategoryRow Structure:

```swift
VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
    // Title
    HStack { ... }
        .padding(.horizontal, DesignTokens.Spacing.md)  // ✅ Title has padding
    
    // Horizontal Scroll
    ScrollView(.horizontal) {
        LazyHStack(spacing: DesignTokens.Spacing.md) {
            ForEach(tools) {
                ToolCard(...)  // ← Cards inside
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)  // ✅ ScrollView has padding
    }
}
```

**Finding:** Padding is correctly applied at the ScrollView level, but visual perception is compromised by color blending.

---

## Recommendation

### Fix Approach (DO NOT IMPLEMENT YET)

#### Option 1: Update Surface.primary for Light Mode (Recommended)

**Change:** Update `Surface.primary` in light mode to use `Surface.secondary` color (`#F8F9FA`)

**File:** `Core/Design/DesignTokens.swift` (line 44-46)

**Current:**
```swift
static func primary(_ colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color(hex: "1A1E24") : Color(hex: "FFFFFF")
}
```

**Proposed:**
```swift
static func primary(_ colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color(hex: "1A1E24") : Color(hex: "F8F9FA")  // Use secondary color for contrast
}
```

**Impact:** 
- ✅ Provides visual separation in light mode
- ✅ Maintains consistency (cards use Surface.primary)
- ✅ Minimal code change
- ⚠️ May require testing other screens that use Surface.primary

#### Option 2: Add Border to AppCard in Light Mode

**Change:** Add subtle border to AppCard when in light mode

**File:** `Core/Design/Components/UIComponents.swift` (cardContent computed property)

**Proposed:**
```swift
private var cardContent: some View {
    content
        .padding(DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                .fill(DesignTokens.Surface.primary(colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                        .stroke(
                            colorScheme == .light 
                                ? DesignTokens.Special.borderDefault(colorScheme) 
                                : Color.clear,
                            lineWidth: colorScheme == .light ? 1 : 0
                        )
                )
                .designShadow(DesignTokens.Shadow.md)
        )
}
```

**Impact:**
- ✅ Provides visual separation via border
- ✅ Keeps current color scheme
- ⚠️ Adds visual weight (border)
- ⚠️ More complex implementation

#### Option 3: Increase Shadow in Light Mode

**Change:** Use stronger shadow for cards in light mode

**File:** `Core/Design/Components/UIComponents.swift`

**Proposed:**
```swift
.designShadow(
    colorScheme == .light 
        ? DesignTokens.Shadow.lg  // Stronger shadow in light mode
        : DesignTokens.Shadow.md
)
```

**Impact:**
- ✅ Provides visual separation via shadow
- ✅ Minimal code change
- ⚠️ Shadows less effective on white backgrounds
- ⚠️ May not fully solve blending issue

---

## Recommended Solution

**Primary Fix:** **Option 1** - Update `Surface.primary` light mode color

**Rationale:**
1. Addresses root cause (color matching)
2. Minimal code change (single line)
3. Follows design system principles (Surface should contrast with Background)
4. Consistent with dark mode approach (different colors for contrast)

**Secondary Enhancement:** Consider adding Option 2 (border) if Option 1 alone doesn't provide sufficient visual separation.

---

## Testing Checklist (After Fix)

- [ ] Verify cards have visible separation in light mode
- [ ] Verify cards maintain proper spacing from screen edges
- [ ] Verify dark mode still works correctly
- [ ] Test on multiple device sizes (SE, Pro, Pro Max)
- [ ] Verify FeaturedCarouselView still looks correct
- [ ] Verify CategoryRow cards have proper spacing
- [ ] Check other screens using AppCard (Library, Profile, etc.)

---

## Additional Notes

### Why This Wasn't Caught Earlier

1. **Dark Mode Testing:** Most testing likely done in dark mode where contrast is naturally present
2. **Design System Assumption:** Assumed `Surface.primary` would differ from `Background.primary` by default
3. **Shadow Dependency:** Relied on shadows for separation, which are less effective on white backgrounds

### Design System Best Practice

**Rule:** `Surface.primary` should always provide visual contrast with `Background.primary` in both light and dark modes.

**Current State:** ✅ Dark mode follows rule, ❌ Light mode violates rule

---

**Analysis Complete**  
**Ready for Implementation Review**
