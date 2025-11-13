# 👤 Profile Screen Design Audit & Migration Plan

**Date**: 2025-11-02  
**External App**: BananaUniverse (ProfileView.swift)  
**Target**: Fortunia (ProfileScreen.swift - MVVM Architecture)

---

## 📊 Executive Summary

This audit compares the external app's Profile screen implementation with Fortunia's expected MVVM architecture. The external app **already follows MVVM pattern** with a well-structured ViewModel, but includes **inline components** that should be extracted and **design token violations** that need fixing. Migration primarily involves **extracting inline components**, **reorganizing component locations**, and ensuring **100% design system compliance**.

---

## 🔍 Layout Comparison Table

| Aspect | External App (BananaUniverse) | Fortunia Expected Structure |
|--------|-------------------------------|----------------------------|
| **View Hierarchy** | `NavigationStack` → `VStack` → Header, ScrollView | `NavigationStack` → `VStack` → Header, ScrollView |
| **State Management** | `@StateObject` ViewModel + `@State` for UI (sheets, triggers) | `@StateObject` ViewModel + minimal `@State` for UI only |
| **Business Logic** | ✅ All in `ProfileViewModel` | ✅ All in `ProfileViewModel` |
| **Component Location** | Mix: Core components + inline components | All in `Views/Components/` (shared) |
| **Header Component** | `UnifiedHeaderBar` (from Core) | `UnifiedHeaderBar` (from `Views/Components/`) |
| **Pro Card** | Inline `ProCard` struct | Extract to `Views/Components/ProCard/` |
| **Premium Banner** | Inline `PremiumStatusBanner` struct | Extract to `Views/Components/PremiumStatusBanner/` |
| **Sign In Button** | Inline `Button` in View | Extract to `Views/Components/SignInButton/` |
| **Theme Selector** | Inline `Menu` in View | Extract to `Views/Components/ThemeSelector/` |
| **Profile Row** | `ProfileRow` (from Core) | Move to `Views/Components/ProfileRow/` |
| **Quota Display** | `QuotaDisplayView` (from Core) | Move to `Views/Components/QuotaDisplayView/` |
| **Design System** | ⚠️ Mixed (some hardcoded colors) | ✅ 100% design token compliance |
| **Navigation** | Sheet presentation for modals | Same pattern, ViewModel manages state |

---

## 🏗️ View Hierarchy Comparison

### External App Structure
```
NavigationStack
└── VStack(spacing: 0)
    ├── UnifiedHeaderBar
    └── ScrollView
        └── VStack (profileContent)
            ├── ProCard (inline component)
            ├── PremiumStatusBanner (inline component, conditional)
            ├── Sign In Button (inline, conditional)
            ├── Account Section (conditional)
            │   └── VStack Card
            │       ├── ProfileRow (Email)
            │       ├── Divider
            │       ├── QuotaDisplayView
            │       ├── Divider
            │       └── ProfileRow (Sign Out)
            ├── Settings Section
            │   └── VStack Card
            │       ├── Theme Selector (inline Menu)
            │       ├── Divider
            │       ├── ProfileRow (Language)
            │       ├── Divider
            │       ├── ProfileRow (Notifications)
            │       ├── Divider (conditional)
            │       └── Delete Account Button (inline, conditional)
            └── Support Section
                └── VStack Card
                    ├── ProfileRow (Help & Support)
                    ├── Divider
                    ├── ProfileRow (Privacy Policy)
                    ├── Divider
                    ├── ProfileRow (Terms of Service)
                    ├── Divider
                    ├── ProfileRow (AI Disclosure)
                    ├── Divider
                    └── ProfileRow (Restore Purchases)
```

### Fortunia Expected Structure
```
NavigationStack
└── VStack(spacing: 0)
    ├── UnifiedHeaderBar
    └── ScrollView
        └── VStack (profileContent)
            ├── ProCard (component)
            ├── PremiumStatusBanner (component, conditional)
            ├── SignInButton (component, conditional)
            ├── AccountSection (component, conditional)
            ├── SettingsSection (component)
            └── SupportSection (component)
```

**Key Difference**: Inline components extracted, sections modularized, component locations moved to shared `Views/Components/`.

---

## 🧩 Component Structure Analysis

