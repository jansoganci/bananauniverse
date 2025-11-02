# LibraryView Migration Plan: Flat List → Grouped Card Layout with Date Sections

**Date:** 2025-11-02  
**Target:** Integrate LibraryPreview's modern grouped layout into LibraryView while preserving all functionality  
**Status:** 📋 PLANNING - Phase 0 (Analysis Complete)

---

## 📊 Comparative Analysis

### Current LibraryView.swift Structure

**Layout:**
```
NavigationView (❌ Legacy API)
├── UnifiedHeaderBar(title: "Library")
└── Conditional Content:
    ├── LoadingView (if loading + empty)
    ├── ErrorView (if error + empty)
    ├── EmptyHistoryView (if empty)
    └── HistoryList (ScrollView + LazyVStack)
        └── HistoryItemRow × N (flat list, simple dividers)
```

**Business Logic:**
- ✅ `@StateObject viewModel` - LibraryViewModel (async loading, state management)
- ✅ `@EnvironmentObject themeManager` - ThemeManager (theme support)
- ✅ `@State selectedImageURL` - Image detail sheet state
- ✅ State handling (loading, error, empty, content)
- ✅ Pull-to-refresh functionality
- ✅ Alert handling (error, delete confirmation)
- ✅ Sheet presentations (share, image detail)
- ✅ Action callbacks (tap, select, rerun, share, download, delete)

**Existing Components:**
- ✅ `HistoryList` - Scrollable list component with refresh
- ✅ `HistoryItemRow` - Row component with thumbnail, title, status, actions menu
- ✅ `LoadingView`, `ErrorView`, `EmptyHistoryView` - State components
- ✅ `StatusBadge` - Status indicator component

**Data Flow:**
```
LibraryViewModel
├── historyItems: [HistoryItem] (from Supabase)
├── isLoading, isRefreshing (state flags)
├── errorMessage, showingError (error handling)
└── Actions: loadHistory(), refreshHistory(), deleteJob(), etc.
```

**Navigation:**
- ❌ Uses deprecated `NavigationView` (should be `NavigationStack`)
- ✅ Header: `UnifiedHeaderBar(title: "Library")`

**Issues:**
- ❌ Flat list layout (no grouping)
- ❌ No date-based organization
- ❌ No "recent activity" quick access section
- ❌ Missing visual depth (no shadows, minimal spacing)

---

### LibraryPreview.swift Structure (Target Design)

**Layout:**
```
NavigationStack (✅ Modern API)
├── UnifiedHeaderBar(title: "History")
└── ScrollView
    └── VStack(spacing: DesignTokens.Spacing.lg)
        ├── Recent Activity Section
        │   ├── Section Header ("Recent Activity")
        │   └── Horizontal ScrollView
        │       └── RecentActivityCard × 4 (horizontal cards)
        ├── All History Section
        │   ├── Section Header ("All History")
        │   └── Date-Grouped Cards:
        │       ├── "Today" group (ProfileRow items in card)
        │       ├── "This Week" group (ProfileRow items in card)
        │       └── "Earlier" group (ProfileRow items in card)
        └── Clear History Button (optional)
```

**Visual Features:**
- ✅ Section headers with `Typography.title3`
- ✅ Grouped cards with `Surface.secondary` backgrounds
- ✅ `CornerRadius.md` on cards
- ✅ `Shadow.sm` on grouped sections
- ✅ Structured spacing (`Spacing.lg` between sections, `Spacing.md` padding)
- ✅ Date headers (`Typography.subheadline`, secondary color)

**Components:**
- ✅ `RecentActivityCard` - Horizontal preview card with thumbnail/icon
- ✅ `ProfileRow` - Reusable row component (icon, title, subtitle, chevron)
- ✅ `historyDateGroup()` - Helper function for date-grouped sections

**Limitations:**
- ❌ Mock data only (`PreviewHistoryItem`)
- ❌ No state handling (loading, error, empty)
- ❌ No functional actions (share, delete, download, rerun)
- ❌ No ViewModel integration
- ❌ No thumbnail loading (gradient placeholders only)

