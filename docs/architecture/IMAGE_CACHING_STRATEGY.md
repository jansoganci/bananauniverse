# 🖼️ Kingfisher Image Caching Strategy Plan

This document outlines the strategy for implementing professional image caching in the BananaUniverse app using the Kingfisher library. This will improve loading performance, reduce data usage, and enhance the overall user experience.

## 📝 Executive Summary
The current use of `AsyncImage` lacks persistent disk caching, causing images to be re-downloaded every time the app is opened. This plan replaces the standard implementation with a Kingfisher-based system that stores images locally on the user's device.

---

## 🛠️ Implementation Phases

### Phase 1: Centralized Image Component
*   **Location:** `BananaUniverse/Core/Components/CachedAsyncImage/CachedAsyncImage.swift`
*   **Goal:** Create a reusable wrapper component around Kingfisher to ensure consistency across the app.
*   **Features:**
    *   Animated **SkeletonView** during loading.
    *   Automatic **SF Symbol** fallback on failure.
    *   Smooth **Fade-in** transitions.

### Phase 2: Global Configuration
*   **Location:** `BananaUniverse/App/AppDelegate.swift`
*   **Goal:** Configure Kingfisher's global behavior and cache limits.
*   **Settings:**
    *   **RAM Limit:** 100 MB.
    *   **Disk Limit:** 500 MB.
    *   **Expiration:** 7 Days.
    *   **Downsampling:** Automatically resize images to match screen scale for memory efficiency.

### Phase 3: Component Migration
Replace all instances of `AsyncImage` with the new `CachedAsyncImage` in the following components:
*   `ToolCard.swift` (Home screen theme cards)
*   `CarouselCard.swift` (Featured section)
*   `RecentActivityCard.swift` (Library/Recent items)
*   `HistoryItemRow.swift` (History list)

### Phase 4: Architectural Improvements (Refactoring)
*   **SkeletonView Extraction:** Extract the existing skeleton loading logic from `HistoryItemRow` into a standalone component at `BananaUniverse/Core/Components/SkeletonView/SkeletonView.swift` for shared use.

### Phase 5: Cleanup
*   Remove legacy `URLCache` configuration from `AppDelegate.swift` once Kingfisher is fully operational.

---

## ⚙️ Technical Architecture

### Component API Design
```swift
CachedAsyncImage(
    url: URL?,
    placeholderIcon: String = "photo",
    contentMode: ContentMode = .fill,
    showsProgressView: Bool = false
)
```

### Caching Strategy
*   **Memory (RAM):** Uses an LRU (Least Recently Used) algorithm to automatically evict old images.
*   **Disk:** Persistent storage that survives app restarts, allowing for offline access to previously loaded images.

---

## 💎 Benefits and Risks

### Benefits
1.  **Speed:** Images load instantly (0ms latency) after the first download.
2.  **Data Savings:** Images are only downloaded once, saving user bandwidth.
3.  **Stability:** Downsampling prevents memory pressure and potential crashes on older devices.
4.  **Premium UX:** High-quality transitions and loading states.

### Risk Management
*   **Storage Management:** A 500MB cap and 7-day expiration policy ensure the app's cache doesn't grow indefinitely.
*   **Content Freshness:** Kingfisher automatically handles updated content if the URL changes on the server.

---

This plan moves the app's image handling to **industry-standard practices**, ensuring scalability and a high-quality user experience.