### ✅ Reusable Components (External App → Fortunia)

| Component | Current Location | Fortunia Target | Status | Notes |
|-----------|-----------------|-----------------|--------|-------|
| `UnifiedHeaderBar` | `Core/Components/` | `Views/Components/` | ✅ Reusable | Already modular |
| `ProfileRow` | `Core/Components/ProfileRow/` | `Views/Components/ProfileRow/` | ✅ Reusable | Well-designed, reusable |
| `QuotaDisplayView` | `Core/Components/` | `Views/Components/QuotaDisplayView/` | ✅ Reusable | Multiple styles supported |

### 🔨 Inline Components (Need to Extract)

| Component | Current State | Fortunia Target | Priority | Notes |
|-----------|--------------|-----------------|----------|-------|
| `ProCard` | Inline struct in ProfileView.swift | `Views/Components/ProCard/` | **High** | Complex component with gradient, buttons |
| `PremiumStatusBanner` | Inline struct in ProfileView.swift | `Views/Components/PremiumStatusBanner/` | Medium | Simple banner component |
| `SignInButton` | Inline `Button` in ProfileView | `Views/Components/SignInButton/` | Medium | Simple button, but reusable |
| `ThemeSelector` | Inline `Menu` in ProfileView | `Views/Components/ThemeSelector/` | **High** | Complex Menu with 3 options |
| `DeleteAccountButton` | Inline `Button` in ProfileView | `Views/Components/DeleteAccountButton/` | Low | Destructive action, specific to Profile |

### 📦 Component Dependencies

```
ProfileView
├── UnifiedHeaderBar (from Core)
├── ProCard (inline - needs extraction)
├── PremiumStatusBanner (inline - needs extraction)
├── SignInButton (inline - needs extraction)
├── ProfileRow (from Core)
├── QuotaDisplayView (from Core)
├── ThemeSelector (inline - needs extraction)
├── DeleteAccountButton (inline - needs extraction)
└── Sheets:
    ├── PaywallPreview
    ├── SignInView
    └── AI_Disclosure_View
```

---

## 🎨 Styling & Design System Compliance

### ✅ Design System Usage (External App)

- **Colors**: ✅ Mostly uses `DesignTokens.Background.*`, `DesignTokens.Text.*`, `DesignTokens.Surface.*`, `DesignTokens.Brand.*`
- **Spacing**: ✅ Uses `DesignTokens.Spacing.*` (8pt grid)
- **Typography**: ✅ Uses `DesignTokens.Typography.*`
- **Shadows**: ⚠️ Some hardcoded shadows in `ProCard`
- **Corner Radius**: ✅ Uses `DesignTokens.CornerRadius.*`
- **Haptics**: ✅ Uses `DesignTokens.Haptics.*`

### ⚠️ Design Token Violations Found

1. **ProCard Component**:
   - Hardcoded colors: `Color(hex: "1A1A1A")`, `Color(hex: "FFFFFF")`, `Color(hex: "6B21C0")`, `Color(hex: "EDEBFF")`
   - Hardcoded gradients instead of `DesignTokens.Gradients.*`
   - Hardcoded shadow: `shadow(color: .black.opacity(0.05), ...)`
   - Should use `DesignTokens.Text.primary()`, `DesignTokens.Brand.primary()`, `DesignTokens.Shadow.*`

2. **PremiumStatusBanner**:
   - ✅ Properly uses design tokens

3. **Sign In Button**:
   - ✅ Properly uses `DesignTokens.Brand.primary()` and `DesignTokens.Spacing.*`

4. **Theme Selector**:
   - ⚠️ Hardcoded colors: `.orange`, `.blue`, `.gray` for theme icons
   - Should use semantic colors or design tokens

5. **Delete Account Button**:
   - ✅ Properly uses `DesignTokens.Semantic.error()`

### ✅ Fortunia Compliance

**Status**: ⚠️ **85% COMPLIANT** (needs fixes for ProCard and ThemeSelector)

---

## 🔄 State Management Analysis

### External App (Current - MVVM Compliant ✅)

