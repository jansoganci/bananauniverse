# Phase 0 Pre-Migration Audit Report

**Date:** 2026-01-26  
**Status:** Post-Phase 0 Completion Audit

## Summary

This audit identifies remaining hardcoded colors and design elements that were missed during Phase 0 implementation.

---

## 🔴 CRITICAL Issues (Must Fix Before Migration)

### 1. Hardcoded Colors in Core Components

#### ChatView.swift
- **Line 692:** `Color.black.opacity(0.1)` → Should use `DesignTokens.Special.borderDefault(colorScheme)`
- **Line 328:** `Color(hex: "9D7FD6")` → Already fixed in previous pass, but verify

#### ImageProcessingView.swift
- **Line 409:** `.foregroundColor(.red)` → Should use `DesignTokens.Semantic.error(colorScheme)`
- **Line 509:** `Color.black.opacity(0.6)` → Should use `DesignTokens.Surface.overlay(colorScheme)`
- **Line 780:** `.foregroundColor(.red)` → Should use `DesignTokens.Semantic.error(colorScheme)`

#### ResultView.swift
- **Line 156:** `.foregroundColor(.green)` → Should use `DesignTokens.Semantic.success(colorScheme)`
- **Line 161:** `Color.green` → Should use `DesignTokens.Semantic.success(colorScheme)`

#### ImageDetailView.swift
- **Line 25:** `Color.black` → Should use `DesignTokens.Surface.overlay(colorScheme)`
- **Line 41, 69, 82:** `Color.black.opacity(0.5)` → Should use `DesignTokens.Surface.overlay(colorScheme)`
- **Line 62:** `.foregroundColor(.green)` → Should use `DesignTokens.Semantic.success(colorScheme)`

#### BeforeAfterSlider.swift
- **Line 86:** `Color.white` → Should use `DesignTokens.Surface.primary(colorScheme)`
- **Line 102:** `Color.white.opacity(0.8)` → Should use `DesignTokens.Surface.primary(colorScheme).opacity(0.8)`
- **Line 135:** `Color.black` (preview) → Should use `DesignTokens.Background.primary(.dark)`

### 2. Hardcoded Brand.primary(.light) in Feature Views

#### Authentication Views
- **SignInView.swift:** 3 instances of `Brand.primary(.light)` → Should use `Brand.primary(colorScheme)`
- **QuickAuthView.swift:** 3 instances of `Brand.primary(.light)` → Should use `Brand.primary(colorScheme)`
- **LoginView.swift:** 2 instances of `Brand.primary(.light)` → Should use `Brand.primary(colorScheme)`

#### Other Feature Views
- **AI_Disclosure_View.swift:** 1 instance → Should use `Brand.primary(colorScheme)`
- **ErrorView.swift:** 1 instance → Should use `Brand.primary(colorScheme)`
- **ProfileRow.swift:** 1 instance of `Brand.primary(.dark)` → Should use `Brand.primary(colorScheme)`

---

## 🟡 MEDIUM Priority Issues (Should Fix)

### 3. Hardcoded Colors in Onboarding (Lower Priority)
- **OnboardingScreen1.swift:** `Color.black` background
- **OnboardingScreen2.swift:** `Color.black` background
- **OnboardingScreen3.swift:** `Color.black` background, `.orange`, `.blue`
- **OnboardingScreen4.swift:** `Color.black` background, `.orange`, `.blue`
- **OnboardingStepCard.swift:** `.orange`, `.blue`, `.purple`, `Color.black` background

**Note:** These might be intentional for onboarding design. Review with design team.

### 4. Debug/Preview Views (Low Priority)
- **PaymentDebugView.swift:** Multiple `.orange`, `.green`, `.red` instances
- **CarouselCard.swift:** `Color.black` in preview
- Various preview files with hardcoded colors

**Note:** Debug views are less critical, but should be fixed for consistency.

---

## 🟢 LOW Priority Issues (Can Fix Later)

### 5. Hardcoded Spacing Values
- **94 instances** across codebase
- Examples: `.padding(.horizontal, 12)`, `.padding(.vertical, 8)`, `.padding(20)`
- **Recommendation:** Fix during Phase 1 or Phase 2 when updating spacing system

### 6. Hardcoded Corner Radius Values
- **70 instances** across codebase
- Examples: `.cornerRadius(12)`, `.cornerRadius(8)`, `RoundedRectangle(cornerRadius: 16)`
- **Recommendation:** Some might be intentional. Review during Phase 1.

### 7. Hardcoded Font Sizes
- **170 instances** across codebase
- Examples: `.font(.system(size: 16))`, `.font(.system(size: 20, weight: .bold))`
- **Recommendation:** Lower priority. Can be addressed during typography system update.

---

## ✅ Already Fixed (DesignTokens.swift)

The following are **intentional** and should NOT be changed:
- All `Color(hex:)` instances in `DesignTokens.swift` (these define the tokens)
- All `Color.white`, `Color.black` in `DesignTokens.swift` (these are token definitions)

---

## 📋 Action Items

### Immediate (Before Phase 1):
1. ✅ Fix ChatView.swift line 692
2. ✅ Fix ImageProcessingView.swift (3 instances)
3. ✅ Fix ResultView.swift (2 instances)
4. ✅ Fix ImageDetailView.swift (5 instances)
5. ✅ Fix BeforeAfterSlider.swift (3 instances)
6. ✅ Fix Authentication views (8 instances)
7. ✅ Fix AI_Disclosure_View.swift (1 instance)
8. ✅ Fix ErrorView.swift (1 instance)
9. ✅ Fix ProfileRow.swift (1 instance)

### Medium Priority (During Phase 1):
- Review and fix Onboarding screens
- Fix PaymentDebugView.swift

### Low Priority (Future):
- Standardize spacing values
- Standardize corner radius values
- Standardize font sizes

---

## Files Requiring Immediate Attention

1. `Features/Chat/Views/ChatView.swift`
2. `Features/ImageProcessing/Views/ImageProcessingView.swift`
3. `Features/ImageProcessing/Views/ResultView.swift`
4. `Features/Library/Views/ImageDetailView.swift`
5. `Features/Onboarding/Components/BeforeAfterSlider.swift`
6. `Features/Authentication/Views/SignInView.swift`
7. `Features/Authentication/Views/QuickAuthView.swift`
8. `Features/Authentication/Views/LoginView.swift`
9. `Features/Profile/Views/AI_Disclosure_View.swift`
10. `Features/Library/Views/Components/ErrorView.swift`
11. `Core/Components/ProfileRow/ProfileRow.swift`

---

**Total Critical Issues Found:** 25  
**Total Medium Priority Issues:** ~15  
**Total Low Priority Issues:** ~334
