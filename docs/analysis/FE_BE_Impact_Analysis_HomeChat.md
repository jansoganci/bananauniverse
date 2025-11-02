# Frontend & Backend Impact Analysis — Home & Chat Redesign

**Last Updated:** 2025-10-31  
**Status:** 📋 Pre-Implementation Analysis  
**Scope:** Frontend surface changes + Backend confirmation

---

## 📝 Changelog — Corrections

**2025-10-31:** Event-driven session architecture
- Replaced `onChange(of: chatPrompt)` with `AppState.sessionId`-based reactivity
- Added `ChatViewModel.reset()` and `apply(prompt:)` contracts
- Removed `onAppear` coupling for prompt/picker
- Added same-prompt re-selection acceptance test
- Enhanced race condition mitigation
- Clarified TabView lifecycle pitfalls

---

## 🎯 Overview

This document maps every UX decision from `BananaUniverse_HomeChat_Scope_Analysis.md` to concrete FE/BE surface changes. No implementation code yet—only structural impact assessment.

**Key Principle:** Home becomes a discovery layer with search/carousel; Chat remains the processing interface. Single `ChatViewModel` owns chat state at TabView root with event-driven session management.

---

## 🔧 Frontend Impact

### Screens/Components Affected

| Component | Current State | New State | Impact Level |
|-----------|--------------|-----------|--------------|
| **HomeView.swift** | Header + CategoryTabs + Featured card + Grid | Add search bar, replace featured card with 5-item carousel, simplify grid cards | 🔴 High |
| **ChatView.swift** | WhatsApp-style messaging | Polish: haptics, prompt auto-prefill via sessionId, header badge logic | 🟡 Medium |
| **ContentView.swift** | TabView with `chatPrompt: String?` | Enhance navigation: AppState.selectPreset() → Chat with prefilled prompt | 🟡 Medium |
| **ToolCard.swift** | Image + Title + Description + Icon | Simplify: Image + Title only (remove description, icon) | 🟢 Low |
| **UnifiedHeaderBar.swift** | Logo + title + right badge | No changes (already supports Pro badge logic) | 🟢 None |
| **FeaturedToolCard.swift** | Hero card with description | Remove (replaced by carousel) | 🔴 High |
| **FeaturedCarouselView.swift** | Does not exist | New component: 5 cards, auto-advance, pause/resume | 🔴 High |
| **ChatViewModel.swift** | Process images, manage quota | Add: reset(), apply(prompt:), in-flight cancellation | 🟡 Medium |
| **AppState.swift** | Does not exist | New: session management with sessionId, selectedToolId, currentPrompt | 🔴 High |

### State Ownership Changes

#### Current State
```
ContentView
  ├─ HomeView
  │   └─ onToolSelected callback → manually switch tabs
  ├─ ChatView
  │   └─ @StateObject private var viewModel = ChatViewModel()
```

#### New State
```
ContentView
  ├─ @StateObject private var appState = AppState()  ← NEW: Session management
  ├─ @StateObject private var chatViewModel = ChatViewModel()  ← NEW: Single instance
  ├─ HomeView(onToolSelected: navigateToChatWithPrompt)
  │   └─ Search state: @State private var searchQuery
  ├─ ChatView(viewModel: chatViewModel)  ← Pass only the shared VM (no initialPrompt)
  └─ .onChange(of: appState.sessionId) { _ in  ← NEW: sessionId-based reactivity
      chatViewModel.reset()
      chatViewModel.apply(appState.currentPrompt)
    }
```

**Key Changes:**
- **AppState:** New centralized session management
- **ChatViewModel:** Lift to TabView root (remove `@StateObject` from ChatView)
- **Reactivity:** `sessionId` changes trigger reset + apply (not `chatPrompt`)
- **Search:** Local to HomeView (no global state needed)

### Navigation/State Flow

#### Scenario 1: Chat Tab Not Visible
```
User taps card in Home
  → HomeView.onToolSelected(tool.prompt)
  → ContentView.navigateToChatWithPrompt(id: tool.id, prompt: tool.prompt)
  → AppState.selectPreset(id: tool.id, prompt: tool.prompt)
  → sessionId = UUID() (new session)
  → Trigger .onChange(of: sessionId)
  → ChatViewModel.reset()
  → ChatViewModel.apply(currentPrompt)
  → Switch to Chat tab
  → ChatView receives viewModel reference
  → Auto-open image picker + prefill prompt (via sessionId change)
```