---

## 🔍 Architectural Differences

### Navigation Stack

| Aspect | LibraryView | LibraryPreview | Migration Impact |
|--------|-------------|----------------|------------------|
| **API** | `NavigationView` (iOS 13+) | `NavigationStack` (iOS 16+) | ✅ Low risk: Drop-in replacement |
| **Toolbar** | `.navigationBarHidden(true)` | `.toolbar(.hidden, for: .navigationBar)` | ✅ Low risk: Equivalent API |
| **Header** | `UnifiedHeaderBar(title: "Library")` | `UnifiedHeaderBar(title: "History")` | ⚠️ Medium: Title change requires consideration |

### Content Structure

| Aspect | LibraryView | LibraryPreview | Migration Impact |
|--------|-------------|----------------|------------------|
| **Container** | Conditional (Loading/Error/Empty/List) | Single ScrollView | ⚠️ Medium: Must preserve conditional states |
| **Spacing** | `LazyVStack(spacing: 0)` | `VStack(spacing: DesignTokens.Spacing.lg)` | ✅ Low risk: Spacing update |
| **Padding** | None (inherited) | `.padding(.horizontal, DesignTokens.Spacing.md)` | ✅ Low risk: Add padding |
| **Background** | `.background(DesignTokens.Background.primary)` | Same | ✅ No change needed |

### List Structure

| Aspect | LibraryView | LibraryPreview | Migration Impact |
|--------|-------------|----------------|------------------|
| **Layout** | Flat `LazyVStack` with dividers | Grouped `VStack` with date sections | ⚠️ Medium: Requires grouping logic |
| **Grouping** | None | Date-based (Today, This Week, Earlier) | ⚠️ Medium: Requires ViewModel changes |
| **Card Style** | None | Grouped cards with shadows | ✅ Low risk: Wrapper styling |
| **Items** | `HistoryItemRow` (thumbnail + actions) | `ProfileRow` (icon + chevron) | ❌ HIGH: Cannot replace (loses functionality) |

### Recent Activity Section

| Aspect | LibraryView | LibraryPreview | Migration Impact |
|--------|-------------|----------------|------------------|
| **Section** | ❌ Not present | ✅ Horizontal scroll section | ⚠️ Medium: New component required |
| **Card Type** | N/A | `RecentActivityCard` (icon placeholder) | ⚠️ Medium: Adapt for thumbnail loading |
| **Data Source** | N/A | Mock `PreviewHistoryItem` | ⚠️ Medium: Extract from `historyItems` |

---

## 🎯 Migration Strategy: What to Migrate vs Preserve

### ✅ **Direct Migration (Low Risk)**

1. **Navigation API Update**
   - Replace `NavigationView` → `NavigationStack`
   - Update `.navigationBarHidden(true)` → `.toolbar(.hidden, for: .navigationBar)`

2. **Spacing & Padding**
   - Add `.padding(.horizontal, DesignTokens.Spacing.md)` to content
   - Change `LazyVStack(spacing: 0)` → `VStack(spacing: DesignTokens.Spacing.lg)` where appropriate

3. **Visual Styling**
   - Add `designShadow(DesignTokens.Shadow.sm)` to grouped sections
   - Apply `CornerRadius.md` to card containers
   - Use `Surface.secondary` for card backgrounds

4. **Section Headers**
   - Add "Recent Activity" and "All History" section headers
   - Use `Typography.title3` for headers

### ⚠️ **Adaptation Required (Medium Risk)**

1. **Date Grouping Logic**
   - Create date grouping function in `LibraryViewModel`
   - Group `HistoryItem` array by: Today, This Week, Earlier
   - Return structured data for UI consumption

2. **RecentActivityCard Component**
   - Create new component accepting `HistoryItem` (not `PreviewHistoryItem`)
   - Load real thumbnails using `AsyncImage` (not gradient placeholders)
   - Extract recent items (top 4-6) from `historyItems`

