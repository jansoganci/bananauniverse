# ProfileView Migration Plan: Classic → Modern Apple HIG-Compliant Layout

**Date:** 2025-11-02  
**Target:** Replace classic ProfileView with modern grouped card layout from ProfilePreview  
**Status:** 📋 PLANNING - Phase 0 (Analysis Complete)

---

## 📊 Comparative Analysis

### Current ProfileView.swift Structure

**Layout:**
```
NavigationView
├── UnifiedHeaderBar(title: "Profile") // NO rightContent yet!
├── ScrollView
│   └── VStack
│       ├── ProCard (gradient premium card)
│       ├── PremiumStatusBanner (conditional)
│       ├── Sign In Button (for anonymous users)
│       ├── Account Info Section (authenticated users)
│       │   ├── Email Row
│       │   ├── Quota Display (detailed)
│       │   └── Sign Out Button
│       ├── Settings Section
│       │   ├── Help & Support
│       │   ├── Privacy Policy
│       │   ├── Terms of Service
│       │   ├── AI Service Disclosure
│       │   ├── Restore Purchases
│       │   ├── Theme Selector (Menu dropdown)
│       │   └── Delete Account (destructive)
│       └── Empty VStack spacer (lines 141-147, bug?)
```

**Business Logic:**
- ✅ `@StateObject viewModel` - ProfileViewModel (premium status, alerts, subscription)
- ✅ `@ObservedObject authService` - HybridAuthService (auth state, sign out)
- ✅ `@StateObject creditManager` - HybridCreditManager (quota display)
- ✅ `@EnvironmentObject themeManager` - ThemeManager (theme switching)
- ✅ `@State showPaywall` - Paywall sheet
- ✅ `@State showSignIn` - Sign in sheet
- ✅ `@State showAI_Disclosure` - AI disclosure sheet
- ✅ `authStateRefreshTrigger` - Forces UI refresh on auth changes
- ✅ Alert handling (restore purchases, delete account)
- ✅ Sheet presentations
- ✅ Navigation to subscription management
- ✅ URL opening (support, privacy, terms)

**Existing Components:**
- ✅ `ProCard` - Premium subscription card with upgrade/manage buttons
- ✅ `PremiumStatusBanner` - Premium user notification banner
- ✅ `SettingsRow` - Reusable settings row component
- ✅ `QuotaDisplayView` (detailed style) - Quota info display

**Navigation:**
- ❌ Uses deprecated `NavigationView` (should be `NavigationStack`)
- ✅ Header currently: `UnifiedHeaderBar(title: "Profile")` with NO right content
- ❌ MISSING: PRO badge or Get PRO button in header (NEW REQUIREMENT)

**Issues:**
- 🐛 Empty VStack spacer bug (lines 141-147)
- 🎨 Inconsistent styling (mix of old/new design tokens)
- 📐 Inefficient layout spacing
- 🎯 No header PRO status indicator

---

### New ProfilePreview.swift Structure (Target)

**Layout:**
```
NavigationStack
├── headerView (custom header with Profile title)
├── ScrollView
│   └── VStack(spacing: lg)
│       ├── accountSection
│       │   ├── Section Header ("Account")
│       │   └── Card
│       │       ├── Username Row (ProfileRow)
│       │       ├── Email Row (ProfileRow)
│       │       └── Subscription Row (ProfileRow with crown icon)
│       ├── settingsSection
│       │   ├── Section Header ("Settings")
│       │   └── Card
│       │       ├── Theme Row (ProfileRow)
│       │       ├── Language Row (ProfileRow)
│       │       └── Notifications Row (ProfileRow)
│       └── supportSection
│           ├── Section Header ("Support")
│           └── Card
│               ├── Help & Support (ProfileRow)
│               ├── Privacy Policy (ProfileRow)
│               ├── Terms of Service (ProfileRow)
│               ├── AI Service Disclosure (ProfileRow)
│               └── Restore Purchases (ProfileRow)
```

