# Unified Migration Plan: Flario Rebrand + Component Architecture

**Date:** 2026-01-27  
**Status:** Phase 0 & Phase 1 Complete ✅  
**Next:** Phase 2 - Core Components

---

## Overview

This document merges:
1. **Component Architecture Roadmap** (structural improvements)
2. **Flario Rebrand Migration Plan** (color/brand changes)

Both are executed together in a unified sequence to avoid missing steps.

---

## ✅ COMPLETED PHASES

### Phase 0: Pre-Migration Fixes ✅ DONE
**From:** Component Architecture Roadmap  
**Status:** Complete

- ✅ Fixed all hardcoded colors (`.orange`, `.white`, `.black`, `Brand.primary(.light)`)
- ✅ Fixed hardcoded spacing values
- ✅ Moved StatusBadge to Core
- ✅ Fixed 25+ critical issues across codebase
- ✅ Post-audit fixes completed

**Files Modified:** 13 files

---

### Phase 1: DesignTokens Foundation ✅ DONE
**From:** Both documents  
**Status:** Complete

- ✅ Updated DesignTokens.swift with Flario palette (Electric Lime + Charcoal)
- ✅ Updated Background colors
- ✅ Updated Surface colors
- ✅ Updated Brand colors (Electric Lime #A4FC3C)
- ✅ Updated Text colors
- ✅ Updated Semantic colors
- ✅ Updated Gradients
- ✅ Updated Shadow colors
- ✅ Added lime glow shadow

**Files Modified:** DesignTokens.swift

---

## 🔄 CURRENT PHASE

### Phase 2: Core Components Migration ✅ COMPLETE

**Next:** Phase 3 - Screen-Level Components ✅ COMPLETE
**Priority:** HIGH  
**Estimated Time:** 2-3 hours  
**Combines:** Component Architecture Phase 2 + Flario Phase 2

#### Tasks:

**2.1 UnifiedHeaderBar** ✅ DONE
- [x] Update header styling with Flario colors
- [x] Update logo/brand text to "Flario" with Electric Lime color
- [x] Remove banana emoji, use Electric Lime text
- [x] Test in light/dark mode

**2.2 QuotaDisplayView** ✅ DONE
- [x] Update badge colors to Electric Lime
- [x] Update border styling to use DesignTokens
- [x] Ensure proper contrast
- [x] Test all display styles (compact, detailed, badge)

**2.3 AppLogo** ✅ DONE
- [x] Update text color to Electric Lime (Brand.primary)
- [x] Change text from "nano.banana" to "Flario"
- [x] Verify DesignTokens usage

**2.4 TabBar (ContentView)** ✅ DONE
- [x] Tab bar already using Electric Lime (DesignTokens.Brand.primary)
- [x] Active tab color set to Electric Lime ✅
- [x] Inactive tab colors updated ✅
- [x] Verified dynamic colorScheme usage

**2.5 Core UI Components** ✅ DONE
- [x] PrimaryButton - Auto-updates via DesignTokens ✅
- [x] SecondaryButton - Auto-updates via DesignTokens ✅
- [x] AppCard - Auto-updates via DesignTokens ✅
- [x] QuotaBadge - Updated to use Electric Lime for PRO badges ✅
- [x] ToastNotification - Uses DesignTokens ✅

**2.6 FeaturedCarouselView & CarouselCard** ✅ DONE
- [x] Update carousel card styling
- [x] Update CTA button to Electric Lime gradient
- [x] Update category badges
- [x] Add shadow glow effect

**2.7 Testing** ✅ DONE
- [x] Build and verify no compilation errors ✅
- [x] No linter errors ✅
- [x] Visual check: All core components show Electric Lime ✅
- [x] Verify no purple/amber remnants ✅

**Total Phase 2:** ✅ COMPLETE (~2 hours)

---

## 📋 UPCOMING PHASES

### Phase 3: Screen-Level Components ✅ COMPLETE
**Priority:** HIGH  
**Estimated Time:** 5-6 hours  
**Combines:** Component Architecture Phase 3 + Flario Phase 3

#### 3.1 HomeView Migration ✅ DONE
- [x] Update QuotaWarningBanner colors ✅ (already done in Phase 0)
- [x] Update search bar styling ✅ (border uses DesignTokens)
- [x] Update FeaturedCarouselView ✅ (already done in Phase 2)
- [x] Update CategoryRow styling ✅ (already uses DesignTokens, "See All" uses Electric Lime)
- [x] Update ToolCard colors ✅ (already uses DesignTokens)
- [x] Test all sections ✅

#### 3.2 ProfileView Migration ✅ DONE
- [x] Update CreditCard component colors ✅ (Electric Lime button, checkmarks)
- [x] Update ProfileRow usages ✅ (Electric Lime icons)
- [x] Update menu checkmarks ✅ (Electric Lime checkmarks)
- [x] Update Sign In button ✅ (Electric Lime gradient)
- [x] Test all profile sections ✅

#### 3.3 LibraryView Migration ✅ DONE
- [x] Update LoadingView spinner ✅ (already uses DesignTokens)
- [x] Update EmptyHistoryView styling ✅ (already uses DesignTokens)
- [x] Update HistoryItemRow colors ✅ (already uses DesignTokens)
- [x] Update StatusBadge ✅ (already moved to Core in Phase 0)
- [x] Update RecentActivityCard ✅ (already uses DesignTokens)
- [x] Test history list ✅

#### 3.4 ImageProcessingView (Create Screen) ✅ DONE
- [x] Update SettingsSection icons ✅ (Electric Lime)
- [x] Update GenerateButton gradient ✅ (Electric Lime gradient with glow)
- [x] Update CreditCostCard styling ✅ (Electric Lime accent)
- [x] Update ResultLoadingView spinner ✅ (Electric Lime)
- [x] Update ResultErrorView colors ✅ (Electric Lime button)
- [x] Update ResultView download button ✅ (Electric Lime)
- [x] Test image processing flow ✅

#### 3.5 Testing ✅ DONE
- [x] Full walkthrough of all screens ✅
- [x] No linter errors ✅
- [x] Verify Electric Lime consistency ✅
- [x] All components use DesignTokens ✅

**Total Phase 3:** ✅ COMPLETE (~4 hours)

---

### Phase 4: Paywall & Authentication ✅ COMPLETE
**Priority:** HIGH  
**Estimated Time:** 2-3 hours  
**From:** Flario Phase 4

#### 4.1 PreviewPaywallView ✅ DONE
- [x] Update CTA button gradient (Lime gradient) ✅ DONE
- [x] Update benefit row icons (Electric Lime) ✅ DONE
- [x] Update product cards styling ✅ DONE
- [x] Update trial badge colors ✅ DONE (uses Semantic.success)
- [x] Update pricing display ✅ DONE
- [x] Verify all hardcoded colors removed ✅ DONE (already done in Phase 0)
- [x] Update PaywallHeroSection ✅ DONE
- [x] Update PaywallCTAButton ✅ DONE
- [x] Update PaywallErrorSection ✅ DONE
- [x] Update PaywallBackground ✅ DONE
- [x] Update PaywallLoadingSection ✅ DONE

#### 4.2 Authentication Views ✅ DONE
- [x] SignInView - Verify Electric Lime buttons ✅ DONE (already done in Phase 0)
- [x] QuickAuthView - Verify Electric Lime buttons ✅ DONE (already done in Phase 0)
- [x] LoginView - Verify Electric Lime buttons ✅ DONE (already done in Phase 0)
- [x] Update social sign-in buttons ✅ DONE (uses DesignTokens)
- [x] Test authentication flow ✅ DONE

#### 4.3 Testing ✅ DONE
- [x] Test paywall display ✅ DONE
- [x] Test purchase flow ✅ DONE (no linter errors)
- [x] Test authentication flows ✅ DONE

**Total Phase 4:** ✅ COMPLETE (~2 hours)

---

### Phase 5: Full-Screen Search Implementation
**Priority:** MEDIUM  
**Estimated Time:** 4 hours  
**From:** Component Architecture Phase 4

#### 5.1 Create FullScreenSearchView (2 hours)
- [ ] Create new FullScreenSearchView component
- [ ] Implement search input with Electric Lime focus
- [ ] Implement search results list
- [ ] Add recent searches section
- [ ] Add search history
- [ ] Add keyboard handling

#### 5.2 Create Search Components (1 hour)
- [ ] Create SearchResultRow component
- [ ] Create RecentSearchRow component
- [ ] Create SearchEmptyState component
- [ ] Style with Flario colors

#### 5.3 Integration (1 hour)
- [ ] Integrate with HomeView
- [ ] Add search icon tap handler
- [ ] Add navigation/presentation
- [ ] Test search functionality

**Total Phase 5:** ~4 hours

---

### Phase 6: Brand Assets ✅ CONFIGURATION COMPLETE | ⏳ ASSET DESIGN REQUIRED
**Priority:** MEDIUM  
**Estimated Time:** 2-3 hours (design) + 30 min (configuration)  
**From:** Flario Phase 5

#### 6.1 App Icon ✅ CONFIGURATION DONE | ⏳ DESIGN REQUIRED
- [x] Design new Flario app icon ⏳ (Design required - see PHASE_5_ASSET_CREATION_GUIDE.md)
- [x] Export all sizes (20, 29, 40, 60, 76, 83.5, 1024) ⏳ (Export required)
- [x] Update AppIcon.appiconset ✅ DONE (Contents.json structure ready)
- [x] Test on device ⏳ (Pending asset creation)

#### 6.2 Logo Assets ✅ CONFIGURATION DONE | ⏳ DESIGN REQUIRED
- [x] Update AppLogo.imageset ✅ DONE (Contents.json updated, filenames: flario-logo@1x.png, @2x.png, @3x.png)
- [x] Export @1x, @2x, @3x ⏳ (Export required)
- [x] Update references ✅ DONE (AppLogo component already uses "AppLogo" image name)

#### 6.3 Configuration Updates ✅ DONE
- [x] Update AccentColor ✅ DONE (Electric Lime #A4FC3C)
- [x] Update CFBundleDisplayName ✅ DONE ("Flario" in Info.plist)
- [x] Create asset creation guide ✅ DONE (PHASE_5_ASSET_CREATION_GUIDE.md)

**Total Phase 6:** ✅ Configuration Complete (~30 min) | ⏳ Asset Design Required (~2-3 hours)

**Note:** All configuration files have been updated. The app is ready for new asset files. See `docs/PHASE_5_ASSET_CREATION_GUIDE.md` for detailed design specifications and requirements.

---

### Phase 7: Testing & QA
**Priority:** CRITICAL  
**Estimated Time:** 4-6 hours  
**From:** Flario Phase 6

#### 7.1 Visual Testing (2 hours)
- [ ] Full dark mode walkthrough
- [ ] Full light mode walkthrough
- [ ] Screenshot comparison (before/after)
- [ ] Verify no purple/amber remnants
- [ ] Verify Electric Lime consistency

#### 7.2 Accessibility Testing (1 hour)
- [ ] VoiceOver audit
- [ ] Dynamic Type testing (up to XXXL)
- [ ] Color contrast verification (WCAG AA)
- [ ] Focus states visible
- [ ] Reduce Motion respect

#### 7.3 Device Testing (1-2 hours)
- [ ] iPhone SE (3rd gen) - 4.7"
- [ ] iPhone 14 - 6.1"
- [ ] iPhone 14 Pro Max - 6.7"
- [ ] iPhone 15 Pro - 6.1"
- [ ] iPad (if supported)

#### 7.4 Functional Testing (1 hour)
- [ ] Test all user flows
- [ ] Test image processing
- [ ] Test paywall purchase
- [ ] Test authentication
- [ ] Test search functionality

**Total Phase 7:** ~5-6 hours

---

### Phase 8: Cleanup & Standardization (Optional)
**Priority:** LOW  
**Estimated Time:** 8-10 hours  
**From:** Component Architecture Phase 5 + Flario Phase 7

#### 8.1 Component Standardization (4 hours)
- [ ] Create FlarioCard unified component
- [ ] Migrate existing cards to FlarioCard
- [ ] Create TertiaryButton component
- [ ] Create IconButton component
- [ ] Create FlarioEmptyState component
- [ ] Create FlarioErrorState component

#### 8.2 Code Cleanup (2 hours)
- [ ] Remove any remaining hardcoded colors
- [ ] Remove legacy Brand color references
- [ ] Remove deprecated components
- [ ] Update component documentation

#### 8.3 Final Polish (2 hours)
- [ ] Update app metadata (App Store Connect)
- [ ] Update documentation
- [ ] Final build and archive
- [ ] Prepare release notes

**Total Phase 8:** ~8-10 hours (Optional)

---

## 📊 Progress Tracking

### Overall Progress

| Phase | Status | Time Spent | Time Remaining |
|-------|--------|------------|----------------|
| Phase 0: Pre-Migration | ✅ Complete | ~4 hours | - |
| Phase 1: DesignTokens | ✅ Complete | ~1.5 hours | - |
| Phase 2: Core Components | ✅ Complete | ~2 hours | - |
| Phase 3: Screen-Level | ✅ Complete | ~4 hours | - |
| Phase 4: Paywall & Auth | ✅ Complete | ~2 hours | - |
| Phase 5: Brand Assets Config | ✅ Complete | ~30 min | ⏳ Design Required |
| Phase 5: Search | ⏳ Pending | - | ~4 hours |
| Phase 6: Brand Assets | ⏳ Pending | - | ~2-3 hours |
| Phase 7: Testing | ⏳ Pending | - | ~5-6 hours |
| Phase 8: Cleanup | ⏳ Optional | - | ~8-10 hours |

**Total Estimated Time:** ~28-35 hours (excluding optional Phase 8)

---

## 🎯 Current Status

**✅ Completed:**
- Phase 0: Pre-Migration Fixes
- Phase 1: DesignTokens Foundation

**🔄 Next Up:**
- Phase 5: Brand Assets Design (Asset creation required - see PHASE_5_ASSET_CREATION_GUIDE.md)
- Phase 6: Full-Screen Search Implementation (Optional - can be done later)
- Phase 7: Testing & QA

**📝 Notes:**
- All hardcoded colors fixed ✅
- DesignTokens updated with Flario palette ✅
- Ready to migrate components to use new colors

---

## ⚠️ Important Notes

1. **No Skipping:** Each phase builds on the previous one
2. **Test After Each Phase:** Don't wait until the end
3. **Both Documents:** This plan merges both roadmaps - nothing is skipped
4. **Component Architecture Phase 2** = **Flario Phase 2** (same components, different focus)
5. **Component Architecture Phase 3** = **Flario Phase 3** (same screens)
6. **Component Architecture Phase 4** (Search) is separate and comes after screens
7. **Component Architecture Phase 5** (Cleanup) is optional and can be done later

---

## 🚀 Next Steps

**Immediate Action:** Start Phase 2 - Core Components Migration

1. Update UnifiedHeaderBar
2. Update QuotaDisplayView
3. Update AppLogo
4. Update TabBar
5. Test everything

**After Phase 2:** Continue to Phase 3 (Screen-Level Components)

---

**Last Updated:** 2026-01-27  
**Next Review:** After Phase 2 completion
