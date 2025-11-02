# Home & Chat Refactor — Phase-Based Action Plan

**Last Updated:** 2025-10-31  
**Status:** 📋 Execution Plan  
**Aligned With:** `BananaUniverse_HomeChat_Scope_Analysis.md` + `FE_BE_Impact_Analysis_HomeChat.md`

---

## 📝 Changelog — Corrections

**2025-10-31:** Event-driven session architecture
- Added AppState/SessionStore with sessionId-based reactivity
- Replaced onChange(of: chatPrompt) with onChange(of: sessionId)
- Added ChatViewModel.reset() and apply(prompt:) contracts
- Removed onAppear coupling for prompt/picker logic
- Added same-prompt re-selection acceptance test
- Enhanced race condition mitigation in Phase 1

---

## 🎯 Overview

This plan breaks the Home & Chat redesign into **5 testable phases**. Each phase delivers working functionality and ends with verifiable acceptance checks. Serial execution only—no skipping ahead.

**Timeline Estimate:** 8-12 hours total development  
**Testing Strategy:** Manual QA per phase + end-to-end smoke test

---

## Phase 0 — Prep & Setup

**Goal:** Validate scope, define testing matrix, document console events  
**Duration:** 30 mins (no code changes)

### Tasks

#### 1. Confirm File Inventory
- [ ] Verify `HomeView.swift` exists and exports `onToolSelected` callback
- [ ] Verify `ChatView.swift` has WhatsApp-style messaging
- [ ] Verify `ContentView.swift` uses `@StateObject appState: AppState` and sessionId-based reactivity (`.onChange(of: appState.sessionId)`)
- [ ] Verify `ToolCard.swift` shows icon + title + description
- [ ] Verify `UnifiedHeaderBar.swift` supports Pro badge logic
- [ ] Verify `ChatViewModel.swift` has `reset()` and `apply(prompt:)`, plus in-flight cancellation storage
- [ ] Verify `FeaturedToolCard.swift` exists (will be removed in Phase 2)
- [ ] Verify `CategoryFeaturedMapping.swift` provides featured tools
- [ ] Verify `DesignTokens.swift` has centralized colors, haptics

#### 2. Define Test Device Matrix
- [ ] **iPhone SE (3rd gen)** — 375pt width, 2-col grid baseline
- [ ] **iPhone 14/15** — 393pt width, 2-col grid
- [ ] **iPhone 14/15 Plus** — 428pt width, 2-col grid
- [ ] **Dark/Light mode** — Theme switching on all devices
- [ ] **Edge cases:** Tab switching mid-processing, background/foreground transitions

#### 3. Define Console Event Names
```swift
// Console-only analytics (standardized payload with sessionId)
logEvent("carousel_click", ["item_id": tool.id, "position": index, "session_id": appState.sessionId.uuidString])
logEvent("card_select", ["tool_id": tool.id, "category": category, "session_id": appState.sessionId.uuidString])
logEvent("search_performed", ["query": query, "results_count": count, "session_id": appState.sessionId.uuidString])
logEvent("chat_start", ["source": "preset", "tool_id": appState.selectedToolId ?? "", "prompt_len": prompt.count, "session_id": appState.sessionId.uuidString])
logEvent("purchase_click", ["placement": "home_get_pro", "session_id": appState.sessionId.uuidString])
logEvent("paywall_view", ["placement": placement, "session_id": appState.sessionId.uuidString])
```

#### 4. Set Up Branch
- [ ] Create feature branch: `feature/home-chat-refactor`
- [ ] Confirm base branch: `main`
- [ ] No merge yet—work in feature branch only

---

## Phase 1 — State & Wiring (FE)

**Goal:** AppState + single ChatViewModel at root, session-based navigation flow working  
**Duration:** 2-3 hours  
**Files Modified:** `ContentView.swift`, `ChatView.swift`, `ChatViewModel.swift`  
**Files Created:** `AppState.swift`  
**Note:** `AppState` should be `@MainActor` if async usage exists.