**Business Logic:**
- ❌ Mock data only (no real backend)
- ❌ No auth integration
- ❌ No sheets/alerts
- ❌ No subscription management
- ❌ No navigation

**Components:**
- ✅ `ProfileRow` - NEW reusable row component with icon, title, subtitle, chevron
- ✅ Modern card-based layout
- ✅ Section headers with `Typography.title3`
- ✅ Clean spacing with `DesignTokens`
- ✅ Theme-aware colors

**Navigation:**
- ✅ Uses `NavigationStack` (modern)
- ❌ Custom header (should use `UnifiedHeaderBar` with PRO badge)
- ❌ No navigation or actions

---

## 🔍 Shared Components Analysis

### ✅ Already Reusable (No Changes Needed)

1. **UnifiedHeaderBar**
   - ✅ Fully functional, supports all header content types
   - ✅ Supports `.getProButton` and `.unlimitedBadge` (used in HomeView)
   - ✅ Uses ThemeManager
   - ✅ DesignTokens compliant

2. **DesignTokens**
   - ✅ All spacing, typography, colors available
   - ✅ `Typography.title3` for section headers
   - ✅ `CornerRadius.md` for cards
   - ✅ Theme-aware functions

3. **ThemeManager**
   - ✅ `EnvironmentObject` integration
   - ✅ `resolvedColorScheme` property
   - ✅ Theme switching via `ThemePreference` enum

4. **ProfileViewModel**
   - ✅ Full business logic (premium, restore, delete, subscription)
   - ✅ `@Published` properties for reactive updates
   - ✅ Subscription status management
   - ✅ Error handling

5. **HybridAuthService**
   - ✅ Auth state management
   - ✅ Sign out functionality
   - ✅ Current user email access

6. **HybridCreditManager**
   - ✅ Premium status check
   - ✅ Quota management

### 🔄 Needs Integration/Migration

1. **ProfileRow (NEW)**
   - 📦 Copy from ProfilePreview.swift
   - ✅ Icon with circular background
   - ✅ Title + optional subtitle
   - ✅ Optional chevron
   - ✅ Optional action
   - ✅ Theme-aware
   - ⚠️ Need to merge with existing `SettingsRow` logic

2. **Header Logic**
   - ❌ ProfileView currently has NO right content
   - ✅ Add conditional right content:
     - PRO user: `.unlimitedBadge({})`
     - Free user: `.getProButton { showPaywall = true }`
   - ✅ Use existing paywall sheet integration

3. **SettingsRow vs ProfileRow**
   - ⚠️ ProfileView has `SettingsRow` (old)
   - ⚠️ ProfilePreview has `ProfileRow` (new)
   - 📋 DECISION: Replace `SettingsRow` with `ProfileRow` for consistency
   - ⚠️ `ProfileRow` is MORE flexible (subtitles, custom icon colors)

---

## ⚠️ Critical Requirements & Missing Features

### 🔴 HIGH PRIORITY - Must Add/Merge

1. **Header PRO Badge Integration**
   - **Location:** UnifiedHeaderBar rightContent
   - **Logic:** 
     ```swift
     rightContent: creditManager.isPremiumUser 
         ? .unlimitedBadge({})  // PRO badge
         : .getProButton { showPaywall = true }  // Get PRO button
     ```
   - **Impact:** Consistent with HomeView, better UX

2. **ProfileRow Component**
   - **Action:** Copy from ProfilePreview
   - **Usage:** Replace SettingsRow throughout ProfileView
   - **Benefits:** Better visual design, subtitle support, consistent styling

3. **ProCard Preservation**
   - **Action:** KEEP existing ProCard (not in ProfilePreview)
   - **Reason:** Premium upgrade CTA is important, shouldn't be just a row
   - **Placement:** Top of account section (before Account card)

4. **Quota Display Preservation**
   - **Action:** KEEP detailed quota display in Account section
   - **Reason:** Users need to see quota info
   - **Placement:** Add as ProfileRow inside Account card

