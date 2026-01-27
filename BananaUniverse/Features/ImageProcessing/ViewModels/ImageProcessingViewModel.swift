//
//  ImageProcessingViewModel.swift
//  BananaUniverse
//
//  Created by AI Assistant on 2025-11-20.
//  Purpose: Clean, focused ViewModel for image processing with nano-banana models
//

import SwiftUI
import PhotosUI

@MainActor
class ImageProcessingViewModel: ObservableObject {

    // MARK: - Published Properties

    // Image Selection
    @Published var selectedImages: [UIImage] = []
    @Published var imageItems: [PhotosPickerItem?] = [nil, nil] // 2 slots
    @Published var isLoadingImages = false

    // Model Configuration (Defaults as specified)
    @Published var selectedModel: ModelType = .nanoBananaPro // Default to Pro
    @Published var selectedAspectRatio: AspectRatio = .auto
    @Published var selectedResolution: Resolution = .twoK // Default 2K for Pro
    @Published var selectedOutputFormat: OutputFormat = .png

    // Prompt (editable by user)
    @Published var prompt: String = ""

    // UI State
    @Published var showingSettings = false // Collapsible settings
    @Published var isProcessing = false
    @Published var showingPaywall = false
    @Published var errorMessage: String?

    // Processing Result
    @Published var resultImageURL: URL?
    @Published var showingResult = false
    @Published var showingProcessing = false
    @Published var processingJobId: String?
    @Published var resultJobId: String? // Result page job ID
    @Published var processingTheme: Tool?
    @Published private var processingComplete = false  // Guard against duplicate handler calls
    @Published var isImageSaved: Bool = false // Whether image has been saved

    // MARK: - Dependencies
    
    private let supabaseService = SupabaseService.shared
    private let creditManager = CreditManager.shared
    private let storageService = StorageService.shared
    
    // MARK: - Computed Properties

    /// Estimated credit cost based on current settings
    var estimatedCost: Int {
        selectedModel.creditCost(resolution: selectedModel.supportsResolution ? selectedResolution : nil)
    }

    /// Whether user has enough credits
    var hasEnoughCredits: Bool {
        creditManager.creditsRemaining >= estimatedCost
    }

    /// Whether Generate button should be enabled
    var canGenerate: Bool {
        !selectedImages.isEmpty && !prompt.isEmpty && hasEnoughCredits && !isProcessing
    }

    /// Number of selected images (0-2)
    var imageCount: Int {
        selectedImages.count
    }

    // MARK: - Initialization

    init(theme: Tool? = nil) {
        // Pre-fill prompt with theme if provided (user can edit it)
        if let theme = theme {
            self.prompt = theme.prompt
        }

        #if DEBUG
        print("🎨 [ImageProcessingViewModel] Initialized with theme: \(theme?.name ?? "none")")
        print("📊 [ImageProcessingViewModel] Default settings: \(selectedModel.displayName), \(selectedAspectRatio.rawValue), \(selectedOutputFormat.rawValue)")
        #endif
    }

    // MARK: - Image Selection