#### Scenario 2: Chat Tab Already Visible
```
Same flow, but ChatView.onAppear already ran
  → .onChange(of: sessionId) still fires (session ID changed)
  → ChatViewModel.reset() clears old state
  → ChatViewModel.apply(currentPrompt) sets new prompt
  → Picker auto-opens (sessionId change triggers open flag)
```

**Critical Rule:** "Start" button disabled until `chatViewModel.selectedImage != nil && chatViewModel.currentPrompt != nil && chatViewModel.remainingQuota > 0 && !chatViewModel.isProcessing`

#### Scenario 3: Same Prompt Re-Selected
```
User taps same tool card again
  → AppState.selectPreset() called with same id/prompt
  → sessionId = UUID() (NEW session ID)
  → .onChange(of: sessionId) fires
  → Reset + Apply runs again
  → Fresh session starts
```

**Contract:** Every preset selection creates a new session, even if prompt is identical.

#### Scenario 4: Search Filtering
```
User types in search bar
  → Carousel hides immediately (if query non-empty)
  → Debounce timer (300ms)
  → Filter tools by searchQuery (case-insensitive title match)
  → Show filtered tools in their category sections
  → Sections maintain user's expand/collapse state (no auto-expand)
  → If query empty → carousel shows again
```

**Filter scope:** Case-insensitive match on `Tool.title` only (MVP; no `keywords` field yet).  
**Debounce:** 300ms. **Behavior:** Non-empty query hides carousel immediately; filtered tools shown in category sections without auto-expanding collapsed sections.

### UI Behavior Differences

| Behavior | Current | New | Implementation |
|----------|---------|-----|----------------|
| **Layout Order** | Category tabs + Featured + Grid | Header → Search → Carousel → Grid | Reorder components in HomeView |
| **Featured Display** | Single `FeaturedToolCard` | 5-item carousel (single visible, auto-advance 3s, infinite loop) | New: `FeaturedCarouselView` |
| **Auto-Advance** | None | Pause on touch, resume after 2s idle | Timer + state management |
| **Search** | None | 300ms debounce, hide carousel immediately on query | Add `TextField` + debounce + filter by title (case-insensitive) |
| **Grid Layout** | Category tabs + flat grid | Collapsible category sections (Option 3) | New: Collapsible section component |
| **Default State** | Category tabs (seasonal selected) | "Photo Editor" expanded, others collapsed | State management for expanded categories |
| **Grid Columns** | Category-dependent (2-5) | Always 2 on iPhone (when expanded) | Simplify `ToolGridSection.calculateColumns` |
| **Card Content** | Icon + Title + Description + Badge | Image + Title only | Simplify `ToolCard.swift` |
| **Navigation** | Tap → manual tab switch | Tap → session reset + Chat | `AppState.selectPreset()` |
| **Prompt Prefill** | onChange(of: chatPrompt) | onChange(of: sessionId) | More reliable reactivity |
| **Section Animation** | None | Spring animation for expand/collapse | SwiftUI `.animation(.spring())` |

### Minimal Haptics Touchpoints

| Event | Location | Style | Implementation |
|-------|----------|-------|----------------|
| `card_select` | HomeView (tool card tap) | Light impact | `DesignTokens.Haptics.impact(.light)` |
| `chat_start` | ChatView (Start button tap) | Light impact | `DesignTokens.Haptics.impact(.light)` |
| Category switch | HomeView (category tab) | Selection changed | `DesignTokens.Haptics.selectionChanged()` |

**Total haptics:** 3 touchpoints (minimal as requested).

### Color Theming via Central Tokens

**Current:** All views use `DesignTokens.swift` + `ThemeManager`

**No changes needed** — already compliant:
- `DesignTokens.Brand.primary` for golden accent
- `DesignTokens.Background.primary(colorScheme)` for backgrounds
- `DesignTokens.Text.primary(colorScheme)` for text
- `ThemeManager` for system theme resolution

**Verification:** No hardcoded colors in new carousel/search components.

---

## 🔌 Backend Impact