```swift
struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()  // ✅ MVVM
    @ObservedObject private var authService = HybridAuthService.shared
    @StateObject private var creditManager = HybridCreditManager.shared
    @EnvironmentObject var themeManager: ThemeManager
    
    // ✅ UI-only state
    @State private var showPaywall = false
    @State private var showSignIn = false
    @State private var showAI_Disclosure = false
    @State private var authStateRefreshTrigger = false
    @State private var mockNotificationEnabled = true  // ⚠️ Should be in ViewModel
}
```

### ViewModel Structure (Well-Architected ✅)

```swift
@MainActor
class ProfileViewModel: ObservableObject {
    // ✅ Published properties for state
    @Published private(set) var isPremiumUser: Bool = false
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""
    @Published var showDeleteConfirmation: Bool = false
    @Published var isDeletingAccount: Bool = false
    @Published var profile: UserProfile? = nil
    @Published var isProfileLoading: Bool = false
    @Published var profileError: String? = nil
    @Published var isLoadingSubscription: Bool = false
    @Published var shouldShowSuccessAlert: Bool = false
    @Published var successAlertMessage: String = ""
    
    // ✅ Business logic methods
    func restorePurchases() async { ... }
    func openManageSubscription() { ... }
    func getSubscriptionStatusText() -> String { ... }
    func refreshSubscriptionDetails() async { ... }
    func showDeleteAccountConfirmation() { ... }
    func deleteAccount() async { ... }
    func onAuthStateChanged(_ newState: UserState) async { ... }
    func loadProfile() async { ... }
}
```

### ⚠️ Issues Found

1. **Mock Notification State**: `mockNotificationEnabled` is in View (should be in ViewModel)
2. **Multiple Service Observables**: `@ObservedObject` and `@StateObject` for services (should be injected into ViewModel)

### Fortunia Expected (Minor Improvements)

**Status**: ✅ **90% MVVM COMPLIANT** (minor refactoring needed)

---

## 📋 Required New Components List

### 1. **ProCard Component** (EXTRACT - HIGH PRIORITY)
**Location**: `Views/Components/ProCard/ProCard.swift`

**Current State**: Inline struct in `ProfileView.swift` (lines 477-590)

**Props**:
- `isProActive: Bool`
- `features: [String]`
- `subscriptionStatusText: String`
- `isLoadingSubscription: Bool`
- `onUpgradeTap: () -> Void`
- `onManageTap: () -> Void`
- `onRefreshTap: () -> Void`

**Features**:
- Gradient background (needs design token fix)
- Crown icon
- Feature list with checkmarks
- Upgrade/Manage button
- Subscription status with refresh button
- Design token compliance (needs fixes)

**Design Token Fixes Required**:
- Replace `Color(hex: "1A1A1A")` with `DesignTokens.Text.primary()`
- Replace `Color(hex: "FFFFFF")` with `DesignTokens.Text.inverse`
- Replace `Color(hex: "6B21C0")` with `DesignTokens.Brand.primary()`
- Replace `Color(hex: "EDEBFF")` with `DesignTokens.Gradients.premiumStart()`
- Replace hardcoded shadow with `DesignTokens.Shadow.*`

---

### 2. **PremiumStatusBanner Component** (EXTRACT - MEDIUM PRIORITY)
**Location**: `Views/Components/PremiumStatusBanner/PremiumStatusBanner.swift`

**Current State**: Inline struct in `ProfileView.swift` (lines 592-619)

**Props**:
- None (uses environment for theme)

**Features**:
- Crown icon
- Premium message
- Rounded background with border
- Design token compliance ✅

---

### 3. **SignInButton Component** (EXTRACT - MEDIUM PRIORITY)
**Location**: `Views/Components/SignInButton/SignInButton.swift`

**Current State**: Inline `Button` in `ProfileView.swift` (lines 127-144)

**Props**:
- `onSignIn: () -> Void`

**Features**:
- Person icon
- "Sign In or Create Account" text
- Full-width button
- Brand primary color
- Design token compliance ✅

---

### 4. **ThemeSelector Component** (EXTRACT - HIGH PRIORITY)
**Location**: `Views/Components/ThemeSelector/ThemeSelector.swift`

**Current State**: Inline `Menu` in `ProfileView.swift` (lines 206-301)

**Props**:
- `@Binding var preference: ThemePreference` (or use `@EnvironmentObject var themeManager`)