5. **NavigationStack Migration**
   - **Action:** Replace `NavigationView` → `NavigationStack`
   - **Action:** Replace `.navigationBarHidden(true)` → `.toolbar(.hidden, for: .navigationBar)`
   - **Benefit:** Modern iOS 16+ API

6. **Sign Out Functionality**
   - **Action:** PRESERVE existing sign out button
   - **Placement:** Add as ProfileRow in Account section (destructive)

7. **Delete Account Functionality**
   - **Action:** PRESERVE existing delete account button
   - **Placement:** Add as ProfileRow in Settings section (destructive)

8. **Theme Selector**
   - **Action:** KEEP existing Menu dropdown
   - **Reason:** It works, no need to change to simple ProfileRow tap
   - **Note:** Can move to Settings card for consistency

9. **Language Settings**
   - **Action:** ADD as ProfileRow (Preview has it)
   - **Placement:** Settings section
   - **Note:** Mock for now, no implementation needed

10. **Notifications Settings**
    - **Action:** ADD as ProfileRow (Preview has it)
    - **Placement:** Settings section
    - **Note:** Mock for now, no implementation needed

---

## ⚙️ Architecture Decisions

### Decision 1: Replace SettingsRow with ProfileRow?

**✅ YES** - ProfileRow is better:
- Cleaner circular icon background
- Better spacing and typography
- Subtitle support
- More flexible (custom icon colors)
- Consistent with modern design

**Migration:** Replace all `SettingsRow` usages with `ProfileRow` equivalents

### Decision 2: Keep ProCard at Top?

**✅ YES** - ProCard should stay:
- Strong premium CTA is important
- Different purpose than subscription row
- Gradient design is attention-grabbing
- Status banner can also stay (conditional)

**Placement:** Above account section

### Decision 3: Account Section Username?

**❓ DEPENDS** - Need to check UserProfile model:
- If username exists: Add as ProfileRow
- If not: Skip or use email as primary identifier

**Action:** Check ProfileViewModel for username availability

### Decision 4: NavigationView → NavigationStack?

**✅ YES** - Modern API:
- iOS 16+ targeted
- Better performance
- Future-proof

### Decision 5: ProfileRow Name Conflicts?

**⚠️ Potential Conflict:** ProfilePreview has `ProfileRow` struct (local)
- **Risk:** Name collision if both files in same target
- **Solution:** 
  - Option A: Extract to shared component file
  - Option B: Rename in one file
  - **✅ RECOMMENDED:** Extract to `Core/Components/ProfileRow.swift`

---

## 📋 Step-by-Step Migration Plan

### **PHASE 0: Preparation & Analysis** ✅

**Status:** ✅ **COMPLETED**

**Actions:**
- ✅ Analyzed current ProfileView structure
- ✅ Analyzed ProfilePreview structure  
- ✅ Identified shared components
- ✅ Identified missing features
- ✅ Documented architecture decisions
- ✅ Created migration plan

---

### **PHASE 1: Extract & Prepare Components** 🔧

#### Step 1.1: Extract ProfileRow Component
**File:** `BananaUniverse/Core/Components/ProfileRow/ProfileRow.swift` (NEW)

**Action:**
- Copy `ProfileRow` struct from ProfilePreview.swift
- Place in new file: `Core/Components/ProfileRow/ProfileRow.swift`
- Update imports if needed
- Add MARK comments for organization
- Verify it compiles independently

**Dependencies:** None  
**Risk:** Low  
**Status:** 📋 **PENDING**

---

#### Step 1.2: Verify ProfileViewModel Properties
**File:** `ProfileViewModel.swift`

**Action:**
- Check: Does `UserProfile` model have `username` property?
- Check: Does profile loading return username?
- Document: Username availability for Account section

**Dependencies:** None  
**Risk:** Low  
**Status:** 📋 **PENDING**

---