### Tasks

#### 1. Create AppState / SessionStore
```swift
// AppState.swift (new file)
class AppState: ObservableObject {
    @Published var sessionId: UUID = UUID()
    @Published var selectedToolId: String?
    @Published var currentPrompt: String?
    
    func selectPreset(id: String, prompt: String) {
        sessionId = UUID()  // Force new session
        selectedToolId = id
        currentPrompt = prompt
    }
}
```

- [ ] Create new file: `BananaUniverse/Core/Services/AppState.swift`
- [ ] Implement `AppState` class with `sessionId`, `selectedToolId`, `currentPrompt`
- [ ] Add `selectPreset(id:prompt:)` that creates new UUID
- [ ] Mark as `@MainActor` if using async/await

#### 2. Lift ChatViewModel to ContentView
```swift
// ContentView.swift changes
- Add: @StateObject private var appState = AppState()
- Add: @StateObject private var chatViewModel = ChatViewModel()
- Pass: ChatView(initialPrompt: appState.currentPrompt, viewModel: chatViewModel)
- Remove: @StateObject private var viewModel = ChatViewModel() from ChatView
```

- [ ] Add `@StateObject private var appState = AppState()` to `ContentView`
- [ ] Add `@StateObject private var chatViewModel = ChatViewModel()` to `ContentView`
- [ ] Pass `viewModel: chatViewModel` to `ChatView` initializer
- [ ] Remove `@StateObject` from `ChatView`
- [ ] Update `ChatView` to accept `viewModel` as parameter
- [ ] Verify no duplicate ChatViewModel instances

#### 3. Add sessionId-based onChange Flow
```swift
// ContentView.swift additions
.onChange(of: appState.sessionId) { _ in
    chatViewModel.reset()
    chatViewModel.apply(appState.currentPrompt)
}
```

- [ ] Add `.onChange(of: appState.sessionId)` handler to `ContentView`
- [ ] Call `chatViewModel.reset()` inside handler
- [ ] Call `chatViewModel.apply(appState.currentPrompt)` inside handler
- [ ] Ensure handler runs before Chat tab switch

#### 4. Implement ChatViewModel.reset()
```swift
// ChatViewModel.swift additions
func reset() {
    messages = []
    selectedImage = nil
    selectedImageItem = nil
    errorMessage = nil
    uploadProgress = 0.0
    jobStatus = .idle
    currentJobID = nil
    // Cancel all in-flight async work
    for task in inFlightTasks {
        task.cancel()
    }
    inFlightTasks.removeAll()
}

private var inFlightTasks: [Task<Void, Never>] = []
```

- [ ] Add `reset()` method to `ChatViewModel`
- [ ] Clear messages, selectedImage, errorMessage, progress
- [ ] Cancel all in-flight Tasks/AnyCancellable
- [ ] Add `inFlightTasks` storage array
- [ ] Store Tasks when starting async work

#### 5. Implement ChatViewModel.apply(prompt:)
```swift
// ChatViewModel.swift additions
func apply(prompt: String?) {
    currentPrompt = prompt
    // Picker opens via flag bound to sessionId change (NOT onAppear)
}
```

- [ ] Add `apply(prompt:)` method to `ChatViewModel`
- [ ] Set `currentPrompt = prompt`
- [ ] Do NOT trigger picker here (picker opens via sessionId change)

#### 6. Handle "Chat Visible" vs "Chat Hidden" Cases
```swift
// Scenario A: Chat hidden
- Preset tap → AppState.selectPreset() → sessionId changes
- .onChange fires → Reset + Apply → Switch to Chat

// Scenario B: Chat visible
- Preset tap → AppState.selectPreset() → sessionId changes
- .onChange fires → Reset + Apply → Chat re-renders
```