3. **HistoryList Refactoring**
   - Refactor to show grouped date sections
   - Preserve all existing actions (menu, share, download, delete)
   - Keep `HistoryItemRow` component (DO NOT replace with ProfileRow)
   - Wrap grouped items in card container

4. **Header Title**
   - Consider changing "Library" → "History" (optional, requires design approval)

### ❌ **DO NOT Migrate (Preserve Existing)**

1. **HistoryItemRow Component**
   - ✅ **KEEP:** Thumbnail display (more valuable than icon-only)
   - ✅ **KEEP:** Action menu (rerun, share, download, delete)
   - ✅ **KEEP:** Status badge
   - ✅ **KEEP:** All gesture handlers

2. **Functional Logic**
   - ✅ **KEEP:** All ViewModel methods (loadHistory, refreshHistory, deleteJob, etc.)
   - ✅ **KEEP:** State handling (loading, error, empty states)
   - ✅ **KEEP:** All callbacks and action handlers
   - ✅ **KEEP:** Sheet presentations and alerts

3. **Mock Data Structures**
   - ❌ **SKIP:** `PreviewHistoryItem` model (use existing `HistoryItem`)
   - ❌ **SKIP:** Static mock arrays (use ViewModel data)

4. **Clear History Button**
   - ⚠️ **DEFER:** Requires backend support (not in current scope)

---

## 📋 Phase-by-Phase Migration Plan

### Phase 1: Navigation & Visual Foundation ⚡

**Goal:** Update navigation API and add visual polish (spacing, shadows, section structure)

**Risk Level:** 🟢 **LOW**

**Files to Modify:**
1. `BananaUniverse/Features/Library/Views/LibraryView.swift`
2. `BananaUniverse/Features/Library/Views/Components/HistoryList.swift`

**Changes:**

#### File 1: LibraryView.swift

```swift
// BEFORE:
NavigationView {
    VStack(spacing: 0) {
        UnifiedHeaderBar(title: "Library")
        // ... content
    }
    .navigationTitle("")
    .navigationBarHidden(true)
}

// AFTER:
NavigationStack {  // ✅ Updated API
    VStack(spacing: 0) {
        UnifiedHeaderBar(
            title: "History"  // ⚠️ Optional: Consider title change
        )
        // ... content
    }
    .navigationTitle("")
    .toolbar(.hidden, for: .navigationBar)  // ✅ Updated API
}
```

#### File 2: HistoryList.swift

```swift
// BEFORE:
ScrollView {
    LazyVStack(spacing: 0) {
        ForEach(items) { item in
            HistoryItemRow(...)
            Divider()
        }
    }
}

// AFTER:
ScrollView {
    VStack(spacing: DesignTokens.Spacing.lg) {  // ✅ Add spacing
        // All History Section Header
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("All History")
                .font(DesignTokens.Typography.title3)
                .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.top, DesignTokens.Spacing.md)
            
            // Date-grouped content will go here in Phase 2
            // For now, keep existing flat list temporarily
            LazyVStack(spacing: 0) {
                ForEach(items) { item in
                    HistoryItemRow(...)
                    Divider()
                }
            }
        }
    }
    .padding(.horizontal, DesignTokens.Spacing.md)  // ✅ Add horizontal padding
}
```

**Verification:**
- ✅ App builds successfully
- ✅ Navigation works correctly
- ✅ Visual spacing improved
- ✅ All existing functionality preserved

**Estimated Time:** 2-3 hours

---

### Phase 2: Date Grouping Logic 📅

**Goal:** Add date grouping functionality to ViewModel and create grouped UI structure

**Risk Level:** 🟡 **MEDIUM**

**Files to Modify:**
1. `BananaUniverse/Features/Library/ViewModels/LibraryViewModel.swift` (NEW methods)
2. `BananaUniverse/Features/Library/Views/Components/HistoryList.swift` (refactor to use grouped data)