### **PHASE 2: Navigation & Header Migration** 🧭

#### Step 2.1: NavigationStack Migration
**File:** `ProfileView.swift` (lines 22-36)

**Action:**
- Replace `NavigationView` → `NavigationStack` (line 22)
- Replace `.navigationBarHidden(true)` → `.toolbar(.hidden, for: .navigationBar)` (line 36)
- Verify no breaking changes

**Dependencies:** iOS 16+ (already targeted)  
**Risk:** Low  
**Status:** 📋 **PENDING**

---

#### Step 2.2: Add PRO Badge/Get PRO Button to Header
**File:** `ProfileView.swift` (lines 25-26)

**Current:**
```swift
UnifiedHeaderBar(title: "Profile")
```

**Target:**
```swift
UnifiedHeaderBar(
    title: "Profile",
    leftContent: nil,
    rightContent: creditManager.isPremiumUser 
        ? .unlimitedBadge({})  // PRO badge
        : .getProButton { 
            showPaywall = true
            // TODO: Log analytics event - placement: profile_header
        }
)
```

**Action:**
- Update header initialization
- Conditional right content based on premium status
- Verify paywall sheet opens on Get PRO tap
- Test premium vs free user states

**Dependencies:** Step 1.1 (ProfileRow not needed for this)  
**Risk:** Low  
**Status:** 📋 **PENDING**

---

### **PHASE 3: Import ProfileRow & Update Sections** 📦

#### Step 3.1: Import ProfileRow Component
**File:** `ProfileView.swift` (top)

**Action:**
- Verify ProfileRow is accessible (import might not be needed if same module)
- If extracted to shared component, ensure module imports work
- Compile to verify

**Dependencies:** Step 1.1  
**Risk:** Low  
**Status:** 📋 **PENDING**

---

#### Step 3.2: Update Account Section Structure
**File:** `ProfileView.swift` (account section)

**Current Structure:**
```
Account Info Section (old VStack)
├── Text("Account Info") header
└── VStack (account details)
    ├── Email Row (inline HStack)
    ├── Quota Display (detailed)
    └── Sign Out Button (inline HStack)
```

**Target Structure:**
```
accountSection (new)
├── Section Header ("Account")
└── Account Card
    ├── Username Row (ProfileRow) - if available
    ├── Email Row (ProfileRow)
    ├── Quota Row (ProfileRow) - might need custom
    └── Sign Out Row (ProfileRow, destructive)
```

**Actions:**
1. Remove old `Text("Account Info")` header format
2. Add new section header: `Text("Account").font(DesignTokens.Typography.title3)`
3. Replace inline Email HStack with ProfileRow
4. Replace QuotaDisplayView with ProfileRow (or keep if custom styling needed)
5. Replace Sign Out Button with ProfileRow (destructive, icon: "arrow.right.square")
6. Add Dividers between rows
7. Wrap in rounded card background
8. Use `spacing: DesignTokens.Spacing.lg` for section spacing

**Dependencies:** Step 3.1  
**Risk:** Medium  
**Status:** 📋 **PENDING**

**Decision Needed:**
- Quota Row: Use ProfileRow or keep QuotaDisplayView detailed?
- Recommendation: KEEP QuotaDisplayView if it has custom layout/icon
- Username: Add if available from ProfileViewModel

---

#### Step 3.3: Update Settings Section Structure
**File:** `ProfileView.swift` (settings section)

**Current:**
- Uses SettingsRow component (old)
- Inline Theme Selector Menu
- Delete Account in same section

**Target:**
- Replace SettingsRow with ProfileRow
- Move Theme Selector to Settings card (as ProfileRow or keep Menu?)
- Move Delete Account to Settings card (as ProfileRow, destructive)
- Add Language Row (ProfileRow, mock)
- Add Notifications Row (ProfileRow, mock)