### API Schema Changes

**Status:** ✅ **NO CHANGES**

- `Tool` model: Already has `prompt: String` field
- Supabase edge function: `process-image` unchanged
- fal.ai model: `nano-banana/edit` unchanged
- Storage: `processed_images` table unchanged
- Quota: `daily_quota` tracking unchanged

### Prompt Handling

**Current:** Prompts stored in `Tool.prompt`, passed to `supabaseService.processImageSteveJobsStyle()`

**No changes needed:**
- Prompts still drive `nano-banana/edit` processing
- No new prompt templates required
- No backend prompt validation

### Telemetry Upload

**Current:** Console logging only (MVP requirement)

**Future (out of scope):**
- Optional: Upload analytics to Supabase `events` table
- Schema: `{ event_name, tool_id, category, timestamp, user_id }`
- No implementation in this phase

### Analytics — Event Schema (MVP)

Events and payloads to log to console (for later persistence):
- **carousel_click** `{ item_id: String, position: Int, session_id: UUID }`
- **card_select** `{ tool_id: String, category: String, session_id: UUID }`
- **search_performed** `{ query: String, results_count: Int, session_id: UUID }`
- **chat_start** `{ source: "preset"|"manual", tool_id: String?, session_id: UUID, prompt_length: Int }`
- **purchase_click** `{ source: "home_header"|"carousel_pro_tool"|"chat_quota", session_id: UUID }`
- **paywall_view** `{ source: String, session_id: UUID }`
### 8. Picker Idempotence

Add a guard to prevent the image picker from re-opening multiple times within the same session:

```swift
// ChatViewModel or ChatContainerView
@Published var lastPickerSessionId: UUID?

func openPickerIfNeeded(for sessionId: UUID) {
    if lastPickerSessionId != sessionId {
        lastPickerSessionId = sessionId
        showingImagePicker = true
    }
}
```

Call `openPickerIfNeeded(for: appState.sessionId)` when handling `.onChange(of: appState.sessionId)`.

### Quota/Paywall Entry Points

**Current:** `HybridCreditManager` + `PreviewPaywallView`

**New entry points:**
1. Header badge (existing: `UnifiedHeaderBar.getProButton`)
2. Carousel "Get Pro" (new: when user taps featured Pro tool)
3. Chat quota exceeded (existing: `ChatViewModel.showingPaywall`)

**No backend changes** — quota logic unchanged.

---

## ⚠️ Risk & Mitigation

### 1. TabView Lifecycle Pitfalls

**Risk:** `ChatView.onAppear` may fire before prompt updates, causing stale state.

**Mitigation:**
```
✅ Use .onChange(of: sessionId) in ContentView (not chatPrompt)
✅ sessionId change guarantees fresh session
✅ ChatViewModel.reset() + apply() ensures clean state
✅ Picker opens via sessionId change (NOT onAppear)
```

**Why sessionId over onAppear:**
- `onAppear` fires once when view appears, then silent
- `sessionId` change fires every selection, regardless of tab visibility
- `sessionId` drives reset + apply lifecycle reliably

**Fallback:**
```swift
// Add to ChatView if needed
.id(appState.sessionId)
```

### 2. Performance Concerns

| Concern | Risk | Mitigation |
|---------|------|------------|
| **Search debounce** | Laggy typing | `Combine.Timer` with 300ms delay |
| **Lazy grid** | Slow rendering | Use `LazyVGrid` (already implemented) |
| **Carousel timer** | Memory leak | `onDisappear` cancel timer |
| **Image loading** | Blur/crash | Async load, compression (existing) |
| **In-flight cancellation** | Stale results | Store Tasks/AnyCancellable in ChatViewModel |

**Implementation:**
```swift
// Example: In-flight cancellation
class ChatViewModel: ObservableObject {
    private var inFlightTasks: [Task<Void, Never>] = []
    
    func reset() {
        // Cancel all in-flight
        for task in inFlightTasks {
            task.cancel()
        }
        inFlightTasks.removeAll()
        // ... clear other state
    }
    
    func processImage() async {
        let task = Task {
            await doWork()
        }
        inFlightTasks.append(task)
        await task.value
    }
}
```

### 3. Race Conditions

**Risk:** Event fires, then tab switch happens before ChatView receives update.