**Changes:**

#### File 1: LibraryViewModel.swift

Add date grouping computed properties and helper methods:

```swift
// MARK: - Date Grouping (NEW)

/// Groups history items by date categories
struct HistoryDateGroup {
    let header: String
    let items: [HistoryItem]
}

extension LibraryViewModel {
    /// Recent items for horizontal preview section (top 4-6 items)
    var recentActivityItems: [HistoryItem] {
        Array(historyItems.prefix(6))
    }
    
    /// Groups history items by date: Today, This Week, Earlier
    var groupedHistoryItems: [HistoryDateGroup] {
        let calendar = Calendar.current
        let now = Date()
        
        var groups: [HistoryDateGroup] = []
        var todayItems: [HistoryItem] = []
        var thisWeekItems: [HistoryItem] = []
        var earlierItems: [HistoryItem] = []
        
        for item in historyItems {
            let daysSince = calendar.dateComponents([.day], from: item.createdAt, to: now).day ?? 0
            
            if calendar.isDateInToday(item.createdAt) {
                todayItems.append(item)
            } else if daysSince <= 7 {
                thisWeekItems.append(item)
            } else {
                earlierItems.append(item)
            }
        }
        
        // Add groups only if they have items
        if !todayItems.isEmpty {
            groups.append(HistoryDateGroup(header: "Today", items: todayItems))
        }
        if !thisWeekItems.isEmpty {
            groups.append(HistoryDateGroup(header: "This Week", items: thisWeekItems))
        }
        if !earlierItems.isEmpty {
            groups.append(HistoryDateGroup(header: "Earlier", items: earlierItems))
        }
        
        return groups
    }
}
```

**Note:** Add `HistoryDateGroup` struct at the top of the file or in a separate Models file.

#### File 2: HistoryList.swift

Refactor to accept and display grouped data:

```swift
// UPDATE: Accept grouped data
struct HistoryList: View {
    let items: [HistoryItem]  // Keep for backward compatibility
    let groupedItems: [HistoryDateGroup]  // NEW: Grouped data
    // ... rest of properties unchanged
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.lg) {
                // All History Section
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    Text("All History")
                        .font(DesignTokens.Typography.title3)
                        .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                    
                    // Date-grouped sections
                    VStack(spacing: DesignTokens.Spacing.lg) {
                        ForEach(groupedItems, id: \.header) { group in
                            historyDateGroup(
                                header: group.header,
                                items: group.items,
                                themeManager: themeManager,
                                onItemTap: onItemTap,
                                onSelect: onSelect,
                                onRerun: onRerun,
                                onShare: onShare,
                                onDownload: onDownload,
                                onDelete: onDelete
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
        }
        .refreshable {
            await onRefresh()
        }
    }
    
    // NEW: Date group helper function
    @ViewBuilder
    private func historyDateGroup(
        header: String,
        items: [HistoryItem],
        themeManager: ThemeManager,
        onItemTap: @escaping (HistoryItem) -> Void,
        onSelect: @escaping (HistoryItem) -> Void,
        onRerun: @escaping (HistoryItem) async -> Void,
        onShare: @escaping (HistoryItem) -> Void,
        onDownload: @escaping (HistoryItem) async -> Void,
        onDelete: @escaping (HistoryItem) async -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            // Date Header
            Text(header)
                .font(DesignTokens.Typography.subheadline)
                .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.top, DesignTokens.Spacing.xs)
            
            // Grouped Items Card
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    HistoryItemRow(
                        item: item,
                        onTap: { onItemTap(item) },
                        onSelect: { onSelect(item) },
                        onRerun: { Task { await onRerun(item) } },
                        onShare: { onShare(item) },
                        onDownload: { Task { await onDownload(item) } },
                        onDelete: { Task { await onDelete(item) } }
                    )
                    
                    if index < items.count - 1 {
                        Divider()
                            .background(DesignTokens.Surface.secondary(themeManager.resolvedColorScheme))
                            .padding(.leading, 80)  // Match thumbnail width + padding
                    }
                }
            }
            .background(DesignTokens.Surface.secondary(themeManager.resolvedColorScheme))
            .cornerRadius(DesignTokens.CornerRadius.md)
            .designShadow(DesignTokens.Shadow.sm)
        }
    }
}
```