- [ ] Test: Navigate from Home → Chat with preset tap
- [ ] Test: Tap another card while Chat is visible
- [ ] Verify prompt updates in both scenarios

#### 7. Update Navigation Flow
```swift
// ContentView.swift - navigateToChatWithPrompt
private func navigateToChatWithPrompt(_ id: String, prompt: String) {
    appState.selectPreset(id: id, prompt: prompt)  // Creates new session
    selectedTab = 1  // Switch to Chat tab
}
```

- [ ] Update `navigateToChatWithPrompt` to call `appState.selectPreset()`
- [ ] Pass `tool.id` and `tool.prompt` as parameters
- [ ] Verify new session is created on every tap

#### 8. Guardrails
- [ ] No `onAppear` coupling for preset updates
- [ ] No `onAppear` for picker open logic
- [ ] Picker opens via flag bound to `sessionId` change
- [ ] Avoid nested NavigationView

### Acceptance Checks

- [ ] **Preset prefill works:** Tap card → Chat shows correct prompt
- [ ] **No stale state:** Tap card A, then card B → Chat shows card B prompt
- [ ] **Same-prompt re-selection:** Tap same card twice → second tap resets and applies again
- [ ] **Start disabled logic:** Start button disabled until `selectedImage != nil && currentPrompt != nil`
- [ ] **Single instance:** Only one ChatViewModel instance in memory
- [ ] **Navigation works:** Card tap switches to Chat tab
- [ ] **In-flight cancellation:** Start processing, then tap new card → old task cancels
- [ ] **Console logs:** No errors or warnings

**Smoke Test:**
1. Launch app → Home tab
2. Tap any tool card
3. Verify Chat tab opens with prefilled prompt
4. Tap another card (without processing first image)
5. Verify Chat updates to new prompt
6. Tap same card again
7. Verify fresh session starts (reset + apply)
8. Start processing an image
9. Tap new card mid-processing
10. Verify old task cancels (no stale toasts/replies)

---

## Phase 2 — Home UI (FE)

**Goal:** Header badge, search bar, 5-item carousel, collapsible category sections (Option 3), minimal cards  
**Duration:** 4-5 hours (increased due to collapsible sections)  
**Files Modified:** `HomeView.swift`, `ToolCard.swift`, `ToolGridSection.swift`, new: `FeaturedCarouselView.swift`, new: `CollapsibleCategorySection.swift`  
**Files Removed:** `FeaturedToolCard.swift`, `CategoryTabs.swift` (removed from HomeView)

### Tasks

#### 1. Header Badge Logic
```swift
// HomeView.swift - UnifiedHeaderBar usage
rightContent: creditManager.isPremiumUser 
    ? .unlimitedBadge({})  // PRO badge (non-tappable)
    : .getProButton({ showPaywall = true })  // Get Pro button (tappable)
```

- [ ] Verify `UnifiedHeaderBar` already supports `.unlimitedBadge` and `.getProButton`
- [ ] Add `@StateObject private var creditManager = HybridCreditManager.shared` to `HomeView`
- [ ] Set `rightContent` based on `creditManager.isPremiumUser`
- [ ] Test with mock subscription states (Pro vs free)
- [ ] Fire haptic on card tap (`card_select`) in `HomeView` tap handler: `DesignTokens.Haptics.impact(.light)`

#### 2. Search Bar Implementation
```swift
// HomeView.swift additions
@State private var searchQuery: String = ""
@State private var searchDebounceTimer: Timer?

func updateSearch(_ query: String) {
    searchDebounceTimer?.invalidate()
    searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3) { [self] in
        searchQuery = query
    }
}
```

- [ ] Add search bar UI below header (iOS native `TextField` with search style)
- [ ] Add debounce logic (300ms delay)
- [ ] Add `searchQuery` state variable
- [ ] Hide carousel immediately when `!searchQuery.isEmpty`
- [ ] Show carousel again when `searchQuery.isEmpty`
- [ ] Filter tools by title (case-insensitive) - filtering happens in category sections
- [ ] Log: `logEvent("search_performed", ["query": searchQuery, "results_count": filteredTools.count, "session_id": appState.sessionId.uuidString])`