**Features**:
- Paintbrush icon
- Theme picker (Light/Dark/Auto)
- Current selection indicator (checkmark)
- Theme icons (sun/moon/system)
- Design token compliance (needs fixes for icon colors)

**Design Token Fixes Required**:
- Replace `.orange`, `.blue`, `.gray` with semantic colors or design tokens

---

### 5. **DeleteAccountButton Component** (EXTRACT - LOW PRIORITY)
**Location**: `Views/Components/DeleteAccountButton/DeleteAccountButton.swift`

**Current State**: Inline `Button` in `ProfileView.swift` (lines 348-376)

**Props**:
- `isDeleting: Bool`
- `onDelete: () -> Void`

**Features**:
- Trash icon
- Destructive color (error semantic)
- Loading state (ProgressView)
- Design token compliance ✅

---

### 6. **AccountSection Component** (EXTRACT - MEDIUM PRIORITY)
**Location**: `Views/Components/AccountSection/AccountSection.swift`

**Current State**: Inline `VStack` in `ProfileView.swift` (lines 147-194)

**Props**:
- `email: String`
- `onSignOut: () -> Void`
- `onQuotaTap: (() -> Void)?`

**Features**:
- Section header
- Email row
- Quota display
- Sign out row
- Dividers between rows
- Design token compliance ✅

---

### 7. **SettingsSection Component** (EXTRACT - MEDIUM PRIORITY)
**Location**: `Views/Components/SettingsSection/SettingsSection.swift`

**Current State**: Inline `VStack` in `ProfileView.swift` (lines 196-381)

**Props**:
- `onLanguageTap: () -> Void`
- `onNotificationsTap: () -> Void`
- `isNotificationEnabled: Bool`
- `onDeleteAccount: () -> Void`
- `isDeletingAccount: Bool`
- `isAuthenticated: Bool`

**Features**:
- Section header
- Theme selector
- Language row
- Notifications row
- Delete account button (conditional)
- Dividers between rows
- Design token compliance ⚠️ (ThemeSelector needs fixes)

---

### 8. **SupportSection Component** (EXTRACT - MEDIUM PRIORITY)
**Location**: `Views/Components/SupportSection/SupportSection.swift`

**Current State**: Inline `VStack` in `ProfileView.swift` (lines 383-471)

**Props**:
- `onHelpTap: () -> Void`
- `onPrivacyTap: () -> Void`
- `onTermsTap: () -> Void`
- `onAIDisclosureTap: () -> Void`
- `onRestorePurchases: () -> Void`

**Features**:
- Section header
- Help & Support row
- Privacy Policy row
- Terms of Service row
- AI Disclosure row
- Restore Purchases row
- Dividers between rows
- Design token compliance ✅

---

## 🚀 Suggested Migration Sequence

### Phase 1: Extract Inline Components (No Breaking Changes)
**Goal**: Modularize inline UI components

1. ✅ Extract `ProCard` from inline struct to `Views/Components/ProCard/`
   - File: `Views/Components/ProCard/ProCard.swift`
   - Props: `isProActive`, `features`, `subscriptionStatusText`, `isLoadingSubscription`, callbacks
   - **Fix design tokens**: Replace hardcoded colors with design tokens
   - Test: Replace inline code with component

2. ✅ Extract `PremiumStatusBanner` from inline struct to `Views/Components/PremiumStatusBanner/`
   - File: `Views/Components/PremiumStatusBanner/PremiumStatusBanner.swift`
   - Props: None (uses environment)
   - Test: Replace inline code with component

3. ✅ Extract `SignInButton` from inline `Button` to `Views/Components/SignInButton/`
   - File: `Views/Components/SignInButton/SignInButton.swift`
   - Props: `onSignIn: () -> Void`
   - Test: Replace inline code with component

4. ✅ Extract `ThemeSelector` from inline `Menu` to `Views/Components/ThemeSelector/`
   - File: `Views/Components/ThemeSelector/ThemeSelector.swift`
   - Props: `@Binding var preference` or use `@EnvironmentObject`
   - **Fix design tokens**: Replace hardcoded icon colors
   - Test: Replace inline code with component