**Actions:**
1. Replace Help & Support SettingsRow → ProfileRow
2. Replace Privacy Policy SettingsRow → ProfileRow
3. Replace Terms of Service SettingsRow → ProfileRow
4. Replace AI Service Disclosure SettingsRow → ProfileRow
5. Replace Restore Purchases SettingsRow → ProfileRow
6. Add Language ProfileRow (mock action, subtitle: "English")
7. Add Theme ProfileRow - **DECISION NEEDED:** Keep Menu or simple row?
8. Add Notifications ProfileRow (mock toggle state)
9. Add Delete Account ProfileRow (destructive, icon: "trash")
10. Update dividers to use new spacing
11. Update section header format

**Dependencies:** Step 3.1  
**Risk:** Medium  
**Status:** 📋 **PENDING**

**Decision Needed:**
- Theme: Keep Menu dropdown or change to tap → sheet?
- **RECOMMENDATION:** KEEP Menu (works well, no need to change)

---

### **PHASE 4: Layout & Spacing Refinement** 🎨

#### Step 4.1: Fix Spacing & Layout Issues
**File:** `ProfileView.swift` (content VStack)

**Current Issues:**
- Empty VStack bug (lines 141-147)
- Inconsistent spacing
- Mixed DesignTokens usage
- Old card background styles

**Actions:**
1. Remove empty VStack (lines 141-147)
2. Apply consistent spacing: `VStack(spacing: DesignTokens.Spacing.lg)`
3. Update all padding: `padding(.horizontal, DesignTokens.Spacing.md)`
4. Update all background colors: `DesignTokens.Surface.secondary(colorScheme)`
5. Update all corner radius: `DesignTokens.CornerRadius.md`
6. Update dividers: `.background(DesignTokens.Surface.secondary(colorScheme))`
7. Remove old inline colors (Color.white.opacity, etc.)

**Dependencies:** Phase 3  
**Risk:** Low  
**Status:** 📋 **PENDING**

---

#### Step 4.2: Verify Theme Integration
**File:** `ProfileView.swift` (all colorScheme references)

**Actions:**
1. Check all `colorScheme` usage
2. Replace hardcoded colors with DesignTokens
3. Verify ThemeManager integration
4. Test light/dark mode switching

**Dependencies:** Phase 4.1  
**Risk:** Low  
**Status:** 📋 **PENDING**

---

### **PHASE 5: Preserve Business Logic** 🔧

#### Step 5.1: Verify All Sheets & Alerts Work
**File:** `ProfileView.swift` (sheet modifiers)

**Actions:**
1. Test paywall sheet (Get PRO button)
2. Test sign in sheet (anonymous user)
3. Test AI disclosure sheet
4. Test restore purchases alert
5. Test delete account confirmation

**Dependencies:** Phase 3, Phase 4  
**Risk:** Low  
**Status:** 📋 **PENDING**

---

#### Step 5.2: Verify Auth State Management
**File:** `ProfileView.swift` (onReceive modifiers)

**Actions:**
1. Test authenticated user view
2. Test anonymous user view
3. Test sign out flow
4. Verify authStateRefreshTrigger works

**Dependencies:** Phase 3, Phase 4  
**Risk:** Low  
**Status:** 📋 **PENDING**

---

#### Step 5.3: Verify Premium Status Updates
**File:** `ProfileView.swift` (premium badges, ProCard)

**Actions:**
1. Test free user view (Get PRO in header, upgrade ProCard)
2. Test premium user view (PRO badge in header, manage ProCard)
3. Test premium upgrade flow
4. Verify header updates on premium status change

**Dependencies:** Phase 2.2, Phase 3  
**Risk:** Low  
**Status:** 📋 **PENDING**

---

#### Step 5.4: Verify Subscription Management
**File:** `ProfileView.swift` (ProCard interactions)

**Actions:**
1. Test "Upgrade Now" button → paywall
2. Test "Manage Subscription" → subscription management
3. Test subscription status refresh
4. Test restore purchases

**Dependencies:** Phase 3, Phase 5.1  
**Risk:** Low  
**Status:** 📋 **PENDING**