#### 3. Featured Carousel Component (New File)
**Create:** `BananaUniverse/Core/Components/FeaturedCarousel/FeaturedCarouselView.swift`

```swift
// FeaturedCarouselView requirements
- 5 items total (from all categories via CategoryFeaturedMapping)
- Single visible item at a time
- Auto-advance: every 3 seconds (infinite loop, never stops)
- Pause on touch/drag
- Resume after 2 seconds idle
- Page dots indicator
- Horizontal swipe navigation
```

- [ ] Create new component file: `FeaturedCarouselView.swift`
- [ ] Implement carousel with 5 items (TabView with `.tabViewStyle(.page)`)
- [ ] Display single visible item at a time
- [ ] Add auto-advance timer (3s interval, infinite loop)
- [ ] Pause on `onTapGesture` or drag gesture
- [ ] Resume after 2s idle (separate idle timer)
- [ ] Add page dots below carousel (shows 5 dots)
- [ ] Cancel timers on `onDisappear`
- [ ] Log: `logEvent("carousel_click", ["item_id": tool.id, "session_id": appState.sessionId.uuidString])`
- [ ] Replace `FeaturedToolCard` in `HomeView` with `FeaturedCarouselView`
- [ ] Position carousel below search bar (correct layout order)
- [ ] Also fire `DesignTokens.Haptics.impact(.light)` on carousel item tap before navigation

#### 4. Simplify Tool Card
```swift
// ToolCard.swift changes
- Remove: description text
- Remove: icon at bottom
- Remove: badge logic
- Keep: image placeholder (SF Symbol)
- Keep: title (2-line limit)
```

- [ ] Edit `ToolCard.swift` to remove description
- [ ] Remove icon row (keep only image placeholder)
- [ ] Remove badge rendering
- [ ] Keep title (2-line truncation)
- [ ] Maintain card height (160pt for consistency)

#### 5. Create Collapsible Category Section Component (New File)
**Create:** `BananaUniverse/Core/Components/CollapsibleCategorySection/CollapsibleCategorySection.swift`

```swift
// CollapsibleCategorySection requirements
- Section header with category name (simple text for MVP)
- Expand/collapse indicator (chevron: ▶ when collapsed, ▼ when expanded)
- Tap header to toggle expand/collapse
- When expanded: 2-column grid of tool cards
- When collapsed: Header only (no tools visible)
- Spring animation for expand/collapse
```

- [ ] Create new component file: `CollapsibleCategorySection.swift`
- [ ] Accept parameters: `categoryId`, `categoryName`, `tools`, `isExpanded`, `onToggle`, `onToolTap`
- [ ] Implement section header with text label + chevron
- [ ] Add tap gesture to header for expand/collapse
- [ ] Use `ToolGridSection` for grid when expanded
- [ ] Add spring animation: `.animation(.spring(), value: isExpanded)`
- [ ] Filter tools by search query if provided (maintains in section)

#### 6. Update HomeView with Collapsible Sections
```swift
// HomeView.swift changes
@State private var expandedCategories: Set<String> = ["main_tools"] // Default: Photo Editor expanded

// Remove CategoryTabs component
// Add CollapsibleCategorySection for each category
```

- [ ] Remove `CategoryTabs` component from HomeView
- [ ] Add `@State private var expandedCategories: Set<String> = ["main_tools"]` (default: Photo Editor)
- [ ] Iterate through all categories: `["main_tools", "seasonal", "pro_looks", "restoration"]`
- [ ] Create `CollapsibleCategorySection` for each category
- [ ] Pass filtered tools to each section (based on search query)
- [ ] Maintain expand/collapse state per section
- [ ] Ensure sections positioned below carousel

