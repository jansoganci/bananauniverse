# 🧩 Concept 2: Component Specifications
## Detailed Component Design & API

---

## 🎯 **1. FeaturedToolCard Component**

### **Purpose**
Hero card component that displays the featured tool for each category with prominent styling and call-to-action buttons.

### **API Design**
```swift
struct FeaturedToolCard: View {
    // MARK: - Properties
    let tool: Tool
    let onUseTool: () -> Void
    let onLearnMore: () -> Void
    
    // MARK: - Configuration
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isPressed = false
}
```

### **Visual Design**
```
┌─────────────────────────────────────────┐
│  ┌─────────────────────────────────────┐ │
│  │        🏆 FEATURED                  │ │ ← Featured badge
│  │     Remove Object                   │ │ ← Tool title
│  │    Most Popular This Week           │ │ ← Subtitle
│  │                                     │ │
│  │         🔧                         │ │ ← Large icon (64pt)
│  │                                     │ │
│  │  [Use Tool] [Learn More]           │ │ ← Action buttons
│  └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

### **Size & Spacing**
- **Width**: Full width minus 32pt horizontal padding
- **Height**: 180pt (hero card size)
- **Corner Radius**: 16pt (DesignTokens.CornerRadius.lg)
- **Shadow**: DesignTokens.Shadow.lg
- **Padding**: 24pt internal padding

### **Features**
- **Featured Badge**: "🏆 FEATURED" with golden styling
- **Large Icon**: 64pt SF Symbol with brand colors
- **Dual CTAs**: "Use Tool" (primary) + "Learn More" (secondary)
- **Hover Effects**: Scale + shadow increase
- **Haptic Feedback**: Medium impact on tap

### **Styling**
```swift
// Featured badge
.foregroundColor(DesignTokens.Brand.accent(themeManager.resolvedColorScheme))
.font(DesignTokens.Typography.caption1)
.fontWeight(.bold)

// Tool title
.font(DesignTokens.Typography.title2)
.fontWeight(.bold)
.foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))

// Subtitle
.font(DesignTokens.Typography.callout)
.foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))

// Large icon
.font(.system(size: 64, weight: .medium))
.foregroundColor(DesignTokens.Brand.primary(themeManager.resolvedColorScheme))
```

---

## 🎯 **2. ToolGridSection Component**

### **Purpose**
Modular wrapper around the tool grid that handles responsive layout and tool display logic.

### **API Design**
```swift
struct ToolGridSection: View {
    // MARK: - Properties
    let tools: [Tool]
    let showPremiumBadge: Bool
    let onToolTap: (Tool) -> Void
    
    // MARK: - Configuration
    @EnvironmentObject var themeManager: ThemeManager
    @State private var screenWidth: CGFloat = 0
}
```

### **Responsive Behavior**
```swift
private var columns: [GridItem] {
    let columnCount = calculateColumns(for: screenWidth)
    return Array(repeating: GridItem(.flexible(), spacing: DesignTokens.Spacing.sm), count: columnCount)
}

private func calculateColumns(for width: CGFloat) -> Int {
    switch width {
    case 0..<390: return 2      // iPhone SE
    case 390..<428: return 3    // iPhone 14
    case 428..<768: return 4    // iPhone 14 Plus
    default: return 5           // iPad+
    }
}
```

### **Layout Structure**
```
ToolGridSection
├── LazyVGrid
│   ├── columns: [GridItem] (responsive)
│   ├── spacing: DesignTokens.Spacing.sm
│   └── ForEach(tools)
│       └── ToolCard (reused existing)
└── .padding(.horizontal, DesignTokens.Spacing.md)
```

### **Features**
- **Responsive Columns**: 2-5 columns based on screen width
- **Consistent Spacing**: 8pt grid system
- **Tool Reuse**: Uses existing ToolCard component
- **Performance**: LazyVGrid for efficient rendering

---

## 🎯 **3. CategoryFeaturedMapping Utility**

### **Purpose**
Utility class that maps each category to its featured tool and calculates remaining tools.

### **API Design**
```swift
struct CategoryFeaturedMapping {
    // MARK: - Featured Tool Selection
    static func featuredTool(for category: String) -> Tool?
    
    // MARK: - Remaining Tools
    static func remainingTools(for category: String) -> [Tool]
    
    // MARK: - Category Validation
    static func isValidCategory(_ category: String) -> Bool
}
```

### **Featured Tool Logic**
```swift
static func featuredTool(for category: String) -> Tool? {
    switch category {
    case "main_tools":
        return Tool.mainTools.first { $0.id == "remove_object" }
    case "pro_looks":
        return Tool.proLooksTools.first { $0.id == "linkedin_headshot" }
    case "restoration":
        return Tool.restorationTools.first { $0.id == "image_upscaler" }
    default:
        return nil
    }
}
```

### **Remaining Tools Logic**
```swift
static func remainingTools(for category: String) -> [Tool] {
    let allTools = currentTools(for: category)
    let featured = featuredTool(for: category)
    return allTools.filter { $0.id != featured?.id }
}
```

---

## 🎯 **4. Updated HomeView Structure**

### **New Body Structure**
```swift
var body: some View {
    NavigationView {
        VStack(spacing: 0) {
            // Header Bar (unchanged)
            UnifiedHeaderBar(...)
            
            // Category Tabs (unchanged)
            CategoryTabs(selectedCategory: $selectedCategory)
            
            // Content Area (new structure)
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    // Featured Tool Card
                    if let featuredTool = featuredTool {
                        FeaturedToolCard(
                            tool: featuredTool,
                            onUseTool: { handleToolTap(featuredTool) },
                            onLearnMore: { showToolInfo(featuredTool) }
                        )
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity.combined(with: .scale(scale: 1.05))
                        ))
                    }
                    
                    // Tool Grid Section
                    ToolGridSection(
                        tools: remainingTools,
                        showPremiumBadge: shouldShowPremiumBadge,
                        onToolTap: handleToolTap
                    )
                }
                .padding(.top, DesignTokens.Spacing.md)
                .padding(.bottom, DesignTokens.Spacing.lg)
            }
        }
        .background(DesignTokens.Background.primary(themeManager.resolvedColorScheme))
        .navigationTitle("")
        .navigationBarHidden(true)
    }
    .sheet(isPresented: $showPaywall) {
        PreviewPaywallView()
    }
}
```

### **New Computed Properties**
```swift
// Featured tool for current category
private var featuredTool: Tool? {
    CategoryFeaturedMapping.featuredTool(for: selectedCategory)
}