---

### **PHASE 6: Clean Up & Remove Dead Code** 🧹

#### Step 6.1: Remove SettingsRow Component
**File:** `ProfileView.swift` (end of file)

**Action:**
- Delete SettingsRow struct definition (lines 549-589)
- Already replaced by ProfileRow in previous steps

**Dependencies:** Phase 3.3 (must verify all SettingsRow removed)  
**Risk:** Low  
**Status:** 📋 **PENDING**

---

#### Step 6.2: Remove Old Header Code
**File:** N/A

**Action:**
- No old header code to remove (already using UnifiedHeaderBar)

**Dependencies:** N/A  
**Risk:** None  
**Status:** ✅ **N/A**

---

#### Step 6.3: Clean Up Imports & MARK Comments
**File:** `ProfileView.swift` (top)

**Actions:**
1. Add/update MARK comments for clarity
2. Organize imports
3. Remove unused imports
4. Document complex sections

**Dependencies:** All previous phases  
**Risk:** Low  
**Status:** 📋 **PENDING**

---

### **PHASE 7: Testing & Verification** ✅

#### Step 7.1: Visual Verification Checklist
**Action:** Manually test all UI states

- [ ] Light mode renders correctly
- [ ] Dark mode renders correctly
- [ ] Premium user header shows PRO badge
- [ ] Free user header shows Get PRO button
- [ ] ProCard displays correctly (free & premium)
- [ ] Premium status banner shows for premium users
- [ ] Account section cards render properly
- [ ] Settings section cards render properly
- [ ] Support section cards render properly
- [ ] Dividers show correctly between rows
- [ ] Section headers use `Typography.title3`
- [ ] Icon backgrounds are circular and tinted
- [ ] Chevrons show on tappable rows
- [ ] Spacing follows 8pt grid

**Dependencies:** All previous phases  
**Risk:** Low  
**Status:** 📋 **PENDING**

---

#### Step 7.2: Functionality Verification Checklist
**Action:** Test all user flows

- [ ] Tapping Get PRO in header → paywall sheet opens
- [ ] PRO badge in header (non-tappable)
- [ ] ProCard "Upgrade Now" → paywall sheet
- [ ] ProCard "Manage Subscription" → subscription management
- [ ] Sign in button (anonymous user) → sign in sheet
- [ ] Sign out → triggers sign out
- [ ] Theme selector → changes theme
- [ ] Language row → placeholder action (no implementation)
- [ ] Notifications row → toggle state (mock)
- [ ] Help & Support → opens URL
- [ ] Privacy Policy → opens URL
- [ ] Terms of Service → opens URL
- [ ] AI Service Disclosure → disclosure sheet
- [ ] Restore Purchases → restore alert
- [ ] Delete Account → confirmation alert
- [ ] Auth state changes refresh UI
- [ ] Premium status changes update header

**Dependencies:** All previous phases  
**Risk:** Low  
**Status:** 📋 **PENDING**

---

#### Step 7.3: Edge Cases & Error Handling
**Action:** Test boundary conditions

- [ ] Anonymous user sees sign in button
- [ ] Authenticated user sees account info
- [ ] Premium user sees all premium indicators
- [ ] Free user sees all upgrade CTAs
- [ ] Network error on restore purchases
- [ ] Delete account confirmation flow
- [ ] Theme switching in light/dark
- [ ] Auth state refresh trigger
- [ ] App background/foreground transitions

**Dependencies:** All previous phases  
**Risk:** Low  
**Status:** 📋 **PENDING**

---

#### Step 7.4: Final Code Review
**Action:** Code quality check

- [ ] No linter errors
- [ ] No compiler warnings
- [ ] Consistent DesignTokens usage
- [ ] Proper ThemeManager integration
- [ ] Clean MARK comments
- [ ] No dead code
- [ ] No duplicate components
- [ ] ProfileRow extracted to shared location
- [ ] Code follows project conventions
- [ ] README updated if needed