#### 7. Force 2-Column Grid in ToolGridSection
```swift
// ToolGridSection.swift changes
// Update calculateColumns to always return 2 for iPhone
private func calculateColumns(for width: CGFloat) -> Int {
    // Force 2 columns for all iPhone categories
    return 2
}
```

- [ ] Update `ToolGridSection.calculateColumns` to always return 2
- [ ] Remove category-dependent column logic
- [ ] Test on all device sizes (should stay 2-column)
- [ ] Files Modified includes `ToolGridSection.swift`

### Acceptance Checks

- [ ] **Layout order:** Header → Search → Carousel → Grid (correct vertical order)
- [ ] **Header badge:** Shows "PRO" when subscribed, "Get Pro" when not
- [ ] **Search bar:** Below header (top of page), 300ms debounce, no lag, smooth typing
- [ ] **Search filtering:** Tools filter by title (case-insensitive match)
- [ ] **Carousel hides:** Carousel hidden immediately when search query non-empty
- [ ] **Carousel shows:** Carousel visible when search query empty
- [ ] **Carousel:** 5 items total, single visible item, auto-advance every 3 seconds, infinite loop
- [ ] **Auto-advance:** Advances every 3 seconds (loops forever)
- [ ] **Pause/resume:** Pauses on touch/drag, resumes after 2s idle
- [ ] **Collapsible sections:** Category sections with expand/collapse
- [ ] **Default state:** "Photo Editor" expanded, all others collapsed
- [ ] **Section headers:** Simple text labels, tap to toggle expand/collapse
- [ ] **Spring animation:** Smooth expand/collapse animation
- [ ] **Grid:** Always 2 columns on iPhone (when section expanded)
- [ ] **Minimal cards:** Image + title only (no description/icon/badge)
- [ ] **Search maintains state:** Sections keep expand/collapse state during search (no auto-expand)
- [ ] **No CategoryTabs:** Removed from HomeView
- [ ] **Console logs:** `carousel_click`, `card_select`, `search_performed`
- [ ] **No FeaturedToolCard:** Removed from HomeView
- [ ] **Haptics:** card tap (Home/Carousel) triggers light impact

**Smoke Test:**
1. Launch app → Home tab
2. Verify layout order: Header → Search → Carousel → Grid
3. Verify header shows correct badge
4. Verify "Photo Editor" section expanded, others collapsed
5. Tap "Seasonal" section header → verify expands with spring animation
6. Tap "Photo Editor" section header → verify collapses
7. Type in search bar → verify carousel hides immediately
8. Type "famous" → verify tools filter (only matching cards shown in their sections)
9. Verify sections maintain expand/collapse state (no auto-expand)
10. Clear search → verify carousel shows again
11. Wait 3 seconds → verify carousel auto-advances (loops forever)
12. Touch carousel → verify pause, wait 2s → verify resume
13. Verify grid is 2-column layout when section expanded

---

## Phase 3 — Chat UI Polish (FE)

**Goal:** Image picker UX, prompt prefilling, Start button logic, haptics  
**Duration:** 2 hours  
**Files Modified:** `ChatView.swift`, `ChatContainerView.swift`

### Tasks

#### 1. Auto-Open Image Picker on Preset
```swift
// ChatContainerView.swift changes
.onChange(of: appState.sessionId) { _ in
    if appState.currentPrompt != nil && appState.currentPrompt?.isEmpty == false {
        showingImagePicker = true  // Auto-open picker when sessionId changes
    }
}
```

- [ ] Add `.onChange(of: appState.sessionId)` to auto-open image picker when sessionId changes
- [ ] Check `appState.currentPrompt` is non-empty
- [ ] Set `showingImagePicker = true` inside onChange
- [ ] Do NOT use `onAppear` for picker open logic
- [ ] Test: Navigate Home → Chat → picker opens automatically

