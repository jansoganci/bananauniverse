# BananaUniverse Home & Chat Redesign - Scope Analysis

**Last Updated:** 2025-01-27  
**Status:** 🎯 Ready for Implementation  
**Inspired By:** Hepsiburada Layout Pattern

---

## 📝 Changelog — Corrections

**2025-01-27:** Event-driven session architecture
- Replaced `onChange(of: chatPrompt)` with event-driven `AppState` model
- Added `AppState/SessionStore` with `sessionId`, `selectedToolId`, `currentPrompt`
- Added `ChatViewModel.reset()` and `apply(prompt:)` contracts
- Removed `onAppear` coupling for prompt/picker logic
- Added same-prompt re-selection acceptance test
- Clarified in-flight cancellation requirements

---

## 🎯 Goals

Transform the Home tab into a modern, discovery-focused interface with:
1. **Featured carousel** for tool discovery (5 cards, auto-advance)
2. **Search-driven filtering** for quick tool access
3. **Streamlined card grid** (2-column layout, minimal metadata)
4. **Direct navigation** from cards to Chat with prefilled prompts
5. **Polished ChatView** with WhatsApp-style messaging and Pro badge logic
6. **Lightweight analytics** (console logging only, 6 core events)

---

## 🚫 Non-Goals (Out of Scope for MVP)

- ❌ Accessibility beyond basic touch targets (44x44pt minimum)
- ❌ Advanced analytics integration (Mixpanel, Firebase, etc.)
- ❌ Custom theme palettes (use existing `DesignTokens.swift`)
- ❌ iPad-specific layouts or optimizations
- ❌ Offline mode or caching strategies
- ❌ Tool usage counters or badges on cards
- ❌ Multi-step tool configuration flows
- ❌ Tool favorites or custom collections
- ❌ Push notifications or background processing

---

## 🎨 Core UX Behaviors

### Header (UnifiedHeaderBar)
- **Left:** App logo (🍌 icon, 32pt)
- **Right:** Pro badge logic
  - Subscribed: `"PRO"` badge (non-tappable)
  - Not subscribed: `"Get Pro"` button (tappable → paywall)
- **Height:** 56pt (from `DesignTokens.Layout.headerHeight`)

