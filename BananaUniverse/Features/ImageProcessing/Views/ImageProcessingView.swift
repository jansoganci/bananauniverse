//
//  ImageProcessingView.swift
//  BananaUniverse
//
//  Created by AI Assistant on 2025-11-20.
//  Purpose: Main image processing screen with collapsible settings
//

import SwiftUI
import PhotosUI

struct ImageProcessingView: View {
    @StateObject var viewModel: ImageProcessingViewModel
    @Binding var sourceTab: Int
    let targetTab: Int
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appState: AppState
    @ObservedObject private var creditManager = CreditManager.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            ZStack(alignment: .leading) {
                UnifiedHeaderBar(
                    title: "Create",
                    leftContent: .empty,
                    rightContent: .quotaBadge(creditManager.creditsRemaining, {
                        viewModel.showingPaywall = true
                    })
                )

                // Back button overlay
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                }
                .padding(.leading, DesignTokens.Spacing.md)
            }

            ScrollView {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    // Image Selection Section
                    ImageSelectionSection(viewModel: viewModel)

                    // Prompt Input (Editable)
                    PromptSection(viewModel: viewModel)

                    // Collapsible Settings Section
                    SettingsSection(viewModel: viewModel)

                    // Credit Cost Display
                    CreditCostCard(viewModel: viewModel)

                    // Generate Button
                    GenerateButton(viewModel: viewModel)
                }
                .padding(DesignTokens.Spacing.md)
            }
            .scrollDismissesKeyboard(.immediately) // Dismiss keyboard on scroll start
            .background(
                DesignTokens.Background.primary(themeManager.resolvedColorScheme)
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Dismiss keyboard when tapping background
                        hideKeyboard()
                    }
            )
        }
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $viewModel.showingPaywall) {
            PaywallPreview()
        }
        .fullScreenCover(isPresented: $viewModel.showingProcessing) {
            if let jobId = viewModel.processingJobId {
                ProcessingView(
                    jobId: jobId,
                    theme: createDummyTheme(),
                    onComplete: { imageUrl in
                        viewModel.handleProcessingComplete(imageUrl: imageUrl)
                    },
                    onError: { error in
                        viewModel.handleProcessingError(error)
                    }
                )
            }
        }
        .onChange(of: viewModel.showingProcessing) { isShowing in
            if !isShowing {
                // Reset state when processing view is dismissed
                viewModel.isProcessing = false
                viewModel.processingJobId = nil
            }
        }
        .fullScreenCover(isPresented: $viewModel.showingResult) {
            ResultViewLoader(
                imageURL: viewModel.resultImageURL,
                creditCost: viewModel.estimatedCost,
                modelType: viewModel.selectedModel,
                onDismiss: {
                    viewModel.showingResult = false
                    // Restore the source tab after dismissing result
                    sourceTab = targetTab
                }
            )
            .environmentObject(themeManager)
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // Helper to dismiss keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    // Helper to create a dummy theme for ProcessingView
    private func createDummyTheme() -> Theme {
        return Theme(
            id: "nano-banana",
            name: viewModel.selectedModel.displayName,
            description: "AI Image Generation",
            thumbnailURL: nil,
            category: "nano-banana",
            modelName: viewModel.selectedModel.rawValue,
            placeholderIcon: "sparkles",
            prompt: viewModel.prompt,
            isFeatured: false,
            isAvailable: true,
            requiresPro: false,
            defaultSettings: nil,
            createdAt: Date()
        )
    }
}

// MARK: - Result View Loader (Async Image Loading)

struct ResultViewLoader: View {
    let imageURL: URL?
    let creditCost: Int
    let modelType: ModelType
    let onDismiss: () -> Void

