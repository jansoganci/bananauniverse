# Profile Preview

## 📱 How to View the Preview

This is a **preview-only file** that shows the redesigned modern profile screen without modifying your actual app.

### Steps to View in Xcode:

1. **Open the file:**
   - Navigate to: `BananaUniverse/Features/Profile/Previews/ProfilePreview.swift`
   - Or use Cmd+Shift+O and type "ProfilePreview"

2. **Enable Canvas:**
   - In Xcode, press `⌥⌘↩` (Option + Command + Return) to show the Canvas
   - Or: View → Canvas → Show Canvas

3. **Select a Preview:**
   - Click on "Profile Preview - Light" or "Profile Preview - Dark"
   - The preview will render in the Canvas

4. **Interact with the Preview:**
   - Tap theme toggle to cycle through themes
   - Tap notification toggle to enable/disable
   - All buttons have mock actions

### If Preview Doesn't Work:

1. **Close and reopen Xcode**
2. **Clean build folder:** Product → Clean Build Folder (Cmd+Shift+K)
3. **Build the project:** Product → Build (Cmd+B)
4. **Try Canvas again:** ⌥⌘↩

### Available Previews:

- **Light Mode** - Shows the design in light theme
- **Dark Mode** - Shows the design in dark theme

## 🎨 What You'll See:

- **Account Section:** Username, Email, Subscription Status
- **Settings Section:** Theme (with working toggle!), Language, Notifications
- **Support Section:** Help, Privacy Policy, Terms, AI Disclosure, Restore Purchases
- **Modern Design:** SF Symbols, rounded cards, proper spacing
- **Apple HIG Compliant:** Follows Human Interface Guidelines

## ⚠️ Important:

- This file **does not affect your actual app**
- It's located in `Previews/` folder - separate from production code
- All components use your actual DesignTokens and ThemeManager
- Safe to preview, safe to delete if you don't like it

## 🔧 Customization:

If you want to modify the preview:
- Change mock data in the `ProfilePreview` struct
- Adjust spacing or colors using DesignTokens
- Add/remove sections as needed

## 📝 Notes:

- Uses real ThemeManager for theme switching
- Uses actual DesignTokens for consistency
- Follows your existing design system completely
- Mock data only - no backend dependencies

---

**Enjoy previewing your redesigned profile screen! 🎉**

