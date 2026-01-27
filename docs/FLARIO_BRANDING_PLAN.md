# Flario Branding Plan

**Date:** 2026-01-27
**Philosophy:** Ship fast, iterate based on feedback
**Brand Colors:** Electric Lime `#A4FC3C` + Charcoal `#121417`

---

## Current State

| Asset | Status | Location |
|-------|--------|----------|
| App Icon | EXISTS | `Assets.xcassets/AppIcon.appiconset/` (all sizes) |
| In-App Logo | EXISTS | `Assets.xcassets/AppLogo.imageset/banana.universe.icon.png` |
| Launch Screen | CONFIGURED | `Info.plist` references "LaunchScreen" |

**Decision Point:** Update existing assets or keep current?

---

## 1. App Icon Design

### Current iOS Requirements (2025-2026)

| Size | Usage | Required |
|------|-------|----------|
| 1024x1024 | App Store | YES (single source) |
| 180x180 | iPhone @3x | Auto-generated |
| 120x120 | iPhone @2x | Auto-generated |
| 60x60 | Spotlight | Auto-generated |

**Key Change:** iOS now auto-generates all sizes from single 1024x1024. Just provide one file.

### Design Principles (2026)

1. **One element** - People recognize icons in <1 second
2. **2-3 colors max** - Lime + Charcoal + White
3. **Bold shapes** - Clear at 29pt (smallest size)
4. **Liquid Glass ready** - iOS 26 adds glass effects to icons

### Concept Options

#### Option A: Abstract "F" (Recommended)
```
┌─────────────┐
│             │
│  ███████    │  ← Lime "F" shape
│  ██         │
│  █████      │
│  ██         │
│  ██         │
│             │
└─────────────┘
Background: Charcoal (#121417)
```
- **Pros:** Simple, scalable, brand-initial
- **Cons:** Generic
- **Time:** 30 min in Figma

#### Option B: Stylized Banana
```
┌─────────────┐
│      🍌     │  ← Lime curved shape
│    ╱       │     (banana silhouette)
│   ╱        │
│  ╱ ✨      │  ← Sparkle accent
│             │
└─────────────┘
Background: Charcoal (#121417)
```
- **Pros:** Memorable, ties to "Banana Universe" history
- **Cons:** Might look like food app
- **Time:** 1 hour in Figma

#### Option C: Magic Wand / Sparkles
```
┌─────────────┐
│     ✨      │
│    ✨ ✨    │  ← Lime sparkles
│   ✨   ✨   │
│  ✨         │
│             │
└─────────────┘
Background: Charcoal (#121417)
```
- **Pros:** Communicates "AI magic"
- **Cons:** Common in AI apps
- **Time:** 30 min in Figma

### Recommended: Option A (Abstract "F")

**Why:**
- Fastest to execute
- Scales perfectly at all sizes
- Unique identifier
- Can iterate later

### Tools to Use

| Tool | Cost | Speed | Quality |
|------|------|-------|---------|
| **Figma** | Free | Fast | Pro |
| Canva | Free | Fast | Good |
| AI (Midjourney/DALL-E) | $ | Fast | Variable |
| Sketch | $ | Medium | Pro |

**Recommendation:** Figma (free, fast, exports all sizes)

### Export Checklist

```
□ 1024x1024 PNG (no transparency, no alpha)
□ sRGB color space
□ Square, no rounded corners (Apple adds them)
□ Test at 29pt size - still recognizable?
```

---

## 2. In-App Logo

### Current Usage

```swift
// AppLogo.swift - Line 14-19
Image("AppLogo")
    .resizable()
    .aspectRatio(contentMode: .fit)
    .frame(width: size, height: size)  // Default 40pt
    .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
```

Appears in: **UnifiedHeaderBar** (top-left, 32pt)

### Requirements

| Attribute | Value |
|-----------|-------|
| Default size | 32-40pt |
| Format | PNG (current) or SVG |
| Background | Transparent |
| Colors | Lime on transparent |

### Design Options

#### Option 1: Same as App Icon (Current)
- Keep `banana.universe.icon.png`
- Consistency across app and home screen

#### Option 2: Wordmark Only
- "Flario" text in lime
- Modern, minimal
- Used by: Instagram, Netflix

#### Option 3: Icon + Wordmark
- Small icon + "Flario" text
- Already supported: `showText: true` parameter

### Recommended: Keep Current (Option 1)

**Why:**
- Already working
- Matches app icon
- No additional design work

### Format Decision

| Format | Pros | Cons |
|--------|------|------|
| PNG | Works now, simple | Fixed resolution |
| SVG | Scales perfectly | Requires conversion |
| PDF | Vector, Xcode native | Slightly larger |

**Recommendation:** Keep PNG for now. Convert to PDF vector later if needed.

---

## 3. Launch Screen

### iOS Best Practices (2026)

1. **Use Storyboard** - Required by Apple, auto-adapts to all devices
2. **Minimal content** - Logo + background only
3. **Match first screen** - Seamless transition
4. **No text** - Localization issues
5. **Fast perceived load** - Should feel instant

### Design Options

#### Option A: Minimalist (Recommended)
```
┌─────────────────────────────────┐
│                                 │
│                                 │
│                                 │
│            [LOGO]               │  ← Centered app icon
│                                 │
│                                 │
│                                 │
└─────────────────────────────────┘
Background: Charcoal (#121417)
```