5. ✅ Extract `DeleteAccountButton` from inline `Button` to `Views/Components/DeleteAccountButton/`
   - File: `Views/Components/DeleteAccountButton/DeleteAccountButton.swift`
   - Props: `isDeleting: Bool`, `onDelete: () -> Void`
   - Test: Replace inline code with component

---

### Phase 2: Extract Section Components (Modularization)
**Goal**: Create reusable section components

6. ✅ Extract `AccountSection` from inline `VStack` to `Views/Components/AccountSection/`
   - File: `Views/Components/AccountSection/AccountSection.swift`
   - Props: `email`, `onSignOut`, `onQuotaTap`
   - Test: Replace inline code with component

7. ✅ Extract `SettingsSection` from inline `VStack` to `Views/Components/SettingsSection/`
   - File: `Views/Components/SettingsSection/SettingsSection.swift`
   - Props: Theme, Language, Notifications, Delete Account callbacks
   - Test: Replace inline code with component

8. ✅ Extract `SupportSection` from inline `VStack` to `Views/Components/SupportSection/`
   - File: `Views/Components/SupportSection/SupportSection.swift`
   - Props: All support row callbacks
   - Test: Replace inline code with component

---

### Phase 3: Move Components to Fortunia Structure
**Goal**: Align component locations with Fortunia architecture

9. ✅ Move `UnifiedHeaderBar` from `Core/Components/` to `Views/Components/`
   - Update imports in `ProfileView.swift` and all other files

10. ✅ Move `ProfileRow` from `Core/Components/ProfileRow/` to `Views/Components/ProfileRow/`
    - Update imports in `ProfileView.swift` and all other files

11. ✅ Move `QuotaDisplayView` from `Core/Components/` to `Views/Components/QuotaDisplayView/`
    - Update imports in `ProfileView.swift` and all other files

---

### Phase 4: Fix Design System Compliance
**Goal**: Ensure 100% design token compliance

12. ✅ Fix `ProCard` design tokens
    - Replace `Color(hex: "1A1A1A")` → `DesignTokens.Text.primary()`
    - Replace `Color(hex: "FFFFFF")` → `DesignTokens.Text.inverse`
    - Replace `Color(hex: "6B21C0")` → `DesignTokens.Brand.primary()`
    - Replace `Color(hex: "EDEBFF")` → `DesignTokens.Gradients.premiumStart()`
    - Replace hardcoded shadow → `DesignTokens.Shadow.md`

13. ✅ Fix `ThemeSelector` design tokens
    - Replace `.orange` → `DesignTokens.Semantic.warning()` or custom theme color
    - Replace `.blue` → `DesignTokens.Brand.secondary()` or custom theme color
    - Replace `.gray` → `DesignTokens.Text.tertiary()`

14. ✅ Verify all components use `DesignTokens.*`
    - Review all files for hardcoded values
    - Replace with design tokens

15. ✅ Verify all spacing uses `DesignTokens.Spacing.*` (8pt grid)
    - Check all padding/margin values

16. ✅ Verify all colors use design tokens
    - Check all color references

17. ✅ Verify all typography uses `DesignTokens.Typography.*`
    - Check all font definitions

---

### Phase 5: Refactor ViewModel (Minor Improvements)
**Goal**: Move remaining state to ViewModel

18. ✅ Move `mockNotificationEnabled` from View to ViewModel
    - Add `@Published var notificationEnabled: Bool` to ViewModel
    - Update View to use `viewModel.notificationEnabled`

19. ✅ Refactor service dependencies
    - Inject services into ViewModel instead of using `@ObservedObject` in View
    - ViewModel should expose computed properties instead

---

### Phase 6: Testing & Refinement
**Goal**: Ensure functionality and performance

20. ✅ Test ProCard (upgrade/manage/refresh)
21. ✅ Test PremiumStatusBanner (conditional display)
22. ✅ Test SignInButton (conditional display, sheet presentation)
23. ✅ Test AccountSection (email, quota, sign out)
24. ✅ Test SettingsSection (theme, language, notifications, delete account)
25. ✅ Test SupportSection (all links and actions)
26. ✅ Test ThemeSelector (light/dark/auto switching)
27. ✅ Test DeleteAccountButton (confirmation, loading state)
28. ✅ Test all sheet presentations (Paywall, SignIn, AI Disclosure)
29. ✅ Test alerts (restore purchases, delete confirmation)
30. ✅ Test auth state changes (refresh trigger)
31. ✅ Performance: Verify ViewModel doesn't cause unnecessary re-renders
32. ✅ Accessibility: Verify all components have proper labels and hints
33. ✅ Localization: Verify all text uses `NSLocalizedString`

