# Create New SwiftUI Feature

## Task: Add New Feature Module

### Context
Create a new feature following MVVM architecture with proper file organization and state management.

### Steps
1. Create feature directory structure
2. Implement model (if needed)
3. Create view model with ObservableObject
4. Build SwiftUI view
5. Add navigation integration
6. Write tests (if applicable)

### Directory Structure
```
Features/{FeatureName}/
├── Models/
│   └── {FeatureName}Model.swift     # Data models
├── ViewModels/
│   └── {FeatureName}ViewModel.swift # Business logic
├── Views/
│   ├── {FeatureName}View.swift      # Main view
│   └── Components/                   # Feature-specific components
└── Services/
    └── {FeatureName}Service.swift   # API/business services
```

### ViewModel Template
```swift
import Foundation
import Combine
import SwiftUI

class FeatureNameViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var state: State = .idle
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    private let service: FeatureNameService
    private let appState: AppState
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - State
    enum State {
        case idle
        case loading
        case loaded([DataModel])
        case error(String)
    }
    
    // MARK: - Initialization
    init(
        service: FeatureNameService = FeatureNameService(),
        appState: AppState = AppState.shared
    ) {
        self.service = service
        self.appState = appState
        setupBindings()
    }
    
    // MARK: - Public Methods
    @MainActor
    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let data = try await service.fetchData()
            state = .loaded(data)
        } catch {
            state = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Private Methods
    private func setupBindings() {
        // Setup any Combine bindings
    }
}
```

### View Template
```swift
import SwiftUI

struct FeatureNameView: View {
    @StateObject private var viewModel = FeatureNameViewModel()
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        NavigationView {
            content
                .navigationTitle("Feature Name")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        toolbarContent
                    }
                }
        }
        .task {
            await viewModel.loadData()
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
    
    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let data):
            loadedContent(data)
        case .error(let message):
            ErrorView(message: message) {
                Task {
                    await viewModel.loadData()
                }
            }
        }
    }
    
    @ViewBuilder
    private func loadedContent(_ data: [DataModel]) -> some View {
        ScrollView {
            LazyVStack(spacing: DesignTokens.Spacing.md) {
                ForEach(data) { item in
                    // Item view
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
        }
    }
    
    @ViewBuilder
    private var toolbarContent: some View {
        Button("Action") {
            // Toolbar action
        }
    }
}

#Preview {
    FeatureNameView()
        .environmentObject(AppState.shared)
}
```

### Integration Checklist
- [ ] Add to ContentView navigation
- [ ] Update AppState if needed
- [ ] Add proper @EnvironmentObject injection
- [ ] Test navigation flow
- [ ] Verify design system usage
- [ ] Add proper error handling
- [ ] Implement loading states
- [ ] Add accessibility labels