#### File 3: LibraryView.swift

Update to pass grouped data:

```swift
// UPDATE: Pass grouped items
HistoryList(
    items: viewModel.historyItems,  // Keep for compatibility
    groupedItems: viewModel.groupedHistoryItems,  // NEW
    isRefreshing: viewModel.isRefreshing,
    onRefresh: { await viewModel.refreshHistory() },
    // ... rest of callbacks unchanged
)
```

**Verification:**
- ✅ Date grouping works correctly
- ✅ Items appear in correct date sections
- ✅ All actions (tap, menu, delete) work
- ✅ Pull-to-refresh updates groups
- ✅ Empty states handled correctly

**Estimated Time:** 4-6 hours

---

### Phase 3: Recent Activity Horizontal Section 🎯

**Goal:** Add horizontal "Recent Activity" section with preview cards

**Risk Level:** 🟡 **MEDIUM**

**Files to Create:**
1. `BananaUniverse/Features/Library/Views/Components/RecentActivityCard.swift` (NEW)

**Files to Modify:**
1. `BananaUniverse/Features/Library/Views/LibraryView.swift` (add section)
2. `BananaUniverse/Features/Library/Views/Components/HistoryList.swift` (optional: integrate or keep separate)

**Changes:**

#### File 1: RecentActivityCard.swift (NEW)

```swift
//
//  RecentActivityCard.swift
//  BananaUniverse
//
//  Horizontal preview card for recent activity section
//

import SwiftUI

struct RecentActivityCard: View {
    let item: HistoryItem
    let onTap: () -> Void
    
    @EnvironmentObject var themeManager: ThemeManager
    
    private var colorScheme: ColorScheme {
        themeManager.resolvedColorScheme
    }
    
    // Typography.bodyMedium equivalent
    private var bodyMedium: Font {
        Font.system(size: 17, weight: .medium, design: .default)
    }
    
    var body: some View {
        Button(action: {
            DesignTokens.Haptics.impact(.light)
            onTap()
        }) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                // Thumbnail (real image or fallback)
                Group {
                    if let thumbnailURL = item.thumbnailURL {
                        AsyncImage(url: thumbnailURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .failure(_), .empty:
                                // Fallback to gradient with icon
                                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                DesignTokens.Brand.primary(colorScheme).opacity(0.6),
                                                DesignTokens.Brand.secondary(colorScheme).opacity(0.4)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .overlay(
                                        Image(systemName: iconForEffect(item.effectId))
                                            .font(.system(size: 32, weight: .medium))
                                            .foregroundColor(.white.opacity(0.9))
                                    )
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        // No thumbnail: show gradient placeholder
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        DesignTokens.Brand.primary(colorScheme).opacity(0.6),
                                        DesignTokens.Brand.secondary(colorScheme).opacity(0.4)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Image(systemName: iconForEffect(item.effectId))
                                    .font(.system(size: 32, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                            )
                    }
                }
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md))
                .designShadow(DesignTokens.Shadow.md)
                
                // Title
                Text(item.effectTitle)
                    .font(bodyMedium)
                    .foregroundColor(DesignTokens.Text.primary(colorScheme))
                    .lineLimit(2)
                    .frame(width: 120, alignment: .leading)
                
                // Time ago
                Text(item.relativeDate)
                    .font(DesignTokens.Typography.caption1)
                    .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                    .frame(width: 120, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("\(item.effectTitle), \(item.relativeDate)")
        .accessibilityHint("Double tap to view")
    }
    
    // Helper: Map effect ID to SF Symbol
    private func iconForEffect(_ effectId: String) -> String {
        switch effectId {
        case "nano-banana-edit":
            return "wand.and.stars"
        case "upscale":
            return "arrow.up.circle.fill"
        default:
            return "photo.fill"
        }
    }
}
```

