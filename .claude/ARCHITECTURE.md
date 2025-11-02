# Architecture Guide

## File Structure

```
BananaUniverse/
├── App/                              # App entry point
│   ├── BananaUniverseApp.swift      # @main App
│   ├── AppDelegate.swift            # Lifecycle
│   └── ContentView.swift            # TabView root
│
├── Core/                             # Shared components
│   ├── Components/                   # Reusable UI
│   │   ├── UnifiedHeaderBar.swift   # Header with badges
│   │   ├── ToolCard.swift           # Tool display
│   │   └── ToolGridSection.swift    # Grid layout
│   ├── Config/Config.swift          # API keys, URLs
│   ├── Design/                      # Design system
│   │   ├── DesignTokens.swift       # Colors, spacing
│   │   └── Theme.swift              # Theme management
│   ├── Models/                      # Data models
│   │   ├── Tool.swift               # Tool definition
│   │   ├── ProcessedImage.swift     # AI result
│   │   └── User.swift               # User model
│   ├── Services/                    # Business logic
│   │   ├── AppState.swift           # Global state
│   │   ├── HybridCreditManager.swift # Quota system
│   │   ├── SeasonalManager.swift    # Dynamic content
│   │   └── AuthService.swift        # Authentication
│   └── Utils/                       # Helpers
│       └── CategoryFeaturedMapping.swift
│
├── Features/                         # Feature modules
│   ├── Authentication/              # Auth flows
│   ├── Chat/                        # AI processing
│   │   ├── Views/ChatView.swift     # Main UI
│   │   └── ViewModels/ChatViewModel.swift # Logic
│   ├── Home/Views/HomeView.swift    # Tool grid
│   ├── Library/                     # Image history
│   ├── Profile/                     # Settings
│   └── Paywall/                     # Subscription
│
└── supabase/                         # Backend
    ├── migrations/                   # DB schema
    ├── functions/process-image/      # AI processing
    └── config.toml                  # Supabase config
```

## MVVM Pattern

### View Model Structure
```swift
class FeatureViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var state: State
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    private let service: SomeService
    
    // MARK: - Initialization
    init(service: SomeService = SomeService()) {
        self.service = service
    }
    
    // MARK: - Public Methods
    func performAction() async {
        // Implementation
    }
    
    // MARK: - Private Methods
    private func handleError(_ error: Error) {
        // Error handling
    }
}
```

### View Structure
```swift
struct FeatureView: View {
    @StateObject private var viewModel = FeatureViewModel()
    
    var body: some View {
        NavigationView {
            content
        }
        .task {
            await viewModel.loadData()
        }
    }
    
    @ViewBuilder
    private var content: some View {
        // UI implementation
    }
}
```

## State Management

### AppState (Global)
- User authentication status
- Premium subscription state
- Current quota usage
- Seasonal settings

### Feature State (Local)
- Feature-specific data
- Loading states
- Error handling
- UI state

## Data Flow

1. **User Interaction** → View
2. **View** → ViewModel action
3. **ViewModel** → Service call
4. **Service** → Supabase/External API
5. **Response** → ViewModel @Published
6. **UI Update** → SwiftUI reactive update

## Component Guidelines

### Reusable Components
- Accept configuration via init parameters
- Use @Binding for two-way data flow
- Implement proper previews
- Follow design token system

### Navigation
- Use NavigationLink for internal navigation
- TabView for main app sections
- Sheet/fullScreenCover for modals
- Environment for cross-feature data

## Database Architecture

### Tables
- `users` - User profiles (RLS enabled)
- `daily_quota` - Quota tracking (RLS enabled)
- `processed_images` - Image history (RLS enabled)
- `tools` - Tool definitions (public read)

### RLS Policies
- Users can only access their own data
- Anonymous users tracked by session_id
- Premium status checked via Adapty webhook

### Edge Functions
- `process-image` - Main AI processing pipeline
- `cleanup-db` - Maintenance tasks
- `cleanup-images` - Storage cleanup