**Dependencies:** All previous phases  
**Risk:** Low  
**Status:** 📋 **PENDING**

---

## 🔗 Dependencies Graph

```
PHASE 1 (Components)
├── 1.1 Extract ProfileRow → PHASE 3
└── 1.2 Check Username → PHASE 3.2

PHASE 2 (Navigation)
├── 2.1 NavigationStack → Independent
└── 2.2 PRO Badge Header → Independent

PHASE 3 (Sections) ← Depends on PHASE 1
├── 3.1 Import ProfileRow ← Depends on 1.1
├── 3.2 Update Account ← Depends on 1.1, 1.2
└── 3.3 Update Settings ← Depends on 1.1

PHASE 4 (Layout) ← Depends on PHASE 3
├── 4.1 Fix Spacing
└── 4.2 Verify Theme

PHASE 5 (Logic) ← Depends on PHASE 3, 4
├── 5.1 Verify Sheets
├── 5.2 Verify Auth
├── 5.3 Verify Premium
└── 5.4 Verify Subscription

PHASE 6 (Cleanup) ← Depends on PHASE 3
└── 6.1 Remove SettingsRow

PHASE 7 (Testing) ← Depends on ALL PHASES
├── 7.1 Visual Checklist
├── 7.2 Functionality Checklist
├── 7.3 Edge Cases
└── 7.4 Code Review
```

---

## 📝 Implementation Notes

### Design Decisions Made

1. **Keep ProCard**: Premium CTA is important, different from subscription row
2. **Replace SettingsRow with ProfileRow**: Better design, more flexible
3. **Add PRO Badge to Header**: Consistent with HomeView
4. **Extract ProfileRow to Shared**: Avoid name conflicts, reuse
5. **Keep Theme Selector Menu**: Works well, no need to change
6. **Add Mock Language/Notifications**: Placeholders for future features

### Open Questions

1. **Username Display**: Does UserProfile have username? (Need to check)
2. **Quota Display**: Use ProfileRow or keep QuotaDisplayView? (Recommendation: keep QuotaDisplayView)
3. **ProfileRow Location**: Extract to shared or keep local? (Recommendation: extract)

---

## ✅ Success Criteria

### UI/UX
- [ ] Modern grouped card layout matches ProfilePreview design
- [ ] Header shows appropriate PRO badge or Get PRO button
- [ ] All sections use `Typography.title3` headers
- [ ] All rows use ProfileRow component with proper icons
- [ ] Consistent spacing (8pt grid)
- [ ] Theme-aware colors throughout
- [ ] Light/dark mode tested

### Functionality
- [ ] All existing features work (auth, subscription, sign out, delete)
- [ ] All sheets/alerts function correctly
- [ ] Premium status updates header dynamically
- [ ] Navigation and URL opening work
- [ ] No regressions in user flows

### Code Quality
- [ ] No linter errors or warnings
- [ ] ProfileRow extracted to shared location
- [ ] SettingsRow removed
- [ ] Clean, consistent DesignTokens usage
- [ ] Proper MARK comments and organization
- [ ] No dead code

---

## 🚀 Execution Strategy

### Recommended Approach

**Sequential Execution:**
1. Execute phases in order (1 → 2 → 3 → 4 → 5 → 6 → 7)
2. Complete each phase fully before moving to next
3. Test after Phase 3, 5, and 7

**Risk Mitigation:**
- Keep backup of original ProfileView.swift
- Test after each phase
- Use git commits per phase
- Verify no regressions

**Time Estimate:**
- Phase 1: 15 minutes
- Phase 2: 10 minutes
- Phase 3: 45 minutes
- Phase 4: 20 minutes
- Phase 5: 30 minutes
- Phase 6: 10 minutes
- Phase 7: 30 minutes
- **Total:** ~2.5 hours

---

**END OF MIGRATION PLAN**

*Ready for execution when approved.* 🎯