#### File 2: LibraryView.swift

Add Recent Activity section before HistoryList:

```swift
// Inside contentView or body (after header, before HistoryList):
if !viewModel.historyItems.isEmpty {
    ScrollView {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // Recent Activity Section (NEW)
            if !viewModel.recentActivityItems.isEmpty {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    Text("Recent Activity")
                        .font(DesignTokens.Typography.title3)
                        .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DesignTokens.Spacing.md) {
                            ForEach(viewModel.recentActivityItems.prefix(4)) { item in
                                RecentActivityCard(item: item) {
                                    if let resultURL = item.resultURL {
                                        selectedImageURL = resultURL
                                    }
                                    viewModel.navigateToResult(item)
                                }
                            }
                        }
                        .padding(.horizontal, DesignTokens.Spacing.md)
                    }
                    .padding(.horizontal, -DesignTokens.Spacing.md)
                }
                .padding(.top, DesignTokens.Spacing.md)
            }
            
            // All History Section (existing HistoryList)
            HistoryList(
                items: viewModel.historyItems,
                groupedItems: viewModel.groupedHistoryItems,
                // ... rest unchanged
            )
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
    }
}
```

**Verification:**
- ✅ Recent Activity section appears when items exist
- ✅ Cards load thumbnails correctly
- ✅ Tap actions work
- ✅ Horizontal scroll functions properly
- ✅ Fallback gradients show for missing thumbnails

**Estimated Time:** 4-5 hours

---

### Phase 4: Testing & Refinement ✅

**Goal:** Comprehensive testing, bug fixes, and polish

**Risk Level:** 🟢 **LOW**

**Testing Checklist:**

#### Functional Testing
- [ ] Navigation works correctly (NavigationStack)
- [ ] Loading state displays correctly
- [ ] Error state displays correctly
- [ ] Empty state displays correctly
- [ ] Pull-to-refresh updates all sections
- [ ] Date grouping logic is accurate (Today, This Week, Earlier)
- [ ] Recent Activity shows correct items (top 4-6)
- [ ] All actions work: tap, select, rerun, share, download, delete
- [ ] Menu actions function correctly
- [ ] Sheet presentations work (share, image detail)

#### Visual Testing
- [ ] Spacing matches DesignTokens (lg between sections, md padding)
- [ ] Shadows appear correctly on grouped cards
- [ ] Corner radius applied to cards
- [ ] Section headers styled correctly
- [ ] Date headers styled correctly (secondary text)
- [ ] Theme switching works (light/dark)
- [ ] Thumbnails load and display correctly
- [ ] Recent Activity cards display correctly
- [ ] Horizontal scroll works smoothly

#### Edge Cases
- [ ] Empty history state (no items)
- [ ] Single item in history
- [ ] All items in "Today" category
- [ ] All items in "Earlier" category
- [ ] Missing thumbnails (fallback display)
- [ ] Very long titles (text truncation)
- [ ] Network errors during refresh
- [ ] Large number of items (performance)

#### Accessibility
- [ ] VoiceOver labels correct
- [ ] Touch targets meet 44pt minimum
- [ ] Dynamic Type support
- [ ] Color contrast ratios

**Refinement Tasks:**

1. **Performance Optimization**
   - Cache grouped results (only recompute when `historyItems` changes)
   - Lazy load thumbnails in Recent Activity
   - Optimize date calculations

2. **Visual Polish**
   - Smooth animations for section transitions
   - Loading states for Recent Activity thumbnails
   - Error states for failed thumbnail loads

3. **Code Cleanup**
   - Remove any temporary code
   - Add inline documentation
   - Ensure consistent naming

**Estimated Time:** 6-8 hours (testing) + 2-3 hours (refinement)

---

## 📁 File Summary

