# Design System

## Core Principles
- **Simplicity**: Clean, minimal interface
- **Dark-first**: Primary theme is dark
- **Consistency**: Use design tokens for all UI
- **Accessibility**: 44pt minimum touch targets

## Design Tokens Usage

### Colors
```swift
// Primary colors
DesignTokens.Colors.primary          // Main brand color
DesignTokens.Colors.secondary        // Accent color
DesignTokens.Colors.background       // Main background
DesignTokens.Colors.surface          // Card backgrounds
DesignTokens.Colors.onSurface        // Text on surfaces

// Semantic colors
DesignTokens.Colors.success          // Success states
DesignTokens.Colors.warning          // Warning states
DesignTokens.Colors.error            // Error states
```

### Typography
```swift
// Text styles
DesignTokens.Typography.title1       // Main headings
DesignTokens.Typography.title2       // Section headings
DesignTokens.Typography.headline     // Card titles
DesignTokens.Typography.body         // Body text
DesignTokens.Typography.caption      // Secondary text
DesignTokens.Typography.button       // Button text
```

### Spacing
```swift
// Standard spacing scale
DesignTokens.Spacing.xs              // 4pt
DesignTokens.Spacing.sm              // 8pt
DesignTokens.Spacing.md              // 16pt
DesignTokens.Spacing.lg              // 24pt
DesignTokens.Spacing.xl              // 32pt
DesignTokens.Spacing.xxl             // 48pt
```

### Corner Radius
```swift
DesignTokens.CornerRadius.sm         // 8pt - buttons
DesignTokens.CornerRadius.md         // 12pt - cards
DesignTokens.CornerRadius.lg         // 16pt - sheets
```

## Component Guidelines

### Tool Cards
```swift
// Standard tool card
ToolCard(tool: tool)
  .frame(height: 160)
  .background(DesignTokens.Colors.surface)
  .cornerRadius(DesignTokens.CornerRadius.md)
```

### Buttons
```swift
// Primary button
Button("Action") { }
  .buttonStyle(PrimaryButtonStyle())
  .frame(minHeight: 44)

// Secondary button  
Button("Cancel") { }
  .buttonStyle(SecondaryButtonStyle())
  .frame(minHeight: 44)
```

### Headers
```swift
// Unified header with badges
UnifiedHeaderBar(
  quotaUsed: viewModel.quotaUsed,
  isPremium: viewModel.isPremium
)
.frame(height: 56)
```

### Grid Layout
```swift
// Tool grid with proper spacing
LazyVGrid(columns: columns, spacing: DesignTokens.Spacing.md) {
  ForEach(tools) { tool in
    ToolCard(tool: tool)
  }
}
.padding(.horizontal, DesignTokens.Spacing.md)
```

## Layout Guidelines

### Screen Structure
```
┌─────────────────────────┐
│ Header (56pt)           │ ← Fixed header
├─────────────────────────┤
│                         │
│ Scrollable Content      │ ← Main content area
│                         │
│                         │
├─────────────────────────┤
│ Tab Bar (49pt)          │ ← System tab bar
└─────────────────────────┘
```

### Grid System
- **2-column grid** for tool cards
- **16pt spacing** between cards
- **16pt margin** from screen edges
- **160pt height** for tool cards

### Content Hierarchy
1. **Navigation**: Tab bar, headers
2. **Primary content**: Tool grids, chat interface
3. **Secondary content**: Badges, metadata
4. **Actions**: Buttons, interactive elements

## Animation Guidelines

### Transitions
```swift
// Standard transition
.animation(.easeInOut(duration: 0.3), value: state)

// Spring animation for interactive elements
.animation(.spring(response: 0.6, dampingFraction: 0.8), value: isPressed)
```

### Loading States
```swift
// Shimmer effect for loading cards
RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
  .fill(DesignTokens.Colors.surface)
  .redacted(reason: .placeholder)
```

## Haptic Feedback

### Usage Guidelines
```swift
// Light impact for button taps
DesignTokens.Haptics.impact(.light)

// Medium impact for selections
DesignTokens.Haptics.impact(.medium)

// Heavy impact for errors
DesignTokens.Haptics.impact(.heavy)

// Success notification
DesignTokens.Haptics.notification(.success)

// Error notification
DesignTokens.Haptics.notification(.error)
```

## Accessibility

### Guidelines
- Minimum 44x44pt touch targets
- High contrast ratios (WCAG AA)
- VoiceOver support for all interactive elements
- Dynamic Type support
- Reduced motion respect

### Implementation
```swift
// Accessibility labels
.accessibilityLabel("Upscale image tool")
.accessibilityHint("Tap to enhance image resolution")

// Dynamic Type support
.font(DesignTokens.Typography.body)

// Reduced motion
.animation(UIAccessibility.isReduceMotionEnabled ? nil : .default)
```

## Dark Theme Specifics

### Color Palette
- **Background**: Pure black (#000000)
- **Surface**: Dark gray (#1C1C1E)
- **Primary**: Blue (#007AFF)
- **Secondary**: Orange (#FF9500)
- **Text**: White (#FFFFFF)
- **Secondary Text**: Gray (#8E8E93)

### Contrast Guidelines
- Text on background: 15:1 contrast
- Text on surface: 12:1 contrast
- Interactive elements: High visibility
- Disabled states: Clear visual hierarchy

## Component States

### Interactive States
```swift
// Button states
.opacity(isPressed ? 0.6 : 1.0)
.scaleEffect(isPressed ? 0.95 : 1.0)

// Card states
.overlay(
  RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
    .stroke(DesignTokens.Colors.primary, lineWidth: isSelected ? 2 : 0)
)
```

### Loading States
```swift
// Loading overlay
.overlay(
  ProgressView()
    .scaleEffect(1.5)
    .progressViewStyle(CircularProgressViewStyle(tint: .white))
    .opacity(isLoading ? 1 : 0)
)
```

### Error States
```swift
// Error border
.overlay(
  RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
    .stroke(DesignTokens.Colors.error, lineWidth: hasError ? 1 : 0)
)
```