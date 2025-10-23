# 🧩 Component Specifications
## Modular Design System for Home Screen Redesign

---

## 1. ToolGrid Component

### Purpose
A flexible, responsive container that manages tool layout and provides intelligent organization.

### API Design
```swift
struct ToolGrid: View {
    // MARK: - Properties
    let tools: [Tool]
    let layout: GridLayout
    let featuredTool: Tool?
    let showUsageStats: Bool
    let onToolSelected: (Tool) -> Void
    let onShowMore: (() -> Void)?
    
    // MARK: - Configuration
    enum GridLayout {
        case adaptive(minColumns: Int, maxColumns: Int)
        case fixed(columns: Int)
        case masonry
    }
    
    enum CardSize {
        case compact
        case standard
        case featured
        case hero
    }
}
```

### Responsive Behavior
- **iPhone SE (375px)**: 2 columns
- **iPhone 14 (390px)**: 3 columns  
- **iPhone 14 Plus (428px)**: 4 columns
- **iPad (768px+)**: 5+ columns with larger cards

### Features
- Dynamic column calculation based on screen width
- Smart tool prioritization (usage-based)
- Smooth layout transitions
- Accessibility support (VoiceOver, Dynamic Type)

---

## 2. Enhanced ToolCard Component

### Purpose
Individual tool representation with multiple size variants and contextual information.

### API Design
```swift
struct ToolCard: View {
    // MARK: - Properties
    let tool: Tool
    let size: CardSize
    let showUsageStats: Bool
    let showDifficulty: Bool
    let showQuickActions: Bool
    let onTap: () -> Void
    let onQuickAction: ((QuickAction) -> Void)?
    
    // MARK: - Configuration
    enum CardSize {
        case compact    // 80x80pt
        case standard   // 160x120pt
        case featured   // 200x140pt
        case hero       // 300x180pt
    }
    
    enum QuickAction {
        case favorite
        case share
        case info
    }
}
```

### Size Variants

#### Compact Card (80x80pt)
```
┌─────────┐
│    🔧   │
│ Remove  │
│ Object  │
│  ⭐⭐⭐  │
└─────────┘
```
- Icon + title only
- Perfect for dense layouts
- Quick recognition

#### Standard Card (160x120pt)
```
┌─────────────┐
│ Remove      │
│ Object      │
│    🔧       │
│  ⭐⭐⭐    │
│ [Use] [♥]   │
└─────────────┘
```
- Full information display
- Quick action buttons
- Balanced information density

#### Featured Card (200x140pt)
```
┌─────────────────┐
│   🏆 FEATURED   │
│   Remove Object │
│      🔧         │
│  Most Popular   │
│ [Use] [Learn]   │
└─────────────────┘
```
- Prominent display
- Additional context
- Call-to-action buttons

#### Hero Card (300x180pt)
```
┌─────────────────────────┐
│      🏆 FEATURED        │
│     Remove Object       │
│         🔧              │
│   Most Popular Tool     │
│   This Week             │
│ [Use Tool] [Learn More] │
└─────────────────────────┘
```
- Maximum visual impact
- Rich contextual information
- Multiple action options

### Visual States

#### Normal State
- Standard elevation (2px shadow)
- Brand primary color for icon
- Clean typography hierarchy

#### Hover/Press State
- Scale: 1.02x
- Shadow: +2px elevation
- Subtle color shift
- Haptic feedback

#### Disabled State
- 40% opacity
- Grayscale filter
- No interaction feedback

#### Premium Locked State
- Crown icon overlay
- Subtle premium gradient
- Paywall trigger on tap

---

## 3. Smart CategoryTabs Component

### Purpose
Intelligent category navigation with usage analytics and smooth transitions.

### API Design
```swift
struct CategoryTabs: View {
    // MARK: - Properties
    let categories: [ToolCategory]
    let selectedCategory: Binding<String>
    let showUsageCounts: Bool
    let showUsageFrequency: Bool
    let onCategorySelected: (String) -> Void
    
    // MARK: - Configuration
    struct ToolCategory {
        let id: String
        let title: String
        let icon: String
        let toolCount: Int
        let usageFrequency: Double // 0.0 - 1.0
        let isNew: Bool
    }
}
```

### Visual Design
```
┌─────────────────────────────────────────┐
│ [Main Tools 7] [Pro Looks 10] [Restore 2] │
│     ⭐⭐⭐      ⭐⭐        ⭐⭐⭐    │
└─────────────────────────────────────────┘
```