    @State private var loadedImage: UIImage?
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var loadTask: Task<Void, Never>?  // Track the task to prevent duplicates
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        Group {
            if let loadedImage = loadedImage {
                ResultView(
                    resultImage: loadedImage,
                    creditCost: creditCost,
                    modelType: modelType,
                    onDismiss: onDismiss
                )
                .environmentObject(themeManager)
            } else if isLoading {
                ResultLoadingView()
            } else {
                ResultErrorView(message: loadError ?? "Failed to load image", onDismiss: onDismiss)
            }
        }
        .onAppear {
            // Only start task if not already running
            guard loadTask == nil else { return }
            loadTask = Task {
                await loadImage()
            }
        }
        .onDisappear {
            // Explicitly cancel when view disappears
            loadTask?.cancel()
            loadTask = nil
        }
    }

    private func loadImage() async {
        guard let imageURL = imageURL else {
            await MainActor.run {
                loadError = "No image URL"
                isLoading = false
            }
            return
        }

        // Wait 5 seconds for CDN propagation before first attempt
        #if DEBUG
        print("⏳ [ResultViewLoader] Waiting 5 seconds for CDN propagation...")
        #endif
        try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
        
        // Check if task was cancelled during initial wait
        if Task.isCancelled {
            #if DEBUG
            print("⚠️ [ResultViewLoader] Task cancelled during initial wait")
            #endif
            return
        }

        let maxRetries = 3
        let retryDelay: UInt64 = 2_000_000_000 // 2 seconds for all retries

        for attempt in 0...maxRetries {
            do {
                let (data, response) = try await URLSession.shared.data(from: imageURL)

                // Check HTTP status code
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        if let uiImage = UIImage(data: data) {
                            await MainActor.run {
                                loadedImage = uiImage
                                isLoading = false
                                loadError = nil
                            }

                            #if DEBUG
                            print("✅ [ResultViewLoader] Image loaded successfully on attempt \(attempt + 1)")
                            #endif

                            return // Success - exit function
                        } else {
                            // Invalid image data - don't retry
                            await MainActor.run {
                                loadError = "Invalid image data"
                                isLoading = false
                            }

                            #if DEBUG
                            print("❌ [ResultViewLoader] Invalid image data received")
                            #endif

                            return
                        }
                    } else if httpResponse.statusCode == 404 {
                        // 404 - resource not found yet, retry if attempts remaining
                        if attempt < maxRetries {
                            #if DEBUG
                            print("⏳ [ResultViewLoader] Attempt \(attempt + 1) failed (404), retrying in 2s...")
                            #endif
                            try? await Task.sleep(nanoseconds: retryDelay)
                            continue // Retry
                        } else {
                            await MainActor.run {
                                loadError = "Image not found (404)"
                                isLoading = false
                            }

                            #if DEBUG
                            print("❌ [ResultViewLoader] All retries exhausted, image not found (404)")
                            #endif

                            return
                        }
                    } else {
                        // Other HTTP error codes
                        if attempt < maxRetries {
                            #if DEBUG
                            print("⏳ [ResultViewLoader] Attempt \(attempt + 1) failed (HTTP \(httpResponse.statusCode)), retrying in 2s...")
                            #endif
                            try? await Task.sleep(nanoseconds: retryDelay)
                            continue // Retry
                        } else {
                            await MainActor.run {
                                loadError = "HTTP error: \(httpResponse.statusCode)"
                                isLoading = false
                            }
                            return
                        }
                    }
                }

            } catch {
                // Check if task was cancelled
                if Task.isCancelled {
                    #if DEBUG
                    print("⚠️ [ResultViewLoader] Task cancelled")
                    #endif
                    return // Exit silently
                }

                // Network error or timeout
                if attempt < maxRetries {
                    #if DEBUG
                    print("⏳ [ResultViewLoader] Attempt \(attempt + 1) failed: \(error.localizedDescription), retrying in 2s...")
                    #endif
                    try? await Task.sleep(nanoseconds: retryDelay)
                    continue // Retry
                } else {
                    // All retries exhausted
                    await MainActor.run {
                        loadError = error.localizedDescription
                        isLoading = false
                    }

                    #if DEBUG
                    print("❌ [ResultViewLoader] All retries exhausted: \(error.localizedDescription)")
                    #endif

                    return
                }
            }
        }
    }
}

// MARK: - Result Loading View

struct ResultLoadingView: View {
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: DesignTokens.Brand.accent(themeManager.resolvedColorScheme)))

            Text("Loading your masterpiece...")
                .font(.headline)
                .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Background.primary(themeManager.resolvedColorScheme))
    }
}