**Mitigation:**
```
✅ .onChange(of: sessionId) fires immediately
✅ ChatViewModel.reset() + apply() runs before tab switch
✅ Chat reacts to sessionId regardless of tab visibility
✅ Picker open flag bound to sessionId change
```

**Avoid:** Nested NavigationView (causes presentation conflicts).

### 4. Same-Prompt Re-Selection

**Risk:** User taps same tool twice, second tap ignored.

**Mitigation:**
```
✅ Every selectPreset() creates new UUID
✅ New sessionId triggers .onChange
✅ Reset + Apply runs even for duplicate prompts
✅ Fresh session starts every time
```

### 5. Regression Risks

| Area | Risk | Quick Test |
|------|------|------------|
| **Navigation** | Broken TabView switching | Tap card → verify Chat opens |
| **Prompts** | Wrong prompt prefilled | Tap tool → verify Chat shows correct prompt |
| **In-flight cancellation** | Stale toasts/replies | Select new preset mid-processing → verify cancel |
| **Quota** | Not decremented on processing | Process image → verify quota count decreases |
| **Pro badge** | Wrong state (Pro vs not) | Toggle subscription → verify badge updates |
| **Search** | Filter breaks on special chars | Search "test's" → verify no crash |
| **Carousel** | Auto-advance breaks on rotation | Rotate device → verify carousel continues |

**Quick Smoke Test:**
1. Open Home → verify carousel shows
2. Search → verify carousel hides
3. Tap card → verify Chat opens with prompt
4. Tap same card again → verify fresh session starts
5. Start processing → verify haptic fires
6. Tap new card mid-processing → verify old task cancels
7. Complete → verify quota decrements

### 6. State Synchronization

**Risk:** `ChatViewModel.currentPrompt` out of sync with `AppState.currentPrompt`.

**Mitigation:**
```
✅ Single source of truth: AppState
✅ .onChange(of: sessionId) propagates to ChatViewModel
✅ ChatViewModel.apply() sets currentPrompt from AppState
✅ AppState.selectPreset() guarantees atomic update
```

**Test:** Verify prompt updates when switching between tools in Home.

### 7. Carousel Auto-Advance Edge Cases

| Edge Case | Risk | Mitigation |
|-----------|------|------------|
| **User exits app** | Timer keeps running | `onDisappear` cancel timer |
| **User switches tabs** | Timer overlaps | `onAppear` restart, `onDisappear` cancel |
| **Background/foreground** | Timer state lost | `scenePhase` observer |
| **Device rotation** | Layout breaks | `GeometryReader` + auto-size |

**Implementation:**
```swift
.onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) {
    carouselTimer?.invalidate()
}
.onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) {
    startAutoAdvance()
}
```

---

## ✅ Acceptance Checklist (FE/BE Aligned)

### Frontend Acceptance

#### Home Redesign
- [ ] Layout order: Header → Search → Carousel → Grid (correct order)
- [ ] Search bar below header (top of page) with 300ms debounce
- [ ] Search hides carousel immediately when query non-empty
- [ ] Carousel: 5 items total, single visible, auto-advance every 3s, infinite loop
- [ ] Carousel pause on touch/drag, resume after 2s idle
- [ ] Carousel shows again when search query empty
- [ ] Collapsible category sections below carousel (Option 3)
- [ ] Default: "Photo Editor" expanded, all others collapsed
- [ ] Section headers: simple text labels (expand/collapse on tap)
- [ ] Grid: always 2 columns on iPhone (when section expanded)
- [ ] Cards: image + title only (no description/icon/badge)
- [ ] Spring animation for expand/collapse
- [ ] Pro badge logic in header (subscribed → "PRO", not subscribed → "Get Pro")
- [ ] Search filters tools by title (case-insensitive), maintains section expand/collapse state

#### Navigation & State
- [ ] Tap card → switch to Chat tab
- [ ] Prompt prefilled in Chat
- [ ] Image picker auto-opens in Chat
- [ ] "Start" disabled until image + prompt exist, quota > 0, and not processing
- [ ] ChatViewModel at TabView root (not in ChatView)
- [ ] `.onChange(of: sessionId)` triggers reset + apply
- [ ] No onAppear coupling for prompt/picker
- [ ] In-flight cancellations on new selection
- [ ] Picker opens on sessionId change (even if Chat visible)
- [ ] Same-prompt re-selection creates fresh session