### Files Modified

1. **LibraryView.swift**
   - Navigation API update
   - Recent Activity section integration
   - Grouped data passing

2. **HistoryList.swift**
   - Accept grouped data
   - Date group helper function
   - Card styling and shadows
   - Section header

3. **LibraryViewModel.swift**
   - Date grouping computed properties
   - Recent activity items property

### Files Created

1. **RecentActivityCard.swift** (NEW)
   - Horizontal preview card component
   - Thumbnail loading with fallback
   - Tap action handling

2. **HistoryDateGroup.swift** (NEW - Optional)
   - Data structure for grouped items
   - Can be in ViewModel file or separate

### Files Unchanged (Preserved)

- ✅ `HistoryItemRow.swift` - All functionality preserved
- ✅ `LoadingView.swift` - No changes
- ✅ `ErrorView.swift` - No changes
- ✅ `EmptyHistoryView.swift` - No changes
- ✅ `StatusBadge.swift` - No changes

---

## ⚠️ Risk Assessment

### Low Risk ✅
- Navigation API update (drop-in replacement)
- Spacing and padding adjustments
- Visual styling (shadows, corners)

### Medium Risk ⚠️
- Date grouping logic (requires testing with various dates)
- Recent Activity component (thumbnail loading edge cases)
- HistoryList refactoring (must preserve all callbacks)

### High Risk ❌
- None identified (all functional logic preserved)

---

## 🚫 Excluded from Migration

### Design Elements NOT Migrated
1. **ProfileRow in List Items**
   - ❌ Excluded: Would lose thumbnails and actions menu
   - ✅ Preserved: HistoryItemRow with full functionality

2. **Clear History Button**
   - ❌ Deferred: Requires backend API support
   - 📅 Future: Can be added after backend is ready

3. **Mock Data Structures**
   - ❌ Skipped: Use existing `HistoryItem` model
   - ✅ Preserved: Real data from ViewModel

---

## 📊 Success Criteria

### Visual Goals ✅
- [ ] Grouped card layout matches Preview design
- [ ] Date sections appear correctly
- [ ] Recent Activity section visible
- [ ] Shadows and spacing consistent with DesignTokens
- [ ] Theme-aware styling works

### Functional Goals ✅
- [ ] All existing actions work (100% preserved)
- [ ] State handling works (loading, error, empty)
- [ ] Date grouping is accurate
- [ ] Performance is maintained (no regressions)
- [ ] Accessibility maintained

### Code Quality Goals ✅
- [ ] No breaking changes to API
- [ ] Clean, maintainable code
- [ ] Proper error handling
- [ ] Documentation updated

---

## 📅 Estimated Timeline

| Phase | Duration | Risk | Dependencies |
|-------|----------|------|--------------|
| **Phase 1** | 2-3 hours | Low | None |
| **Phase 2** | 4-6 hours | Medium | Phase 1 |
| **Phase 3** | 4-5 hours | Medium | Phase 1 |
| **Phase 4** | 8-11 hours | Low | Phases 1-3 |
| **Total** | **18-25 hours** | - | - |

**Recommended Approach:**
- Week 1: Phases 1-2 (Navigation + Date Grouping)
- Week 2: Phase 3 (Recent Activity) + Phase 4 Start
- Week 3: Phase 4 Completion (Testing & Refinement)

---

## 🎯 Next Steps

1. **Review & Approval**
   - Review migration plan with team
   - Get design approval for "Library" → "History" title change
   - Confirm date grouping logic requirements

2. **Preparation**
   - Create feature branch: `feature/library-view-migration`
   - Set up testing environment
   - Prepare test data with various dates

3. **Execution**
   - Follow phase-by-phase plan
   - Test after each phase
   - Document any deviations

4. **Deployment**
   - Code review
   - QA testing
   - Staged rollout (optional)

---

**Document Version:** 1.0  
**Last Updated:** 2025-11-02  
**Status:** 📋 Ready for Implementation