// MARK: - Result Error View

struct ResultErrorView: View {
    let message: String
    let onDismiss: () -> Void
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.red)

            Text("Error")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))

            Text(message)
                .font(.body)
                .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.lg)

            Button(action: onDismiss) {
                Text("Close")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(DesignTokens.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(DesignTokens.Brand.accent(themeManager.resolvedColorScheme))
                    )
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Background.primary(themeManager.resolvedColorScheme))
    }
}

// MARK: - Image Selection Section

struct ImageSelectionSection: View {
    @ObservedObject var viewModel: ImageProcessingViewModel
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Select Images")
                .font(.headline)
                .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))

            HStack(spacing: DesignTokens.Spacing.md) {
                // Image Slot 1
                ImageSlot(
                    index: 0,
                    image: viewModel.selectedImages.first,
                    imageItem: $viewModel.imageItems[0],
                    onRemove: { viewModel.removeImage(at: 0) }
                )
                .onChange(of: viewModel.imageItems[0]) { _ in
                    viewModel.handleImageSelection(at: 0)
                }

                // Image Slot 2
                ImageSlot(
                    index: 1,
                    image: viewModel.selectedImages.count > 1 ? viewModel.selectedImages[1] : nil,
                    imageItem: $viewModel.imageItems[1],
                    onRemove: { viewModel.removeImage(at: 1) }
                )
                .onChange(of: viewModel.imageItems[1]) { _ in
                    viewModel.handleImageSelection(at: 1)
                }
            }

            Text("Select 1-2 images (optional)")
                .font(.caption)
                .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
        }
    }
}

// MARK: - Image Slot Component

struct ImageSlot: View {
    let index: Int
    let image: UIImage?
    @Binding var imageItem: PhotosPickerItem?
    let onRemove: () -> Void

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        PhotosPicker(selection: $imageItem, matching: .images) {
            ZStack(alignment: .topTrailing) {
                if let image = image {
                    // Show selected image
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Remove button
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.black.opacity(0.6)))
                    }
                    .padding(8)
                } else {
                    // Empty slot
                    VStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 40))
                            .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))

                        Text("Image \(index + 1)")
                            .font(.caption)
                            .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(DesignTokens.Background.secondary(themeManager.resolvedColorScheme))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [8]))
                            .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme).opacity(0.3))
                    )
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Prompt Section (Editable)

struct PromptSection: View {
    @ObservedObject var viewModel: ImageProcessingViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Prompt")
                .font(.headline)
                .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))

            TextField("Describe what you want to create...", text: $viewModel.prompt, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(DesignTokens.Spacing.md)
                .lineLimit(3...8)
                .focused($isTextFieldFocused)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(DesignTokens.Background.secondary(themeManager.resolvedColorScheme))
                )
        }
    }
}

// MARK: - Settings Section (Collapsible)

struct SettingsSection: View {
    @ObservedObject var viewModel: ImageProcessingViewModel
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 0) {
            // Settings Header (Always Visible)
            Button(action: { viewModel.toggleSettings() }) {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(DesignTokens.Brand.accent(themeManager.resolvedColorScheme))

                    Text("Settings")
                        .font(.headline)
                        .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))

                    Spacer()

                    // Current settings preview when collapsed
                    if !viewModel.showingSettings {
                        Text("\(viewModel.selectedModel.displayName) • \(viewModel.selectedAspectRatio.rawValue)")
                            .font(.caption)
                            .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                    }

                    Image(systemName: viewModel.showingSettings ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                }
                .padding(DesignTokens.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(DesignTokens.Background.secondary(themeManager.resolvedColorScheme))
                )
            }
            .buttonStyle(PlainButtonStyle())

            // Settings Content (Collapsible)
            if viewModel.showingSettings {
                VStack(spacing: DesignTokens.Spacing.md) {
                    // Model Selection
                    ModelPicker(viewModel: viewModel)

                    // Aspect Ratio Picker
                    AspectRatioPicker(viewModel: viewModel)

                    // Resolution Picker (Pro only)
                    if viewModel.selectedModel.supportsResolution {
                        ResolutionPicker(viewModel: viewModel)
                    }

                    // Output Format Picker
                    OutputFormatPicker(viewModel: viewModel)
                }
                .padding(DesignTokens.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(DesignTokens.Background.secondary(themeManager.resolvedColorScheme).opacity(0.5))
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }
}