---

## 🔑 Key Differences Summary

### External App (BananaUniverse)
- ✅ MVVM pattern (already compliant)
- ✅ Well-structured ViewModel
- ⚠️ Inline components (ProCard, PremiumStatusBanner, ThemeSelector, etc.)
- ⚠️ Components in mixed locations (Core + inline)
- ⚠️ Some design token violations (ProCard, ThemeSelector)
- ⚠️ Mock state in View (`mockNotificationEnabled`)

### Fortunia Expected
- ✅ MVVM pattern (maintain current)
- ✅ All components extracted (no inline)
- ✅ Components in shared `Views/Components/`
- ✅ 100% design token compliance
- ✅ All state in ViewModel (no mock state in View)
- ✅ Radical simplicity (one primary action per section)

---

## 📝 Migration Checklist

### Components to Extract
- [ ] `ProCard` component (HIGH - complex with design token fixes)
- [ ] `PremiumStatusBanner` component (MEDIUM)
- [ ] `SignInButton` component (MEDIUM)
- [ ] `ThemeSelector` component (HIGH - complex with design token fixes)
- [ ] `DeleteAccountButton` component (LOW)
- [ ] `AccountSection` component (MEDIUM)
- [ ] `SettingsSection` component (MEDIUM)
- [ ] `SupportSection` component (MEDIUM)

### Components to Move
- [ ] `UnifiedHeaderBar` → `Views/Components/`
- [ ] `ProfileRow` → `Views/Components/ProfileRow/`
- [ ] `QuotaDisplayView` → `Views/Components/QuotaDisplayView/`

### Design System Fixes
- [ ] Fix `ProCard` hardcoded colors (5 replacements)
- [ ] Fix `ProCard` hardcoded shadow
- [ ] Fix `ThemeSelector` hardcoded icon colors (3 replacements)
- [ ] Verify all components use design tokens
- [ ] Verify all spacing uses 8pt grid
- [ ] Verify all colors use design tokens
- [ ] Verify all typography uses design tokens

### ViewModel Improvements
- [ ] Move `mockNotificationEnabled` to ViewModel
- [ ] Refactor service dependencies (inject into ViewModel)

### View Updates
- [ ] Update `ProfileView` → `ProfileScreen` (rename)
- [ ] Update all imports after component moves
- [ ] Replace inline components with extracted components
- [ ] Verify ViewModel usage (minor improvements)

### Testing
- [ ] Test all sections and components
- [ ] Test all interactions (tap, sheets, alerts)
- [ ] Test theme switching
- [ ] Test auth state changes
- [ ] Test accessibility
- [ ] Test localization
- [ ] Test performance

---

## 🎯 Success Criteria

1. ✅ **MVVM Compliance**: Maintain current MVVM pattern (already compliant, minor improvements)
2. ✅ **Component Modularity**: All components extracted and reusable
3. ✅ **File Structure**: Components in `Views/Components/`, not inline or feature-specific
4. ✅ **Design System**: 100% design token compliance
5. ✅ **Functionality**: All features work identically to external app
6. ✅ **Performance**: No unnecessary re-renders, efficient state management
7. ✅ **Radical Simplicity**: One primary action per section
8. ✅ **State Management**: All state in ViewModel (no mock state in View)

---

## 📚 Component Usage Patterns

### ProCard Section
- **Purpose**: Display premium status and upgrade/manage options
- **Component**: `ProCard`
- **Layout**: Card with gradient background, icon, text, buttons
- **Data Source**: `viewModel.isPremiumUser`, `viewModel.getSubscriptionStatusText()`

### Account Section
- **Purpose**: Show user account info and quota
- **Component**: `AccountSection` → `ProfileRow`, `QuotaDisplayView`
- **Layout**: Vertical card with dividers
- **Data Source**: `authService.currentUser?.email`, `creditManager`