### Search Bar
- **Placement:** Below header, above carousel (top of page)
- **Debounce:** 300ms (search as user types)
- **Behavior:**
  - Query empty → show carousel
  - Query non-empty → hide carousel immediately, filter tool cards by `title` only (case-insensitive)
  - Filtered tools shown in their respective category sections (sections remain in user's expand/collapse state)
- **Visual:** iOS native search bar style, theme-aware

### Featured Carousel
- **Placement:** Below search bar
- **Count:** Exactly 5 items total
- **Display:** Single visible item at a time
- **Auto-advance:** Every 3 seconds (infinite loop, never stops)
- **Interactions:**
  - Touch/drag → pause auto-advance
  - 2s idle → resume auto-advance
- **Swipe:** Horizontal navigation (iOS native)
- **Indicator:** Page dots below
- **Source:** Featured tools from all categories (via `CategoryFeaturedMapping`)

### Tool Grid (Collapsible Category Sections - Option 3)
- **Layout:** Collapsible category sections with 2-column grids
- **Default State:** "Photo Editor" (main_tools) expanded, all other categories collapsed
- **Section Headers:**
  - Simple text label (e.g., "Photo Editor", "Seasonal") for MVP
  - Expand/collapse indicator (chevron or arrow)
  - Tap header to toggle expand/collapse
- **Grid Behavior:**
  - When expanded: 2-column grid of tool cards
  - When collapsed: Header only (no tools visible)
  - Columns: Always 2 on iPhone
  - Spacing: From `DesignTokens.Spacing`
- **Card Content:**
  - Image (placeholder: SF Symbol from `Tool.placeholderIcon`)
  - Title (short, 2-line limit)
  - No counters, no badges, no metadata
- **Animation:** Spring animation for expand/collapse (SwiftUI default)
- **Source:** All tools minus featured, organized by category (via `CategoryFeaturedMapping`)
- **Search Integration:**
  - Filtered tools remain in their category sections
  - Sections maintain user's expand/collapse state (no auto-expand on search)
  - Only matching tool cards shown within each section

### Tap Flow (Option A: Direct to Chat)
1. User taps card → navigate to Chat tab
   - If `tool.requiresPro` and user is NOT premium: open paywall (do not navigate to Chat).
2. Prompt prefilled: `Tool.prompt`
3. Image picker auto-opens
4. User may edit prompt
5. "Start" disabled until image + prompt exist

### ChatView Polish
- **Header:** Same Pro badge logic as Home
- **Messages:** WhatsApp-style bubbles with tail
  - User: Right-aligned, golden accent
  - Assistant: Left-aligned, gray background
- **Haptics:** Light impact on `card_select` and `chat_start` (Optional: use `selectionChanged()` on category tab switch if category tabs are present.)
- **Input:** Auto-clear after send (WhatsApp-style)
- **State:** Single `ChatViewModel` at root (TabView level)
- **Reactivity:** Event-driven via `AppState.sessionId`

---

## 🔧 State Management Approach

### AppState / SessionStore Architecture

**Centralized session state** at root level:

```swift
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

**Contract:** Every preset selection creates a new `sessionId`, triggering reset + apply.

### AppState Injection

**Injection Contract**

- `ContentView` injects the store: `.environmentObject(appState)`

- Views consume via `@EnvironmentObject var appState: AppState` (HomeView, ChatView, FeaturedCarousel)

- Reactivity is driven by `appState.sessionId` changes; avoid `onAppear` for prompt/picker logic

### ChatViewModel Integration
- **Location:** Root TabView (already in `ContentView.swift`)
- **Observable:** `.onChange(of: appState.sessionId)` triggers reset + apply
- **Avoid:** `onAppear` pitfalls (session ID drives reactivity)
- **Session:** Fresh session per preset selection (reset history)

### ChatViewModel Contracts

#### reset()
Must clear all session state:
- Clear transcript/messages
- `selectedImage = nil`
- Cancel all in-flight async work (store and cancel Tasks/AnyCancellable)
- Reset processing flags

#### apply(prompt: String)
Must apply new prompt:
- Set `currentPrompt = prompt`
- Trigger image picker open via flag bound to `sessionId` change
- **NOT** via `onAppear`

### Navigation State
- **Trigger:** `HomeView(onToolSelected:)` callback
- **Implementation:** Call `AppState.selectPreset(id: tool.id, prompt: tool.prompt)` then set `selectedTab = 1`
- **Data:** Session ID propagates reactivity

### Search State
- **Local:** `@State private var searchQuery: String` in HomeView
- **Debounce:** Timer-based (300ms delay)
- **Filter:** `tools.filter { matchesSearch($0, query: searchQuery) }` (case-insensitive title match)
- **Behavior:**
  - Non-empty query → hides carousel immediately
  - Empty query → shows carousel again
  - Filtered tools shown in their category sections (sections keep user's expand/collapse state)
  - No auto-expand of collapsed sections when search matches

---

## 🎨 Design Constraints

### Colors & Theme
- **Source:** `DesignTokens.swift` (centralized)
- **System:** Respect `ThemeManager` (light/dark)
- **Brand:** Golden accent (`DesignTokens.Brand.primary`)
- **Note:** Palette may change later; keep theme system intact

### Layout
- **Grid:** 2 columns minimum (current `ToolGridSection` logic)
- **Spacing:** Use `DesignTokens.Spacing` tokens
- **Images:** Use `Tool.placeholderIcon` (SF Symbol) for MVP

### Typography
- **Cards:** `DesignTokens.Typography.title3` for titles
- **Search:** `DesignTokens.Typography.body`
- **Badges:** `DesignTokens.Typography.caption1`

---

## 📊 Analytics (MVP)

**Console logging only** — no external SDKs:

```swift
// Events to log
- carousel_click(id: tool.id)
- card_select(tool: tool.id, category: category)
- search_performed(query: String, result_count: Int)
- chat_start(tool: tool.id)
- purchase_click(placement: "home_get_pro" | "chat_quota_exceeded")
- paywall_view(placement: String)
```

**Payload standard (all events include these fields):**
- `event` (string), `sessionId` (UUID string), `toolId` (string)
- optional: `placement`, `query`, `result_count`

**Format:** `print("📊 ANALYTICS", ["event": "<name>", "sessionId": appState.sessionId.uuidString, "toolId": tool.id, "placement": "<where>", "query": query, "result_count": count])`

---

## 🔌 Backend Constraints

### Edge Function
- **Endpoint:** `process-image` (existing Supabase Edge Function)
- **Model:** `nano-banana/edit` (fal.ai)
- **Note:** `Tool.modelName` currently unused; prompts matter most

### Image Processing Flow
1. Upload image to Supabase Storage
2. Call `process-image` with prompt
3. Return processed image URL
4. Download and display in Chat

---

## 🤔 Open Questions & Assumptions

### Assumptions (Proposed Defaults)
1. **Carousel auto-restart:** Resume after 2s idle (default)
2. **Search keywords:** Use `Tool.title` only (no separate `keywords` field yet)
3. **Card images:** SF Symbols for MVP (placeholder icons)
4. **Same-prompt re-selection:** Creates new session (new sessionId)

### Open Questions
1. **Carousel order:** Use featured order from `CategoryFeaturedMapping` or shuffle?
   - **Default:** Use mapping order
2. **Search scope:** Search all categories or current category only?
   - **Default:** Current category
3. **Pro badge styling:** Match existing `UnifiedHeaderBar` or custom design?
   - **Default:** Reuse existing header components

---

## ✅ Acceptance Criteria Checklist

### Home Redesign
- [ ] Header with logo + Pro badge (subscribed → "PRO", not subscribed → "Get Pro")
- [ ] Search bar below header (top of page) with 300ms debounce
- [ ] Search hides carousel immediately when query non-empty
- [ ] Featured carousel below search bar with 5 items (single visible, auto-advance every 3s, infinite loop)
- [ ] Carousel pause on touch/drag, resume after 2s idle
- [ ] Collapsible category sections below carousel
- [ ] Default: "Photo Editor" expanded, all others collapsed
- [ ] Section headers: simple text labels (expand/collapse on tap)
- [ ] 2-column grid when section expanded
- [ ] Cards show image + title only (no counters/badges)
- [ ] Spring animation for expand/collapse

### Navigation & Flow
- [ ] Tapping card navigates to Chat tab
- [ ] Prompt prefilled in Chat (from `Tool.prompt`)
- [ ] Image picker auto-opens in Chat
- [ ] User can edit prompt before starting
- [ ] "Start" disabled until image + prompt exist
- [ ] Pro gating: tapping a Pro tool when not subscribed opens paywall and does NOT navigate to Chat

### Chat Polish
- [ ] Header matches Home Pro badge logic
- [ ] WhatsApp-style message bubbles
- [ ] Light haptic on card select
- [ ] Light haptic on chat start
- [ ] Input auto-clears after send
- [ ] Single `ChatViewModel` at root (TabView level)

### State Management
- [ ] `.onChange(of: sessionId)` triggers reset + apply
- [ ] No `onAppear` coupling for prompt/picker
- [ ] Search state managed locally in HomeView
- [ ] Debounce timer implemented (300ms)
- [ ] In-flight cancellations on new selection (no stale toasts/replies)
- [ ] Picker opens on sessionId change (even if Chat already visible)
- [ ] Same-prompt re-selection creates fresh session
- [ ] AppState is injected via `.environmentObject`; views use `@EnvironmentObject AppState`

### Design & Theme
- [ ] All colors from `DesignTokens.swift`
- [ ] Theme-aware (light/dark)
- [ ] Golden accent for brand elements
- [ ] Consistent spacing (8pt grid)

### Analytics
- [ ] Console logging for 6 core events
- [ ] No external SDKs
- [ ] Every analytics print includes `sessionId` and `toolId` in the payload

### Backend
- [ ] Uses `process-image` edge function
- [ ] `nano-banana/edit` model via fal.ai
- [ ] Prompts passed correctly

---

## 📝 Implementation Notes

### File Modifications
- `HomeView.swift` — Header, search, carousel, grid updates
- `ChatView.swift` — Polish, haptics, state handling
- `ContentView.swift` — Navigation, AppState integration, ChatViewModel wiring
- `ToolCard.swift` — Remove badges/counters, simplify layout
- New: `FeaturedCarouselView.swift` — Carousel component
- New: `AppState.swift` — Session management

### Dependencies
- Existing: `UnifiedHeaderBar`, `DesignTokens`, `ChatViewModel`, `CategoryFeaturedMapping`
- New: `AppState` for session management
- AppState is provided at root via `.environmentObject(appState)` and consumed with `@EnvironmentObject` in HomeView, ChatView, FeaturedCarousel.

### Testing Considerations
- Test search debounce (300ms delay)
- Test carousel auto-advance/pause/resume
- Test navigation from Home → Chat with prefilled prompt
- Test haptic feedback on card select + chat start
- Test Pro badge states (subscribed vs not subscribed)
- Test theme switching (light/dark)
- Test same-prompt re-selection (creates new session)

---

## 🚀 Success Metrics (Post-MVP)

Once MVP is live, track:
- Time to first tool selection
- Search usage rate
- Carousel engagement (taps vs swipes)
- Conversion to Chat (card → Chat start rate)
- Chat start → completion rate

---

**End of Scope Analysis**