#### 2. Start Button Enable Rule
```swift
// ChatContainerView.swift - canSendMessage property
private var canSendMessage: Bool {
    guard let prompt = viewModel.currentPrompt, !prompt.isEmpty else { return false }
    return viewModel.selectedImage != nil && viewModel.remainingQuota > 0 && !viewModel.isProcessing
}
```

- [ ] Verify `canSendMessage` already exists in `ChatContainerView`
- [ ] Ensure logic checks both `selectedImage != nil` AND `currentPrompt != nil`
- [ ] Disable Start button when either missing
- [ ] Visual feedback: gray out Start button when disabled

#### 3. Light Haptic on Chat Start
```swift
// ChatContainerView.swift - handleSendMessage
private func handleSendMessage() {
    guard canSendMessage else { return }
    
    DesignTokens.Haptics.impact(.light)  // Add haptic
    
    Task {
        await viewModel.processSelectedImage()
        // ... existing code ...
    }
}
```

- [ ] Add `DesignTokens.Haptics.impact(.light)` in `handleSendMessage`
- [ ] Trigger haptic before processing starts
- [ ] Verify haptic fires on Start button tap

#### 4. Transcript Polish
- [ ] WhatsApp-style bubbles already implemented (verify)
- [ ] Verify user messages show on right (golden accent)
- [ ] Verify assistant messages show on left (gray background)
- [ ] Verify bubble tails render correctly

#### 5. Result Image Enlarge-on-Tap
- [ ] Add tap gesture to result images in `MessageBubbleView`
- [ ] Present full-screen image viewer on tap
- [ ] Dismiss on tap outside or swipe down

### Acceptance Checks

- [ ] **Auto-open picker:** Picker opens when navigating Home → Chat with preset
- [ ] **Picker on sessionId:** Picker opens even if Chat already visible
- [ ] **Start disabled:** Disabled when image OR prompt missing
- [ ] **Start enabled:** Enabled when both image AND prompt exist
- [ ] **Light haptic:** Haptic fires on Start tap
- [ ] **Console log:** `logEvent("chat_start", ["source": "preset", "tool_id": appState.selectedToolId ?? "", "prompt_len": appState.currentPrompt?.count ?? 0, "session_id": appState.sessionId.uuidString])`
- [ ] **Transcript polish:** Bubbles render correctly
- [ ] **Enlarge-on-tap:** Result images enlarge when tapped

**Smoke Test:**
1. Navigate Home → Chat with preset
2. Verify picker auto-opens
3. Switch back to Home, then return to Chat
4. Verify picker does NOT re-open (sessionId unchanged)
5. Select image → verify Start enables
6. Clear prompt → verify Start disables
7. Restore prompt → verify Start enables
8. Tap Start → verify haptic fires
9. Tap result image → verify enlarges

---

## Phase 4 — Glue & Paywall Entry (FE)

**Goal:** Paywall flow integration, quota unchanged, entry point verification  
**Duration:** 1 hour  
**Files Modified:** `HomeView.swift`, `ChatView.swift`

### Tasks

#### 1. Header "Get Pro" → Paywall
```swift
// HomeView.swift - UnifiedHeaderBar setup
rightContent: creditManager.isPremiumUser 
    ? .unlimitedBadge({}) 
    : .getProButton({ 
        showPaywall = true
        logEvent("purchase_click", ["placement": "home_get_pro", "session_id": appState.sessionId.uuidString])
    })
```

- [ ] Wire "Get Pro" button to `showPaywall = true`
- [ ] Add console log: `purchase_click(placement: home_get_pro)`
- [ ] Test: Tap "Get Pro" → paywall shows

#### 2. PRO Badge Static (No Action)
```swift
// HomeView.swift - UnifiedHeaderBar setup
rightContent: creditManager.isPremiumUser 
    ? .unlimitedBadge({})  // Empty action (non-tappable)
    : .getProButton({ ... })
```