#### Chat Polish
- [ ] WhatsApp-style bubbles (already implemented)
- [ ] Light haptic on card select
- [ ] Light haptic on chat start
- [ ] Input auto-clears after send
- [ ] Header matches Home Pro badge logic

#### Paywall & Purchase Entry Points
- [ ] Header "Get Pro" opens paywall and logs purchase_click(home_header)
- [ ] Carousel Pro tool tap opens paywall and logs purchase_click(carousel_pro_tool)
- [ ] Quota exceeded in Chat opens paywall and logs purchase_click(chat_quota)

### Backend Acceptance

#### No Schema Changes
- [ ] No new database tables
- [ ] No new API endpoints
- [ ] No prompt template changes
- [ ] `process-image` edge function unchanged
- [ ] Quota tracking unchanged

#### Analytics
- [ ] Console logging for 6 events
- [ ] No external SDKs
- [ ] No telemetry upload (out of scope)

### Integration Acceptance

#### State Flow
- [ ] Single ChatViewModel instance across app
- [ ] AppState manages session lifecycle
- [ ] Prompt propagates Home → Chat without loss
- [ ] Search state local to HomeView
- [ ] No onAppear pitfalls

#### Performance
- [ ] Search debounce: smooth typing
- [ ] Lazy grid: fast rendering
- [ ] Carousel timer: no leaks
- [ ] Image loading: no crashes
- [ ] In-flight cancellation: no stale results

#### Regression
- [ ] All existing features still work
- [ ] Navigation flows correctly
- [ ] Quota decrements on processing
- [ ] Pro badge shows correct state
- [ ] Theme switching works

---

## 📋 File Change Summary

### Files to Modify
1. **HomeView.swift** — Remove CategoryTabs, add search, carousel, collapsible sections, correct layout order
2. **ChatView.swift** — Pass viewModel, add haptics
3. **ContentView.swift** — Lift ChatViewModel, add AppState, sessionId onChange handler
4. **ToolCard.swift** — Remove description/icon/badge
5. **ToolGridSection.swift** — Force 2-column layout (remove category-dependent logic)
6. **ChatViewModel.swift** — Add reset(), apply(prompt:), in-flight cancellation

### Files to Create
1. **FeaturedCarouselView.swift** — 5-item carousel component (single visible, infinite loop)
2. **CollapsibleCategorySection.swift** — Collapsible category section component (Option 3)
3. **AppState.swift** — Session management (sessionId, selectPreset)

### Files to Remove
1. **FeaturedToolCard.swift** — Replaced by carousel
2. **CategoryTabs.swift** — Removed from HomeView (sections replace tabs)

### Files Unchanged
1. **UnifiedHeaderBar.swift** — Already supports Pro badge
2. **DesignTokens.swift** — Already centralized
3. **CategoryFeaturedMapping.swift** — Already provides featured tools
4. **Backend (all)** — No schema or API changes

---

## 🎯 Implementation Order

1. **Phase 1:** State management
   - Create AppState
   - Lift ChatViewModel to ContentView
   - Add sessionId onChange handler
   - Implement reset() + apply()
   - Test navigation flow

2. **Phase 2:** Home UI (search + carousel + collapsible sections)
   - Correct layout order: Header → Search → Carousel → Grid
   - Add search bar (below header)
   - Create FeaturedCarouselView (5 items, infinite loop)
   - Create CollapsibleCategorySection component
   - Remove CategoryTabs, add collapsible sections
   - Default: "Photo Editor" expanded
   - Test auto-advance/pause/resume
   - Test search filtering (maintains section state)

3. **Phase 3:** Grid simplification
   - Simplify ToolCard (remove description/icon/badge)
   - Set 2-column layout in ToolGridSection
   - Remove FeaturedToolCard

4. **Phase 4:** Chat polish
   - Add haptics
   - Test prompt prefilling
   - Verify "Start" enable rule
   - Test in-flight cancellation

5. **Phase 5:** Integration testing
   - Smoke test all flows
   - Performance check
   - Regression verification

---

**End of Impact Analysis**