### Features
- Tool count badges
- Usage frequency indicators (stars)
- "New" badges for recent categories
- Smooth animated transitions
- Smart ordering based on usage

### Animation States
- **Selection**: Scale + color transition
- **Hover**: Subtle elevation increase
- **Badge Updates**: Smooth count changes
- **Category Switch**: Slide transition

---

## 4. Progressive Disclosure Component

### Purpose
Manages tool visibility and provides expandable sections for power users.

### API Design
```swift
struct ProgressiveDisclosure: View {
    // MARK: - Properties
    let initialToolCount: Int
    let totalToolCount: Int
    let isExpanded: Binding<Bool>
    let onToggle: () -> Void
    
    // MARK: - Configuration
    enum DisclosureStyle {
        case showMore
        case expandable
        case paginated
    }
}
```

### Visual States

#### Collapsed State
```
┌─────────────────────────────────────┐
│        Show More Tools (5)          │
│         [Expand ▼]                  │
└─────────────────────────────────────┘
```

#### Expanded State
```
┌─────────────────────────────────────┐
│        Hide Additional Tools        │
│         [Collapse ▲]                │
└─────────────────────────────────────┘
```

### Features
- Smooth expand/collapse animation
- Clear visual indicators
- Accessibility announcements
- Smart default state (based on user behavior)

---

## 5. Usage Analytics Component

### Purpose
Tracks and displays tool usage patterns for intelligent recommendations.

### API Design
```swift
struct UsageAnalytics: ObservableObject {
    // MARK: - Properties
    @Published var toolUsageCounts: [String: Int]
    @Published var categoryUsageCounts: [String: Int]
    @Published var recentTools: [Tool]
    @Published var favoriteTools: [Tool]
    
    // MARK: - Methods
    func recordToolUsage(_ tool: Tool)
    func getToolFrequency(_ tool: Tool) -> Double
    func getRecommendedTools() -> [Tool]
    func getTrendingTools() -> [Tool]
}
```

### Data Points
- Tool usage frequency
- Category preferences
- Time-based patterns
- User journey tracking
- A/B test data

---

## 6. Animation System

### Purpose
Provides consistent, performant animations across all components.

### API Design
```swift
struct AnimationSystem {
    // MARK: - Timing
    static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)
    static let smooth = SwiftUI.Animation.easeInOut(duration: 0.3)
    static let gentle = SwiftUI.Animation.easeInOut(duration: 0.4)
    static let spring = SwiftUI.Animation.spring(response: 0.6, dampingFraction: 0.8)
    
    // MARK: - Transitions
    static let cardHover = AnyTransition.scale(scale: 1.02)
    static let categorySwitch = AnyTransition.slide.combined(with: .opacity)
    static let progressiveDisclosure = AnyTransition.move(edge: .bottom)
}
```

### Animation Guidelines
- **Micro-interactions**: 0.15-0.2s
- **Category changes**: 0.3s spring
- **Card interactions**: 0.2s easeOut
- **Progressive disclosure**: 0.4s easeInOut

---

## 7. Accessibility Features

### VoiceOver Support
- Semantic labels for all interactive elements
- Custom actions for complex gestures
- Logical reading order
- State announcements

### Dynamic Type
- Scalable typography (caption to large title)
- Adaptive layout for larger text
- Maintained visual hierarchy

### Motor Accessibility
- 44pt minimum touch targets
- Customizable gesture sensitivity
- Switch control support
- Voice control compatibility

### Visual Accessibility
- High contrast mode support
- Color-blind friendly palette
- Reduced motion preferences
- Customizable animation speeds

---

## 8. Performance Considerations

### Lazy Loading
- Only render visible cards
- Progressive image loading
- Efficient memory management

### Animation Performance
- 60fps target for all animations
- Hardware acceleration where possible
- Reduced motion for accessibility

### Data Management
- Efficient tool data caching
- Smart preloading strategies
- Minimal re-renders

---

## 9. Testing Strategy

### Unit Tests
- Component behavior validation
- Animation timing verification
- Accessibility compliance

### Integration Tests
- User flow validation
- Performance benchmarking
- Cross-device compatibility

### User Testing
- A/B test different layouts
- Usability studies
- Accessibility testing

---

*This component specification provides a comprehensive foundation for implementing the modular, scalable Home screen redesign while maintaining the app's visual DNA and ensuring rapid iteration capabilities.*

