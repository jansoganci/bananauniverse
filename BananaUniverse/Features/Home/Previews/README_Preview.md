# Home Screen Redesign Preview

## 📱 How to View the Preview

This is a **preview-only file** that shows the redesigned home screen without modifying your actual app.

### Steps to View in Xcode:

1. **Open the file:**
   - Navigate to: `BananaUniverse/Features/Home/Previews/HomeView_Redesign_Preview.swift`

2. **Enable Canvas:**
   - In Xcode, press `⌥⌘↩` (Option + Command + Return) to show the Canvas
   - Or: View → Canvas → Show Canvas

3. **Select a Preview:**
   - Click on any preview (Light Mode, Dark Mode, iPhone SE, etc.)
   - The preview will render in the Canvas

4. **Interact with the Preview:**
   - Tap category cards to expand/collapse
   - Try the search bar
   - See the animations

### Available Previews:

- **Light Mode** - Shows the design in light theme
- **Dark Mode** - Shows the design in dark theme  
- **iPhone SE** - Small screen layout
- **iPhone 14 Pro** - Standard screen layout
- **iPhone 14 Pro Max** - Large screen layout

## 🎨 What You'll See:

- **Category Cards (2×2 Grid):** All 4 categories visible at once
- **Expandable Sections:** Tap a card to see tools below
- **Search Bar:** Functional search interface
- **Featured Carousel:** Placeholder for carousel section
- **Tool Grids:** Real tool cards using your existing `ToolCard` component

## ⚠️ Important:

- This file **does not affect your actual app**
- It's located in `Previews/` folder - separate from production code
- All components use your actual DesignTokens and styling
- Safe to preview, safe to delete if you don't like it

## 🔧 Customization:

If you want to modify the preview:
- Change `expandedCategories` initial state to pre-expand categories
- Adjust card sizes in `CategoryCard_Preview`
- Modify spacing or colors using DesignTokens

## 📝 Notes:

- Uses real tool data from `Tool.mainTools`, `Tool.seasonalTools`, etc.
- Uses actual `ToolCard` component for consistency
- Follows your existing design system completely

---

**Enjoy previewing your redesigned home screen! 🎉**