- [ ] Ensure `unlimitedBadge` action is empty closure
- [ ] Verify PRO badge is non-tappable
- [ ] Test: Toggle subscription state → badge updates correctly

#### 3. Carousel Pro Tool → Paywall
```swift
// FeaturedCarouselView.swift - carousel tap handler
.onTapGesture {
    if tool.requiresPro {
        showPaywall = true
        logEvent("purchase_click", ["placement": "carousel_pro_tool", "session_id": appState.sessionId.uuidString])
    } else {
        onToolSelected(tool.id, tool.prompt)
    }
}
```

- [ ] Check tool.requiresPro before navigation
- [ ] If Pro: show paywall, log `purchase_click(placement: carousel_pro_tool)`
- [ ] If free: navigate to Chat with preset

#### 4. Chat Quota Exceeded → Paywall
```swift
// ChatViewModel.swift - processSelectedImage
if dailyQuotaUsed >= dailyQuotaLimit {
    showingPaywall = true
    logEvent("purchase_click", ["placement": "chat_quota_exceeded", "session_id": appState.sessionId.uuidString])
    return
}
```

- [ ] Verify quota check exists in `ChatViewModel.processSelectedImage`
- [ ] Ensure paywall shows when quota exceeded
- [ ] Log: `purchase_click(placement: chat_quota_exceeded)`

#### 5. Quota Dialogs Unchanged
- [ ] Verify existing quota dialogs still work
- [ ] No changes to quota UI logic
- [ ] Test: Run out of quota → dialog shows

### Acceptance Checks

- [ ] **Header "Get Pro":** Opens paywall, logs `purchase_click(placement: home_get_pro)`
- [ ] **PRO badge:** Static (non-tappable) when subscribed
- [ ] **Carousel Pro:** Shows paywall for Pro tools
- [ ] **Chat quota:** Shows paywall when quota exceeded
- [ ] **Quota dialogs:** Work as before (unchanged)
- [ ] **Console logs:** All purchase entry points logged

**Smoke Test:**
1. Tap "Get Pro" in header → paywall shows
2. Toggle subscription → badge updates to "PRO"
3. Tap PRO badge → nothing happens (non-tappable)
4. Tap Pro tool in carousel → paywall shows
5. Use all quota → paywall shows on next attempt

---

## Phase 5 — Polish & QA

**Goal:** Performance, layout, theme switching, edge cases, sanity tests  
**Duration:** 2-3 hours  
**Files Modified:** All (final QA pass)

### Tasks

#### 1. Performance Pass
- [ ] **Search debounce:** 300ms delay, no lag, smooth typing (test on slow device)
- [ ] **Carousel timer:** No memory leaks (check Instruments)
- [ ] **Lazy grid:** Fast rendering, no stutter on scroll
- [ ] **Image loading:** Async, no UI blocking
- [ ] **Background/foreground:** Carousel timer cancels correctly
- [ ] **In-flight cancellation:** No memory leaks from cancelled Tasks

#### 2. Layout Checks
- [ ] **Safe areas:** No content clipped on notch devices
- [ ] **Dark mode:** All colors render correctly
- [ ] **Light mode:** All colors render correctly
- [ ] **Typography:** Text readable, no truncation issues
- [ ] **Spacing:** 8pt grid respected
- [ ] **Grid:** Always 2-column on iPhone (all sizes)

#### 3. Theme Switching
- [ ] **Switch light → dark:** UI updates correctly
- [ ] **Switch dark → light:** UI updates correctly
- [ ] **System theme:** App follows system preference
- [ ] **Manual theme:** Manual override works

#### 4. Edge Cases & Sanity Tests
- [ ] **Rapid preset taps:** Tap 5 cards quickly → no crashes
- [ ] **Same-prompt re-selection:** Tap same card twice → fresh session starts
- [ ] **Tab switch mid-run:** Switch tabs during processing → no state loss
- [ ] **In-flight cancellation:** Start processing, tap new card → old task cancels cleanly
- [ ] **Offline:** Process image offline → error handled gracefully
- [ ] **Quota dialogs:** All entry points show correct dialogs
- [ ] **Large images:** Process 10MB image → compression works
- [ ] **Background/foreground:** Process image, background app → timer pauses/resumes
- [ ] **Carousel rotation:** Rotate device → carousel continues correctly