#### Option B: Branded
```
┌─────────────────────────────────┐
│                                 │
│                                 │
│            [LOGO]               │
│           Flario                │  ← Lime text
│                                 │
│        ═══════════              │  ← Subtle lime accent
│                                 │
└─────────────────────────────────┘
Background: Charcoal (#121417)
```

#### Option C: Animated (Advanced)
- Logo fades in
- Lime pulse effect
- Transitions smoothly to home

### Recommended: Option A (Minimalist)

**Why:**
- Fastest to implement
- Apple-recommended
- Works on all devices
- Can enhance later

### Implementation

**Method 1: Storyboard (Current Standard)**
```
1. Create LaunchScreen.storyboard
2. Add ImageView (centered)
3. Set background color: #121417
4. Add constraints: Center X, Center Y
5. Set image: AppLogo (or AppIcon)
```

**Method 2: Info.plist (Simple)**
```xml
<key>UILaunchScreen</key>
<dict>
    <key>UIColorName</key>
    <string>LaunchBackground</string>
    <key>UIImageName</key>
    <string>AppLogo</string>
</dict>
```

### Animation Consideration

**Skip for V1.** Animated launch screens:
- Require custom code
- Add complexity
- Apple discourages (prefer fast loading)
- Can add in V2 if desired

---

## 4. Implementation Roadmap

### Phase 1: Quick Win (1-2 hours)

**Goal:** Ship something functional today

| Task | Time | Tool |
|------|------|------|
| 1.1 Audit current icon | 15 min | Preview.app |
| 1.2 Decide: keep or redesign? | 5 min | Decision |
| 1.3 If redesign: Create in Figma | 45 min | Figma |
| 1.4 Export 1024x1024 | 5 min | Figma |
| 1.5 Replace in Xcode | 10 min | Xcode |
| 1.6 Test on device | 15 min | Xcode |

**Deliverable:** Updated app icon (if needed)

### Phase 2: Launch Screen (1 hour)

**Goal:** Branded launch experience

| Task | Time | Tool |
|------|------|------|
| 2.1 Create LaunchScreen.storyboard | 20 min | Xcode |
| 2.2 Add logo ImageView | 10 min | Xcode |
| 2.3 Set charcoal background | 5 min | Xcode |
| 2.4 Add constraints | 10 min | Xcode |
| 2.5 Test on multiple devices | 15 min | Simulator |

**Deliverable:** Branded launch screen

### Phase 3: Polish (Optional, 1-2 hours)

**Goal:** Refinements based on feedback

| Task | Time | Tool |
|------|------|------|
| 3.1 A/B test icon variants | 30 min | App Store Connect |
| 3.2 Add dark/light variants | 30 min | Figma + Xcode |
| 3.3 Create marketing assets | 30 min | Figma |

**Deliverable:** Optimized branding

---

## Quick Reference: Color Codes

| Color | Hex | RGB | Usage |
|-------|-----|-----|-------|
| Electric Lime | `#A4FC3C` | 164, 252, 60 | Primary accent |
| Charcoal | `#121417` | 18, 20, 23 | Background |
| White | `#FFFFFF` | 255, 255, 255 | Text on dark |

---

## Quick Reference: File Locations

```
BananaUniverse/
├── Assets.xcassets/
│   ├── AppIcon.appiconset/
│   │   └── Icon-App-1024x1024@1x.png  ← Replace this
│   └── AppLogo.imageset/
│       └── banana.universe.icon.png   ← In-app logo
├── LaunchScreen.storyboard            ← Create this
└── Info.plist                         ← Already configured
```

---

## Decision Matrix

| Question | Answer | Action |
|----------|--------|--------|
| Is current icon good enough? | Check visually | If yes, skip Phase 1 |
| Need custom launch screen? | Yes (branding) | Do Phase 2 |
| Need animation? | No (V1) | Skip for now |
| Need A/B testing? | Later | Phase 3 |

---

## Tools & Resources

### Free Tools
- [Figma](https://figma.com) - Icon design
- [Squoosh](https://squoosh.app) - Image optimization
- [IconKitchen](https://icon.kitchen) - Quick icon generator
- [App Icon Generator](https://appicon.co) - All sizes from 1024

### AI Tools (Optional)
- Midjourney - Concept generation
- DALL-E - Quick iterations
- Recraft - Vector icons

### References
- [Apple HIG: App Icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- [iOS App Icon Sizes Guide](https://splitmetrics.com/blog/guide-to-mobile-icons/)
- [App Icon Design Tips 2026](https://www.apptweak.com/en/aso-blog/how-to-design-an-app-icon)

---

## Summary

| Asset | Action | Time | Priority |
|-------|--------|------|----------|
| **App Icon** | Audit → Decide → Maybe redesign | 1-2h | HIGH |
| **In-App Logo** | Keep current | 0h | DONE |
| **Launch Screen** | Create minimal storyboard | 1h | MEDIUM |

**Total Time:** 2-3 hours for V1

**Philosophy Reminder:**
> "Real artists ship." - Steve Jobs

Don't overthink. Ship V1 today, iterate tomorrow.

---

*Last Updated: 2026-01-27*

Sources:
- [MobileAction App Icon Guide 2026](https://www.mobileaction.co/guide/app-icon-guide/)
- [SplitMetrics iOS Icon Requirements](https://splitmetrics.com/blog/guide-to-mobile-icons/)
- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- [ASOMobile App Icon Trends 2025](https://asomobile.net/en/blog/app-icon-trends-and-best-practices-2025/)