// Remaining tools (excluding featured)
private var remainingTools: [Tool] {
    CategoryFeaturedMapping.remainingTools(for: selectedCategory)
}

// Existing properties (unchanged)
private var currentTools: [Tool] { ... }
private var shouldShowPremiumBadge: Bool { ... }
```

---

## 🎯 **5. Animation Specifications**

### **Featured Card Animations**
```swift
// Appear animation
.transition(.asymmetric(
    insertion: .opacity.combined(with: .scale(scale: 0.95)),
    removal: .opacity.combined(with: .scale(scale: 1.05))
))

// Hover animation
.scaleEffect(isPressed ? 1.02 : 1.0)
.shadow(
    color: .black.opacity(isPressed ? 0.25 : 0.15),
    radius: isPressed ? 8 : 4,
    x: 0,
    y: isPressed ? 4 : 2
)
```

### **Grid Animations**
```swift
// Grid update animation
.transition(.opacity)
.animation(DesignTokens.Animation.smooth, value: selectedCategory)

// Category switch animation
withAnimation(DesignTokens.Animation.spring) {
    selectedCategory = category.id
}
```

### **Timing Constants**
```swift
// Animation durations
static let featuredCardTransition: Animation = .spring(response: 0.6, dampingFraction: 0.8)
static let gridUpdate: Animation = .easeInOut(duration: 0.3)
static let categorySwitch: Animation = .spring(response: 0.4, dampingFraction: 0.7)
static let cardHover: Animation = .easeOut(duration: 0.2)
```

---

## 🎯 **6. Haptic Feedback Strategy**

### **Featured Tool Interactions**
```swift
// Use Tool button
DesignTokens.Haptics.impact(.medium)

// Learn More button
DesignTokens.Haptics.impact(.light)

// Featured card tap
DesignTokens.Haptics.impact(.medium)
```

### **Grid Tool Interactions**
```swift
// Grid tool tap (existing)
DesignTokens.Haptics.impact(.light)

// Category switch (existing)
DesignTokens.Haptics.selectionChanged()
```

---

## 🎯 **7. Accessibility Features**

### **FeaturedToolCard Accessibility**
```swift
.accessibilityElement(children: .combine)
.accessibilityLabel("Featured tool: \(tool.title)")
.accessibilityHint("Double tap to use this tool")
.accessibilityAddTraits(.isButton)
```

### **ToolGridSection Accessibility**
```swift
.accessibilityElement(children: .contain)
.accessibilityLabel("Tools grid with \(tools.count) tools")
```

### **Screen Reader Support**
- Featured tool announced as "Featured tool: [Name]"
- Grid announced as "Tools grid with X tools"
- Action buttons have clear labels and hints

---

## 🎯 **8. Performance Considerations**

### **Lazy Loading**
- Featured card loads immediately
- Grid uses LazyVGrid for efficient rendering
- Only visible tools are rendered

### **Memory Management**
- No unnecessary state retention
- Efficient animation cleanup
- Proper view lifecycle management

### **Animation Performance**
- Hardware-accelerated transforms
- 60fps target for all animations
- Reduced motion support

---

## 🎯 **9. Testing Strategy**

### **Unit Tests**
- CategoryFeaturedMapping logic
- Responsive column calculation
- Featured tool selection

### **Integration Tests**
- Category switching behavior
- Animation timing
- Haptic feedback

### **UI Tests**
- Featured card display
- Grid responsiveness
- Accessibility compliance

---

## 🎯 **10. Implementation Checklist**

### **Phase 1: FeaturedToolCard**
- [ ] Create FeaturedToolCard.swift
- [ ] Implement visual design
- [ ] Add hover animations
- [ ] Test with different tools

### **Phase 2: ToolGridSection**
- [ ] Create ToolGridSection.swift
- [ ] Implement responsive columns
- [ ] Integrate with existing ToolCard
- [ ] Test responsive behavior

### **Phase 3: CategoryFeaturedMapping**
- [ ] Create CategoryFeaturedMapping.swift
- [ ] Implement featured tool logic
- [ ] Implement remaining tools logic
- [ ] Test category switching

### **Phase 4: HomeView Integration**
- [ ] Update HomeView structure
- [ ] Add computed properties
- [ ] Implement animations
- [ ] Test complete flow

---

*These component specifications provide detailed implementation guidance for each new component in Concept 2, ensuring consistency with the existing design system and maintaining the "Think Fast, Iterate Faster" philosophy.*