### Settings Section
- **Purpose**: App preferences and account management
- **Components**: `SettingsSection` → `ThemeSelector`, `ProfileRow`, `DeleteAccountButton`
- **Layout**: Vertical card with dividers
- **Data Source**: `themeManager.preference`, `viewModel.notificationEnabled`

### Support Section
- **Purpose**: Help, legal, and subscription management
- **Component**: `SupportSection` → `ProfileRow` (multiple)
- **Layout**: Vertical card with dividers
- **Data Source**: Config URLs, ViewModel callbacks

---

## 🔍 State Management Patterns

### ViewModel State
```swift
// Premium Status
@Published private(set) var isPremiumUser: Bool = false
@Published var isLoadingSubscription: Bool = false

// Alerts
@Published var showAlert: Bool = false
@Published var alertMessage: String = ""
@Published var showDeleteConfirmation: Bool = false

// Account Management
@Published var isDeletingAccount: Bool = false
@Published var profile: UserProfile? = nil
@Published var isProfileLoading: Bool = false
@Published var profileError: String? = nil

// Success Alerts
@Published var shouldShowSuccessAlert: Bool = false
@Published var successAlertMessage: String = ""
```

### View State (Minimal - UI Only)
```swift
@StateObject private var viewModel = ProfileViewModel()
@ObservedObject private var authService = HybridAuthService.shared
@StateObject private var creditManager = HybridCreditManager.shared
@EnvironmentObject var themeManager: ThemeManager

// UI-only state
@State private var showPaywall = false
@State private var showSignIn = false
@State private var showAI_Disclosure = false
@State private var authStateRefreshTrigger = false
@State private var mockNotificationEnabled = true  // ⚠️ Should be in ViewModel
```

### Lifecycle Management
- `onReceive(authService.$userState)`: Refresh when auth state changes
- `onReceive(viewModel.$isPremiumUser)`: Update UI when premium status changes
- `.alert()`: Show alerts for restore purchases and delete account
- `.sheet()`: Present modals (Paywall, SignIn, AI Disclosure)

---

## 📐 Layout Spacing Patterns

### Vertical Spacing
- Section spacing: `DesignTokens.Spacing.lg` (24pt)
- Card padding: `DesignTokens.Spacing.md` (16pt)
- Row padding: `DesignTokens.Spacing.md` (16pt)
- Small spacing: `DesignTokens.Spacing.sm` (8pt)
- XS spacing: `DesignTokens.Spacing.xs` (4pt)

### Horizontal Spacing
- Content padding: `DesignTokens.Spacing.md` (16pt)
- Card padding: `DesignTokens.Spacing.md` (16pt)
- Row padding: `DesignTokens.Spacing.md` (16pt)

### Component Sizing
- Button height: 44-50pt
- Row height: 50pt
- Icon size: 20-24pt
- Header height: `DesignTokens.Layout.headerHeight` (56pt)

---

## 🔗 Interaction Patterns

### Primary Actions
1. **Upgrade to Pro**: ProCard → Upgrade button → Paywall sheet
2. **Manage Subscription**: ProCard → Manage button → App Store subscriptions
3. **Sign In**: Sign In button → SignInView sheet
4. **Sign Out**: Account section → Sign Out row → Confirm → Sign out
5. **Delete Account**: Settings section → Delete Account → Confirm alert → Delete

### Secondary Actions
- **Theme Switching**: Settings → Theme selector → Menu → Select theme
- **Language**: Settings → Language row → (Future: Language picker)
- **Notifications**: Settings → Notifications row → Toggle
- **Support Links**: Support section → Row → Open URL
- **Restore Purchases**: Support section → Restore Purchases → ViewModel → Alert

---

## 📚 References

- Architecture Guide: `.claude/ARCHITECTURE.md`
- Design Tokens: `BananaUniverse/Core/Design/DesignTokens.swift`
- External ProfileView: `BananaUniverse/Features/Profile/Views/ProfileView.swift`
- External ProfileViewModel: `BananaUniverse/Features/Profile/ViewModels/ProfileViewModel.swift`
- MVVM Pattern: See `.claude/ARCHITECTURE.md` (lines 49-77)

---

**End of Audit Report**

