# Phase 5: Brand Assets Creation Guide

**Status:** Configuration Complete ✅ | Asset Design Required ⏳  
**Last Updated:** 2026-01-27

---

## ✅ Completed Configuration

1. **AccentColor Updated** ✅
   - Updated to Electric Lime (#A4FC3C)
   - File: `BananaUniverse/Assets.xcassets/AccentColor.colorset/Contents.json`

2. **App Display Name Updated** ✅
   - Changed from "Banana Universe" to "Flario"
   - File: `BananaUniverse/Info.plist` → `CFBundleDisplayName`

3. **AppLogo.imageset Configuration Updated** ✅
   - Updated Contents.json to reference new logo filenames
   - File: `BananaUniverse/Assets.xcassets/AppLogo.imageset/Contents.json`
   - **Note:** Actual image files need to be created and added

---

## ⏳ Required Asset Design Work

### 1. App Icon Design

**Location:** `BananaUniverse/Assets.xcassets/AppIcon.appiconset/`

**Required Sizes:**

| Size | Filename | Scale | Purpose |
|------|----------|-------|---------|
| 20×20 | Icon-App-20x20@2x.png | 2x | Notification (40×40px) |
| 20×20 | Icon-App-20x20@3x.png | 3x | Notification (60×60px) |
| 29×29 | Icon-App-58x58@2x.png | 2x | Settings (58×58px) |
| 29×29 | Icon-App-87x87@3x.png | 3x | Settings (87×87px) |
| 40×40 | Icon-App-80x80@2x.png | 2x | Spotlight (80×80px) |
| 40×40 | Icon-App-120x120@3x.png | 3x | Spotlight (120×120px) |
| 60×60 | Icon-App-60x60@2x.png | 2x | App (120×120px) |
| 60×60 | Icon-App-60x60@3x.png | 3x | App (180×180px) |
| 1024×1024 | Icon-App-1024x1024@1x.png | 1x | App Store (1024×1024px) |

**Design Requirements:**
- **Theme:** Flario brand identity (spark/flare icon concept)
- **Primary Color:** Electric Lime (#A4FC3C)
- **Background:** Charcoal (#1A1E24) or transparent
- **Style:** Modern, energetic, AI-focused
- **Format:** PNG with transparency
- **Color Profile:** sRGB

**Design Notes:**
- Icon should be recognizable at small sizes (20×20pt)
- Avoid fine details that won't scale well
- Consider rounded corners (iOS automatically applies mask)
- Test on both light and dark backgrounds

---

### 2. App Logo Design

**Location:** `BananaUniverse/Assets.xcassets/AppLogo.imageset/`

**Required Sizes:**

| Scale | Filename | Actual Size |
|-------|----------|-------------|
| 1x | flario-logo@1x.png | Base size (e.g., 40×40px) |
| 2x | flario-logo@2x.png | 2× base size (e.g., 80×80px) |
| 3x | flario-logo@3x.png | 3× base size (e.g., 120×120px) |

**Design Requirements:**
- **Theme:** Flario logo mark/icon
- **Primary Color:** Electric Lime (#A4FC3C)
- **Style:** Clean, modern, works well with "Flario" text
- **Format:** PNG with transparency
- **Usage:** Used in AppLogo component, headers, navigation

**Design Notes:**
- Should complement the "Flario" text when shown together
- Should work on both light and dark backgrounds
- Consider a simplified version for small sizes
- Can be the same as app icon or a variation

---

### 3. Splash Screen (Optional)

**Location:** `BananaUniverse/LaunchScreen.storyboard` (if exists)

**Design Requirements:**
- **Background:** Use Flario background colors
- **Logo:** Center Flario logo
- **Colors:** Electric Lime accent, Charcoal background
- **Animation:** Optional subtle fade-in

**Note:** If using LaunchScreen.storyboard, update colors to match Flario palette.

---

## Design Specifications

### Color Palette Reference

**Primary Brand Color:**
- Electric Lime: `#A4FC3C` (RGB: 164, 252, 60)

**Background Colors:**
- Dark Mode Primary: `#121417`
- Dark Mode Secondary: `#1A1E24`
- Light Mode Primary: `#FFFFFF`
- Light Mode Secondary: `#F9FAFB`

**Accent Colors:**
- Ice Blue: `#3B82F6`
- Success: `#10B981`
- Error: `#EF4444`
- Warning: `#F59E0B`

### Design Principles

1. **Energetic & Modern:** Reflects AI-powered photo editing
2. **Bold & Confident:** Electric Lime as primary accent
3. **Clean & Professional:** Avoid clutter, focus on clarity
4. **Scalable:** Works at all sizes from 20pt to 1024pt

---

## Asset Delivery Checklist

### App Icon
- [ ] Design app icon concept
- [ ] Export all 9 required sizes
- [ ] Test on device (light/dark mode)
- [ ] Verify App Store 1024×1024 version
- [ ] Replace files in `AppIcon.appiconset/`

### App Logo
- [ ] Design logo mark/icon
- [ ] Export @1x, @2x, @3x versions
- [ ] Test in AppLogo component
- [ ] Verify on light/dark backgrounds
- [ ] Replace files in `AppLogo.imageset/`

### Splash Screen (if applicable)
- [ ] Update LaunchScreen.storyboard colors
- [ ] Add Flario logo
- [ ] Test launch animation

---

## File Structure After Completion

```
BananaUniverse/Assets.xcassets/
├── AppIcon.appiconset/
│   ├── Contents.json ✅ (already updated)
│   ├── Icon-App-20x20@2x.png ⏳ (needs design)
│   ├── Icon-App-20x20@3x.png ⏳ (needs design)
│   ├── Icon-App-58x58@2x.png ⏳ (needs design)
│   ├── Icon-App-87x87@3x.png ⏳ (needs design)
│   ├── Icon-App-80x80@2x.png ⏳ (needs design)
│   ├── Icon-App-120x120@3x.png ⏳ (needs design)
│   ├── Icon-App-60x60@2x.png ⏳ (needs design)
│   ├── Icon-App-60x60@3x.png ⏳ (needs design)
│   └── Icon-App-1024x1024@1x.png ⏳ (needs design)
│
├── AppLogo.imageset/
│   ├── Contents.json ✅ (already updated)
│   ├── flario-logo@1x.png ⏳ (needs design)
│   ├── flario-logo@2x.png ⏳ (needs design)
│   └── flario-logo@3x.png ⏳ (needs design)
│
└── AccentColor.colorset/
    └── Contents.json ✅ (already updated to Electric Lime)
```

---

## Next Steps

1. **Design Phase:** Create app icon and logo designs
2. **Export Phase:** Export all required sizes
3. **Integration Phase:** Add files to asset catalogs
4. **Testing Phase:** Test on device and simulator
5. **Verification:** Ensure all assets display correctly

---

## Design Tools Recommendations

- **Figma:** For vector design and export
- **Sketch:** For macOS-based design
- **Adobe Illustrator:** For professional vector work
- **ImageOptim:** For PNG optimization
- **Asset Catalog Generator:** For batch export

---

## Notes

- All configuration files have been updated
- The app will use "Flario" as the display name
- AccentColor is set to Electric Lime
- Once image assets are added, the rebrand will be complete
- Test thoroughly on actual devices before App Store submission

---

**Phase 5 Status:** Configuration Complete ✅ | Asset Design Required ⏳