    /// Handle image picker item selection
    func handleImageSelection(at index: Int) {
        guard index < imageItems.count else { return }
        guard let item = imageItems[index] else { return }

        isLoadingImages = true

        Task {
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {

                    // Add or replace image at index
                    if index < selectedImages.count {
                        selectedImages[index] = image
                    } else {
                        selectedImages.append(image)
                    }

                    #if DEBUG
                    print("✅ [ImageProcessingViewModel] Image \(index + 1) loaded")
                    #endif
                }
            } catch {
                errorMessage = "Failed to load image: \(error.localizedDescription)"
                #if DEBUG
                print("❌ [ImageProcessingViewModel] Image loading error: \(error)")
                #endif
            }

            isLoadingImages = false
        }
    }

    /// Remove image at index
    func removeImage(at index: Int) {
        guard index < selectedImages.count else { return }
        selectedImages.remove(at: index)
        imageItems[index] = nil

        #if DEBUG
        print("🗑️ [ImageProcessingViewModel] Removed image at index \(index)")
        #endif
    }

    // MARK: - Model Selection

    /// Change model type (updates resolution if needed)
    func selectModel(_ model: ModelType) {
        selectedModel = model

        // Reset resolution if switching to standard model
        if !model.supportsResolution {
            selectedResolution = .twoK // Keep default but won't be used
        } else if let defaultResolution = model.defaultResolution {
            selectedResolution = defaultResolution
        }

        #if DEBUG
        print("🔄 [ImageProcessingViewModel] Model changed to: \(model.displayName)")
        print("💳 [ImageProcessingViewModel] New estimated cost: \(estimatedCost) credits")
        #endif
    }

    // MARK: - Processing

    /// Generate image with selected settings
    func generateImage() async {
        // Check network connectivity before attempting generation
        guard NetworkMonitor.shared.checkConnectivity() else {
            errorMessage = "You're offline. Please check your internet connection and try again."
            return
        }

        guard canGenerate else {
            if !hasEnoughCredits {
                showingPaywall = true
            }
            return
        }

        isProcessing = true
        errorMessage = nil

        #if DEBUG
        print("🚀 [ImageProcessingViewModel] Starting generation...")
        print("📸 Images: \(imageCount)")
        print("🎨 Model: \(selectedModel.displayName)")
        print("📐 Aspect Ratio: \(selectedAspectRatio.rawValue)")
        print("🎯 Resolution: \(selectedModel.supportsResolution ? selectedResolution.rawValue : "N/A")")
        print("📄 Format: \(selectedOutputFormat.rawValue)")
        print("💳 Cost: \(estimatedCost) credits")
        #endif

        do {
            // Step 1: Upload images to Supabase Storage
            var uploadedImageURLs: [String] = []

            for (index, image) in selectedImages.enumerated() {
                #if DEBUG
                print("📤 [ImageProcessingViewModel] Uploading image \(index + 1)/\(imageCount)...")
                #endif

                guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                    throw NSError(domain: "ImageProcessingViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
                }

                let imageURL = try await supabaseService.uploadImageToStorage(imageData: imageData)
                uploadedImageURLs.append(imageURL)

                #if DEBUG
                print("✅ [ImageProcessingViewModel] Image \(index + 1) uploaded: \(imageURL)")
                #endif
            }

            // Step 2: Submit job with new parameters
            #if DEBUG
            print("🚀 [ImageProcessingViewModel] Submitting job to backend...")
            #endif

            let submitResponse = try await supabaseService.submitImageJob(
                imageURLs: uploadedImageURLs,
                prompt: prompt,
                modelType: selectedModel,
                aspectRatio: selectedAspectRatio,
                outputFormat: selectedOutputFormat,
                resolution: selectedModel.supportsResolution ? selectedResolution : nil
            )

            guard submitResponse.success else {
                throw NSError(domain: "ImageProcessingViewModel", code: 2, userInfo: [NSLocalizedDescriptionKey: submitResponse.error ?? "Job submission failed"])
            }

            let jobId = submitResponse.jobId

            #if DEBUG
            print("✅ [ImageProcessingViewModel] Job submitted: \(jobId)")
            #endif

            // Update credits from response
            if let creditsRemaining = submitResponse.creditInfo?.creditsRemaining {
                await creditManager.updateFromBackendResponse(creditsRemaining: creditsRemaining)
            }

            // Step 3: Show ProcessingView with Realtime subscription
            // The ProcessingView will handle the job monitoring via Supabase Realtime
            processingJobId = jobId
            processingComplete = false // Reset guard flag for new job
            showingProcessing = true
            isProcessing = false // Allow user to navigate away

            #if DEBUG
            print("🎬 [ImageProcessingViewModel] Showing ProcessingView for job: \(jobId)")
            #endif

        } catch {
            // Use ErrorMessageTranslator for user-friendly messages
            if ErrorMessageTranslator.isNetworkError(error) {
                errorMessage = ErrorMessageTranslator.userFriendlyMessage(for: error)
            } else {
                errorMessage = "Generation failed. Please try again."
            }

            #if DEBUG
            print("❌ [ImageProcessingViewModel] Generation error: \(error)")
            #endif

            isProcessing = false
        }
    }

    /// Called when ProcessingView completes successfully
    func handleProcessingComplete(imageUrl: String) {
        // Guard against duplicate calls
        guard !processingComplete else {
            #if DEBUG
            print("⚠️ [ImageProcessingViewModel] Duplicate completion call ignored")
            #endif
            return
        }

        processingComplete = true
        
        // Store job ID for deletion operation
        if let jobId = processingJobId {
            resultJobId = jobId
        }
        
        // Reset saved state
        isImageSaved = false

        #if DEBUG
        print("✅ [ImageProcessingViewModel] Processing completed: \(imageUrl), jobId: \(resultJobId ?? "nil")")
        #endif

        // Clear any previous error messages
        errorMessage = nil

        Task {
            // Check if we received a raw path (from Realtime) or a full URL
            var finalURLString = imageUrl
            
            if !imageUrl.hasPrefix("http") {
                // It's a storage path, we need to sign it
                do {
                    finalURLString = try await supabaseService.getSignedURL(for: imageUrl, expiresIn: 3600) // 1 hour
                    #if DEBUG
                    print("🔑 [ImageProcessingViewModel] Signed URL generated: \(finalURLString)")
                    #endif
                } catch {
                    print("❌ [ImageProcessingViewModel] Failed to sign URL: \(error)")
                    errorMessage = "Failed to load image secure link"
                    return
                }
            }
            
            if let url = URL(string: finalURLString) {
                await MainActor.run {
                    resultImageURL = url
                    showingProcessing = false
                    showingResult = true
                }
            }
        }
    }
    
    /// Save image to device and mark as saved in backend
    func saveImageToDevice() async {
        guard let imageURL = resultImageURL else { return }
        
        do {
            // 1. Download image
            let (imageData, _) = try await URLSession.shared.data(from: imageURL)
            guard let image = UIImage(data: imageData) else {
                throw NSError(domain: "ImageProcessingViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert data to image"])
            }
            
            // 2. Save to Photo Library
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            
            // 3. Mark as saved in backend (prevents auto-delete)
            if let jobId = resultJobId {
                try await supabaseService.markImageAsSaved(jobId: jobId)
                
                // 4. Optional: Delete from server immediately to save space?
                // Plan says: "Cihaza indir, sunucudan sil"
                // So yes, delete it.
                try await supabaseService.deleteProcessedImage(jobId: jobId)
            }
            
            await MainActor.run {
                self.isImageSaved = true
            }
            
            #if DEBUG
            print("✅ [ImageProcessingViewModel] Image saved and marked for deletion")
            #endif
            
        } catch {
            #if DEBUG
            print("❌ [ImageProcessingViewModel] Failed to save image: \(error)")
            #endif
            // Handle error (show alert?)
        }
    }

    /// Called when ProcessingView encounters an error
    func handleProcessingError(_ error: String) {
        // Guard against duplicate calls
        guard !processingComplete else {
            #if DEBUG
            print("⚠️ [ImageProcessingViewModel] Duplicate error call ignored")
            #endif
            return
        }

        processingComplete = true

        #if DEBUG
        print("❌ [ImageProcessingViewModel] Processing error: \(error)")
        #endif

        errorMessage = error
        showingProcessing = false
        isProcessing = false
    }

    // MARK: - Settings Management

    /// Toggle settings visibility
    func toggleSettings() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showingSettings.toggle()
        }

        #if DEBUG
        print("⚙️ [ImageProcessingViewModel] Settings \(showingSettings ? "expanded" : "collapsed")")
        #endif
    }

    /// Reset to default settings
    func resetToDefaults() {
        selectedModel = .nanoBananaPro
        selectedAspectRatio = .auto
        selectedResolution = .twoK
        selectedOutputFormat = .png

        #if DEBUG
        print("🔄 [ImageProcessingViewModel] Reset to defaults")
        #endif
    }

    // MARK: - Error Handling

    func clearError() {
        errorMessage = nil
    }
}
