//
//  ChatViewModel.swift
//  noname_banana
//
//  Created by AI Assistant on 13.10.2025.
//

import SwiftUI
import PhotosUI

// MARK: - Processing Job Status Enum
enum ProcessingJobStatus: Equatable {
    case idle
    case submitting
    case queued
    case processing(elapsedTime: Int)
    case completed
    case failed(error: String)
    
    var isActive: Bool {
        switch self {
        case .idle, .completed, .failed:
            return false
        case .submitting, .queued, .processing:
            return true
        }
    }
    
    var displayText: String {
        switch self {
        case .idle:
            return "Ready"
        case .submitting:
            return "Submitting..."
        case .queued:
            return "Queued..."
        case .processing(let elapsed):
            if elapsed < 30 {
                return "Processing... (\(elapsed)s)"
            } else if elapsed < 60 {
                return "Processing... (\(elapsed)s) - Almost done!"
            } else {
                let minutes = elapsed / 60
                let seconds = elapsed % 60
                return "Processing... (\(minutes)m \(seconds)s)"
            }
        case .completed:
            return "Completed!"
        case .failed(let error):
            return "Failed: \(error)"
        }
    }
}

@MainActor
class ChatViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var selectedImageItem: PhotosPickerItem?
    @Published var jobStatus: ProcessingJobStatus = .idle
    @Published var processedImage: UIImage?
    @Published var errorMessage: String?
    @Published var showingImagePicker = false
    @Published var uploadProgress: Double = 0.0
    @Published var showingPaywall = false
    @Published var showingLogin = false
    // Quota properties now connected to HybridCreditManager
    var dailyQuotaUsed: Int {
        return creditManager.dailyQuotaUsed
    }
    
    var dailyQuotaLimit: Int {
        return creditManager.dailyQuotaLimit
    }
    @Published var currentPrompt: String = "" // Current prompt for processing
    @Published var messages: [ChatMessage] = [] // Chat messages for displaying results
    @Published var currentJobID: String? = nil // Current job being processed
    
    // Computed property for backward compatibility
    var isProcessing: Bool {
        return jobStatus.isActive
    }
    
    // MARK: - Quota Management (Connected to HybridCreditManager)
    var remainingQuota: Int {
        return creditManager.remainingQuota
    }
    
    var isPremiumUser: Bool {
        return creditManager.isPremiumUser
    }
    
    private let authService = HybridAuthService.shared
    private let storageService = StorageService.shared
    private let supabaseService = SupabaseService.shared
    // private let adaptyService = AdaptyService.shared
    private let creditManager = HybridCreditManager.shared
    private var inFlightTasks: [Task<Void, Never>] = []
    
    init() {
        // Quota management is now handled by HybridCreditManager
        // No need to load quota separately
    }
    
    // MARK: - Prompt Management
    func setInitialPrompt(_ prompt: String) {
        currentPrompt = prompt
    }
    
    // MARK: - Chat Message Management
    func addMessage(_ message: ChatMessage) {
        messages.append(message)
    }
    
    func addUserMessage(content: String, image: UIImage? = nil) {
        let message = ChatMessage(
            type: .user,
            content: content,
            image: image,
            timestamp: Date()
        )
        addMessage(message)
    }
    
    func addAssistantMessage(content: String, image: UIImage? = nil) {
        let message = ChatMessage(
            type: .assistant,
            content: content,
            image: image,
            timestamp: Date()
        )
        addMessage(message)
    }
    
    func addErrorMessage(content: String) {
        let message = ChatMessage(
            type: .error,
            content: content,
            image: nil,
            timestamp: Date()
        )
        addMessage(message)
    }
    
    // Handle PhotosPickerItem selection
    func handleImageItemSelection() {
        guard let item = selectedImageItem else { return }
        loadImage(from: item)
    }
    
    // MARK: - Image Selection
    func selectImage() {
        showingImagePicker = true
    }
    
    @available(iOS 16.0, *)
    func handleImageSelection(_ result: Result<PhotosPickerItem, Error>) {
        switch result {
        case .success(let item):
            loadImage(from: item)
        case .failure(let error):
            let appError = AppError.from(error)
            errorMessage = appError.errorDescription ?? "Failed to load image"
        }
    }
    
    @available(iOS 16.0, *)
    private func loadImage(from item: PhotosPickerItem) {
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    errorMessage = "Failed to load image"
                    return
                }
                
                selectedImage = image
                errorMessage = nil
            } catch {
                let appError = AppError.from(error)
            errorMessage = appError.errorDescription ?? "An error occurred"
            }
        }
    }
    
    // MARK: - Image Processing
    func processSelectedImage() async {
        guard let image = selectedImage else {
            errorMessage = "No image selected"
            return
        }
        
        // Check quota limits for anonymous users
        if !authService.isAuthenticated {
            if dailyQuotaUsed >= dailyQuotaLimit {
                showingPaywall = true
                return
            }
        }
        
        let task = Task {
            await processImage(image)
        }
        inFlightTasks.append(task)
        await task.value
    }
    
    private func processImage(_ image: UIImage) async {
        // Check network connectivity before making API calls
        guard NetworkMonitor.shared.checkConnectivity() else {
            errorMessage = NetworkMonitor.shared.networkErrorMessage
            jobStatus = .failed(error: NetworkMonitor.shared.networkErrorMessage)
            return
        }
        
        // Check image size limit (10MB)
        let maxSize = 10_000_000 // 10 MB
        if let data = image.jpegData(compressionQuality: 1.0),
           data.count > maxSize {
            errorMessage = "🚫 Image too large (\(data.count / 1_000_000) MB). Please select an image under 10 MB."
            jobStatus = .failed(error: "Image too large")
            return
        }
        
        jobStatus = .submitting
        errorMessage = nil
        uploadProgress = 0.0
        currentJobID = nil
        
        // Add user message with the prompt and image
        let promptContent: String
        if !currentPrompt.isEmpty {
            promptContent = currentPrompt
        } else {
            promptContent = "Enhance this image"
        }
        addUserMessage(
            content: promptContent,
            image: image
        )
        
        do {
            // Step 1: Compress image efficiently using Core Image
            guard let imageData = storageService.compressImageToData(image, maxDimension: 1024, quality: 0.8) else {
                throw ChatError.processingFailed
            }
            
            uploadProgress = 0.1
            
            // Step 2: Upload image to Supabase Storage first
            let imageURL = try await supabaseService.uploadImageToStorage(imageData: imageData)
            
            uploadProgress = 0.2
            
            
            // Step 3: 🍎 STEVE JOBS STYLE - Direct processing (no polling!)
            jobStatus = .processing(elapsedTime: 0)
            uploadProgress = 0.3
            
            // Add status message
            addAssistantMessage(
                content: "🤖 Processing your image with AI...",
                image: nil
            )
            
            // Use original prompt directly
            let originalPrompt: String
            if !currentPrompt.isEmpty {
                originalPrompt = currentPrompt
            } else {
                originalPrompt = "Enhance this image"
            }
            
            // Call the Steve Jobs style function - returns result directly!
            let steveJobsResult = try await supabaseService.processImageSteveJobsStyle(
                imageURL: imageURL,
                prompt: originalPrompt
            )
            
            uploadProgress = 0.8
            
            
            // Step 4: Download processed image directly (no polling needed!)
            guard let processedImageURL = steveJobsResult.processedImageURL else {
                throw ChatError.invalidResult
            }
            
            uploadProgress = 0.9
            
            // Download the processed image
            guard let url = URL(string: processedImageURL) else {
                throw ChatError.invalidResult
            }
            let (processedImageData, _) = try await URLSession.shared.data(from: url)
            
            guard let processedUIImage = UIImage(data: processedImageData) else {
                throw ChatError.invalidResult
            }
            
            processedImage = processedUIImage
            jobStatus = .completed
            uploadProgress = 1.0
            
            // Update assistant message with the processed image
            if let lastMessage = messages.last, lastMessage.type == .assistant {
                // Update the last message
                messages[messages.count - 1] = ChatMessage(
                    type: .assistant,
                    content: "✨ Your image has been processed successfully!",
                    image: processedUIImage,
                    timestamp: Date()
                )
            } else {
                // Add new message
                addAssistantMessage(
                    content: "✨ Your image has been processed successfully!",
                    image: processedUIImage
                )
            }
            
            // Refresh quota after successful processing
            await creditManager.loadQuota()
            // Trigger UI update for quota display
            objectWillChange.send()
            
        } catch {
            let appError = AppError.from(error)
            errorMessage = appError.errorDescription ?? "Processing failed"
            jobStatus = .failed(error: appError.errorDescription ?? "Processing failed")
            uploadProgress = 0.0
            
            
            // Update or add error message to chat
            if let lastMessage = messages.last, lastMessage.type == .assistant, lastMessage.image == nil {
                // Update the waiting message with error
                messages[messages.count - 1] = ChatMessage(
                    type: .error,
                    content: "❌ Processing failed: \(error.localizedDescription)",
                    image: nil,
                    timestamp: Date()
                )
            } else {
                // Add error message to chat
                addErrorMessage(content: "❌ Processing failed: \(error.localizedDescription)")
            }
        }
        
        // Clean up temporary image data after processing
        storageService.cleanupTemporaryImageData()
        
        // Reset after a delay
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if !jobStatus.isActive {
                jobStatus = .idle
            }
        }
    }
    
    private func extractPathFromURL(_ urlString: String) -> String {
        // Extract path from Supabase Storage URL
        // This is a simplified implementation - adjust based on your URL structure
        let url = URL(string: urlString)
        let pathComponents = url?.pathComponents ?? []
        
        // Skip the first "/" component
        return pathComponents.dropFirst().joined(separator: "/")
    }
    
    // MARK: - Save to Photos
    func saveProcessedImage() {
        guard let image = processedImage else {
            errorMessage = "No processed image to save"
            return
        }
        
        Task {
            do {
                let hasPermission = await storageService.requestPhotoLibraryPermission()
                guard hasPermission else {
                    errorMessage = "Photo library access denied"
                    return
                }
                
                try await storageService.saveToPhotos(image)
                errorMessage = nil
            } catch {
                let appError = AppError.from(error)
            errorMessage = appError.errorDescription ?? "An error occurred"
            }
        }
    }
    
    // MARK: - Message-Specific Actions
    func saveMessageImage(_ messageId: UUID) async -> SaveImageResult {
        guard let message = messages.first(where: { $0.id == messageId }),
              let image = message.image else {
            return .failure(.noImage)
        }
        
        // Request permission
        let hasPermission = await storageService.requestPhotoLibraryPermission()
        guard hasPermission else {
            return .failure(.permissionDenied)
        }
        
        // Save to photos
        do {
            try await storageService.saveToPhotos(image)
            return .success
        } catch {
            return .failure(.saveFailed(error.localizedDescription))
        }
    }
    
    func shareMessageImage(_ messageId: UUID) {
        guard let message = messages.first(where: { $0.id == messageId }),
              let image = message.image else {
            errorMessage = "No image found in this message"
            return
        }
        
        // Present share sheet
        Task { @MainActor in
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                
                let shareSheet = storageService.shareImage(image)
                shareSheet.popoverPresentationController?.sourceView = window
                shareSheet.popoverPresentationController?.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                shareSheet.popoverPresentationController?.permittedArrowDirections = []
                
                rootViewController.present(shareSheet, animated: true)
            }
        }
    }
    
    // MARK: - Reset
    func reset() {
        selectedImage = nil
        selectedImageItem = nil
        processedImage = nil
        errorMessage = nil
        uploadProgress = 0.0
        currentPrompt = ""
        messages = []
        jobStatus = .idle
        currentJobID = nil
        for task in inFlightTasks {
            task.cancel()
        }
        inFlightTasks.removeAll()
    }
    
    func apply(_ prompt: String?) {
        self.currentPrompt = prompt ?? ""
        // NOTE: Image picker open is driven by AppState.sessionId change (outside this class)
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Quota Management
    // Legacy local quota implementation removed. Quota is now managed by HybridCreditManager.
    
    // MARK: - Paywall Flow
    func showPaywall() {
        if authService.isAuthenticated {
            // Show paywall for authenticated users
            showingPaywall = true
        } else {
            // Show login first, then paywall
            showingLogin = true
        }
    }
    
    func handleLoginSuccess() {
        showingLogin = false
        showingPaywall = true
    }
}

// MARK: - Chat Message Model
struct ChatMessage: Identifiable {
    let id = UUID()
    let type: MessageType
    let content: String
    let image: UIImage?
    let timestamp: Date
    
    enum MessageType {
        case user
        case assistant
        case error
    }
}

// MARK: - Save Image Result
enum SaveImageResult {
    case success
    case failure(SaveImageError)
}

enum SaveImageError {
    case noImage
    case permissionDenied
    case saveFailed(String)
}

// MARK: - Errors
enum ChatError: Error {
    case processingFailed
    case invalidResult
    case noImageSelected
    
    var localizedDescription: String {
        switch self {
        case .processingFailed:
            return "AI processing failed"
        case .invalidResult:
            return "Invalid processed image"
        case .noImageSelected:
            return "No image selected"
        }
    }
}