// MARK: - Model Picker

struct ModelPicker: View {
    @ObservedObject var viewModel: ImageProcessingViewModel
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Model")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))

            Picker("Model", selection: Binding(
                get: { viewModel.selectedModel },
                set: { viewModel.selectModel($0) }
            )) {
                ForEach(ModelType.allCases) { model in
                    Text(model.displayName).tag(model)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

// MARK: - Aspect Ratio Picker

struct AspectRatioPicker: View {
    @ObservedObject var viewModel: ImageProcessingViewModel
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Aspect Ratio")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))

            Menu {
                ForEach(AspectRatio.allCases) { ratio in
                    Button {
                        viewModel.selectedAspectRatio = ratio
                    } label: {
                        HStack {
                            Text(ratio.displayName)
                            Text("(\(ratio.rawValue))")
                                .font(.caption)
                            if ratio == viewModel.selectedAspectRatio {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Image(systemName: viewModel.selectedAspectRatio.iconName)
                    Text(viewModel.selectedAspectRatio.displayName)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                }
                .padding(DesignTokens.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(DesignTokens.Background.primary(themeManager.resolvedColorScheme))
                )
            }
        }
    }
}

// MARK: - Resolution Picker

struct ResolutionPicker: View {
    @ObservedObject var viewModel: ImageProcessingViewModel
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Resolution")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))

            Picker("Resolution", selection: $viewModel.selectedResolution) {
                ForEach(Resolution.allCases) { resolution in
                    Text(resolution.displayName).tag(resolution)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

// MARK: - Output Format Picker

struct OutputFormatPicker: View {
    @ObservedObject var viewModel: ImageProcessingViewModel
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Output Format")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))

            Picker("Format", selection: $viewModel.selectedOutputFormat) {
                ForEach(OutputFormat.allCases) { format in
                    Text(format.displayName).tag(format)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

// MARK: - Credit Cost Card

struct CreditCostCard: View {
    @ObservedObject var viewModel: ImageProcessingViewModel
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Estimated Cost")
                    .font(.subheadline)
                    .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))

                HStack(spacing: 4) {
                    Text("\(viewModel.estimatedCost)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("credits")
                        .font(.subheadline)
                }
                .foregroundColor(DesignTokens.Brand.accent(themeManager.resolvedColorScheme))
            }

            Spacer()

            if !viewModel.hasEnoughCredits {
                Text("Insufficient credits")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(DesignTokens.Brand.accent(themeManager.resolvedColorScheme).opacity(0.1))
        )
    }
}

// MARK: - Generate Button

struct GenerateButton: View {
    @ObservedObject var viewModel: ImageProcessingViewModel
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        Button {
            Task {
                await viewModel.generateImage()
            }
        } label: {
            HStack(spacing: DesignTokens.Spacing.sm) {
                if viewModel.isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("Generating...")
                } else {
                    Image(systemName: "wand.and.stars")
                    Text("Generate")
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(DesignTokens.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(viewModel.canGenerate ? DesignTokens.Brand.accent(themeManager.resolvedColorScheme) : Color.gray)
            )
        }
        .disabled(!viewModel.canGenerate)
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedTab = 0

        var body: some View {
            NavigationStack {
                ImageProcessingView(
                    viewModel: ImageProcessingViewModel(
                        theme: Tool(
                            name: "Test Theme",
                            description: "Test description",
                            category: "Fun",
                            modelName: "nano-banana",
                            placeholderIcon: "sparkles",
                            prompt: "Add sunglasses"
                        )
                    ),
                    sourceTab: $selectedTab,
                    targetTab: 0
                )
                .environmentObject(ThemeManager())
                .environmentObject(AppState())
            }
        }
    }

    return PreviewWrapper()
}