#### 5. Final Regression Check
- [ ] **Existing features:** Library tab, Profile tab still work
- [ ] **Authentication:** Login flow unchanged
- [ ] **Image processing:** Backend integration still works
- [ ] **Quota tracking:** Daily quota decrements correctly
- [ ] **Paywall:** All entry points work
- [ ] **Navigation:** Tab switching smooth

#### 6. End-to-End Smoke Test
```
1. Launch app → Home tab opens
2. Header shows correct badge (mock subscription state)
3. Carousel auto-advances (wait 3s)
4. Touch carousel → pause, wait 2s → resume
5. Type in search → carousel hides, grid filters
6. Clear search → carousel shows
7. Tap free tool card → Chat opens with preset
8. Picker auto-opens → select image
9. Start enables → tap Start
10. Haptic fires → processing starts
11. Tap new card mid-processing → old task cancels
12. Result shows → tap to enlarge
13. Go back to Home → tap same card → fresh session starts
14. Go back to Home → tap Pro tool → paywall shows
15. Use all quota → try to process → paywall shows
16. Switch themes → UI updates correctly
17. Rotate device → layout adapts
18. Tab switch during processing → no crashes
19. Background app → timer pauses, resumes on foreground
```

### Acceptance Checks

- [ ] **Performance:** No lags, leaks, or crashes
- [ ] **Layout:** Safe areas, responsive, theme-aware
- [ ] **Edge cases:** All handled gracefully
- [ ] **Regression:** No existing features broken
- [ ] **End-to-end:** Full smoke test passes
- [ ] **Same-prompt re-selection:** Creates fresh session every time
- [ ] **ChatViewModel uses `reset()` + `apply()` on `sessionId` changes; no `onAppear` coupling**

**Final Verification:**
- [ ] All Phase 1–4 checks still pass
- [ ] No new console errors or warnings
- [ ] App runs smoothly on all test devices
- [ ] Theme switching works flawlessly
- [ ] Analytics events fire correctly
- [ ] In-flight cancellation works without leaks

---

## Out-of-Scope (Explicit)

**DO NOT implement these in this refactor:**

- ❌ **Accessibility:** Beyond basic touch targets (44x44pt minimum)
- ❌ **Analytics Backend:** No Mixpanel, Firebase, etc. (console only)
- ❌ **Color Rebrand:** No palette changes (use existing `DesignTokens.swift`)
- ❌ **Backend Schema:** No database/API changes
- ❌ **iPad Layouts:** iPhone-only in this phase
- ❌ **Offline Mode:** No caching or offline workflows
- ❌ **Tool Favorites:** No custom collections
- ❌ **Push Notifications:** No background processing
- ❌ **Multi-Step Config:** Simple tap-to-start only

---

## Rollback Plan

If any phase fails QA:

1. **Revert phase changes** (git stash or branch reset)
2. **Fix issues** in feature branch
3. **Re-run phase QA** before proceeding
4. **No merge to main** until Phase 5 passes

**Emergency rollback:**
```bash
git stash  # Save current work
git checkout main  # Return to stable
```

---

## Success Criteria (Overall)

**MVP is complete when:**
- ✅ All Phase 1–5 acceptance checks pass
- ✅ End-to-end smoke test passes
- ✅ No regressions in existing features
- ✅ Console analytics fire correctly
- ✅ No performance issues or memory leaks
- ✅ In-flight cancellation works cleanly
- ✅ Same-prompt re-selection creates fresh sessions
- ✅ Code review approved
- ✅ Ready for merge to `main`

---

**End of Action Plan**
