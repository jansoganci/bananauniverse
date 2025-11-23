//
//  LibraryViewModel.swift
//  noname_banana
//
//  Created by AI Assistant on 16.10.2025.
//  ViewModel for Library screen
//

import Foundation
import SwiftUI
import Photos
import PhotosUI
import Supabase

// MARK: - Library Error Types
enum LibraryError: LocalizedError {
    case loadFailed(String)
    case deleteFailed(String)
    case downloadFailed(String)
    case noQuotaRemaining
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .loadFailed(let message):
            return "Failed to load history: \(message)"
        case .deleteFailed(let message):
            return "Failed to delete item: \(message)"
        case .downloadFailed(let message):
            return "Failed to download image: \(message)"
        case .noQuotaRemaining:
            return "No credits remaining. Please upgrade to Pro for unlimited edits."
        case .networkError:
            return "Network error. Please check your connection and try again."
        }
    }
}

// MARK: - History Date Group
struct HistoryDateGroup {
    let header: String
    let items: [HistoryItem]
}

// MARK: - Signed URL Cache Actor
actor SignedURLCache {
    private var cache: [String: URL] = [:]
    
    func get(url: String) -> URL? {
        return cache[url]
    }
    
    func set(url: String, signedURL: URL) {
        cache[url] = signedURL
    }
}

// MARK: - Library View Model
@MainActor
class LibraryViewModel: ObservableObject {
    @Published var historyItems: [HistoryItem] = []
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?
    @Published var showingError = false
    @Published var selectedItem: HistoryItem?
    @Published var showingShareSheet = false
    @Published var showingDeleteConfirmation = false
    @Published var itemToDelete: HistoryItem?
    @Published var isDownloading = false
    @Published var downloadingItemID: String?
    
    // Services
    private let supabaseService: SupabaseService
    private let authService: HybridAuthService
    private let storageService: StorageService
    private let creditManager: CreditManager
    
    // Image Cache
    private let imageCache = NSCache<NSString, UIImage>()
    
    // MARK: - Computed Properties
    
    var hasHistoryItems: Bool {
        !historyItems.isEmpty
    }
    
    var isLoadingOrRefreshing: Bool {
        isLoading || isRefreshing
    }
    
    var canPerformActions: Bool {
        !isLoadingOrRefreshing && hasHistoryItems
    }
    
    // MARK: - Phase 2 Date Grouping
    
    /// Recent items for horizontal preview section (top 6 items)
    var recentActivityItems: [HistoryItem] {
        Array(historyItems.prefix(6))
    }
    
    /// Groups history items by date: Today, This Week, Earlier
    var groupedHistoryItems: [HistoryDateGroup] {
        let calendar = Calendar.current
        let now = Date()
        
        var groups: [HistoryDateGroup] = []
        var todayItems: [HistoryItem] = []
        var thisWeekItems: [HistoryItem] = []
        var earlierItems: [HistoryItem] = []
        
        for item in historyItems {
            let daysSince = calendar.dateComponents([.day], from: item.createdAt, to: now).day ?? 0
            
            if calendar.isDateInToday(item.createdAt) {
                todayItems.append(item)
            } else if daysSince <= 7 {
                thisWeekItems.append(item)
            } else {
                earlierItems.append(item)
            }
        }
        
        // Add groups only if they have items
        if !todayItems.isEmpty {
            groups.append(HistoryDateGroup(header: "Today", items: todayItems))
        }
        if !thisWeekItems.isEmpty {
            groups.append(HistoryDateGroup(header: "This Week", items: thisWeekItems))
        }
        if !earlierItems.isEmpty {
            groups.append(HistoryDateGroup(header: "Earlier", items: earlierItems))
        }
        
        return groups
    }
    
    init(
        supabaseService: SupabaseService? = nil,
        authService: HybridAuthService? = nil,
        storageService: StorageService? = nil,
        creditManager: CreditManager? = nil
    ) {
        self.supabaseService = supabaseService ?? SupabaseService.shared
        self.authService = authService ?? HybridAuthService.shared
        self.storageService = storageService ?? StorageService.shared
        self.creditManager = creditManager ?? CreditManager.shared
        
        // Configure image cache
        imageCache.countLimit = 50
        imageCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        
        // Add memory warning observer
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.clearImageCache()
            }
        }
    }
    
    func loadHistory() async {
        isLoading = true
        errorMessage = nil
        showingError = false

        #if DEBUG
        print("📚 [LibraryViewModel] Starting loadHistory()...")
        #endif

        do {
            // Get current user state
            let userState = authService.userState

            #if DEBUG
            print("📚 [LibraryViewModel] UserState: \(userState.isAuthenticated ? "authenticated" : "anonymous"), ID: \(userState.identifier)")
            #endif
            
            // Fetch jobs from database
            let jobs = try await supabaseService.fetchUserJobs(
                userState: userState,
                limit: 50
            )

            #if DEBUG
            print("📚 [LibraryViewModel] Fetched \(jobs.count) jobs from database")
            if !jobs.isEmpty {
                print("📚 [LibraryViewModel] First job: ID=\(jobs[0].id), status=\(jobs[0].status), outputURL=\(jobs[0].outputURL != nil ? "YES" : "NO")")
            }
            #endif
            
            // Capture client reference while still on main actor
            let supabaseClient = supabaseService.client
            
            // Move network-heavy URL generation off main actor
            let newHistoryItems = await Task.detached { [weak self] in
                guard let self = self else { return [HistoryItem]() }
                
                let urlCache = SignedURLCache()
                var results: [HistoryItem] = []
                
                await withTaskGroup(of: HistoryItem?.self) { group in
                    for job in jobs {
                        group.addTask {
                            // Get or generate signed URL (only for completed jobs)
                            let signedURL: URL?
                            if let outputURL = job.outputURL {
                                // Check cache first
                                if let cached = await urlCache.get(url: outputURL) {
                                    signedURL = cached
                                } else {
                                    // Generate new signed URL
                                    if let generated = await self.nonActorSignedURL(for: outputURL, client: supabaseClient) {
                                        await urlCache.set(url: outputURL, signedURL: generated)
                                        signedURL = generated
                                    } else {
                                        signedURL = nil
                                    }
                                }
                            } else {
                                signedURL = nil
                            }

                            // Create history item - use createdAt instead of completedAt
                            let historyItem = HistoryItem(
                                id: job.id.uuidString,
                                thumbnailURL: signedURL,
                                effectTitle: self.extractEffectTitle(from: job),
                                effectId: job.model ?? "unknown",  // Handle optional model
                                status: self.mapJobStatus(job.status),
                                createdAt: job.createdAt,  // Changed from completedAt to createdAt
                                resultURL: signedURL,
                                originalImageKey: job.inputURL
                            )

                            return historyItem
                        }
                    }
                    
                    // Collect results as they complete
                    for await item in group {
                        if let item = item {
                            results.append(item)
                        }
                    }
                }
                
                return results
            }.value
            
            // Update UI on main thread
            historyItems = newHistoryItems

            #if DEBUG
            print("📚 [LibraryViewModel] ✅ Loaded \(newHistoryItems.count) history items")
            #endif

        } catch {
            let appError = AppError.from(error)
            let libraryError = LibraryError.loadFailed(appError.errorDescription ?? "Failed to load history")
            errorMessage = libraryError.errorDescription
            showingError = true

            #if DEBUG
            print("📚 [LibraryViewModel] ❌ Error: \(error)")
            print("📚 [LibraryViewModel] ❌ AppError: \(appError.errorDescription ?? "Unknown")")
            #endif
        }

        isLoading = false

        #if DEBUG
        print("📚 [LibraryViewModel] loadHistory() completed. Items: \(historyItems.count)")
        #endif
    }
    
    func refreshHistory() async {
        isRefreshing = true
        await loadHistory()
        isRefreshing = false
    }
    
    func rerunJob(_ item: HistoryItem) async {
        
        // Check if user has quota
        guard creditManager.hasQuotaLeft else {
            let libraryError = LibraryError.noQuotaRemaining
            errorMessage = libraryError.errorDescription
            showingError = true
            return
        }
        
        // TODO: Implement re-run job logic
        // This would involve:
        // 1. Re-submitting the job with the same parameters
        // 2. Updating the item status to "processing"
        // 3. Polling for completion
        // 4. Updating the UI when complete
        
    }
    
    func shareResult(_ item: HistoryItem) {
        selectedItem = item
        showingShareSheet = true
    }
    
    func deleteJob(_ item: HistoryItem) async {
        
        // TODO: Implement proper delete with API
        // This would involve:
        // 1. Delete from database
        // 2. Delete from storage
        // 3. Update local state
        
        // For now, just remove from local array
        historyItems.removeAll { $0.id == item.id }
        
    }
    
    func navigateToResult(_ item: HistoryItem) {
        selectedItem = item
        // TODO: Implement navigation to ResultView
        // This would involve:
        // 1. Setting up navigation state
        // 2. Passing the item data
        // 3. Presenting the result view
    }
    
    // MARK: - Error Handling
    
    func clearError() {
        errorMessage = nil
        showingError = false
    }
    
    func dismissShareSheet() {
        showingShareSheet = false
        selectedItem = nil
    }
    
    func confirmDelete() {
        guard let item = itemToDelete else { return }
        Task {
            await deleteJob(item)
        }
        itemToDelete = nil
        showingDeleteConfirmation = false
    }
    
    func cancelDelete() {
        itemToDelete = nil
        showingDeleteConfirmation = false
    }
    
    // MARK: - Helper Methods
    
    /// Non-isolated helper method for extracting effect title (pure function, no actor isolation needed)
    nonisolated private func extractEffectTitle(from job: JobRecord) -> String {
        // Try to get from prompt first
        if let prompt = job.options?.prompt, !prompt.isEmpty {
            // Take first 40 chars of prompt as title
            let trimmed = String(prompt.prefix(40))
            return trimmed.count < prompt.count ? trimmed + "..." : trimmed
        }

        // Fallback to model name (handle optional)
        guard let model = job.model else {
            return "AI Effect"  // Default title when model is nil
        }

        switch model {
        case "nano-banana-edit":
            return "AI Enhancement"
        case "upscale":
            return "Upscale"
        default:
            return model.capitalized
        }
    }
    
    /// Non-isolated helper method for mapping job status (pure function, no actor isolation needed)
    nonisolated private func mapJobStatus(_ status: String) -> JobStatus {
        switch status.lowercased() {
        case "completed":
            return .completed
        case "processing":
            return .processing
        case "failed":
            return .failed
        case "cancelled":
            return .cancelled
        default:
            return .failed
        }
    }
    
    func generateSignedURL(from path: String) async -> URL? {
        // Use proper Supabase signed URL generation
        do {
            let signedURLString = try await supabaseService.getSignedURL(for: path)
            return URL(string: signedURLString)
        } catch {
            // Fallback to public URL if signed URL fails
            let baseURL = "\(Config.supabaseURL)/storage/v1/object/public/\(Config.supabaseBucket)"
            let fullPath = "\(baseURL)/\(path)"
            return URL(string: fullPath)
        }
    }
    
    // MARK: - Non-Actor Signed URL Generation
    
    /// Non-isolated helper for parallel signed URL generation off the main actor
    nonisolated private func nonActorSignedURL(for path: String, client: SupabaseClient) async -> URL? {
        do {
            // Use provided client to generate signed URL (thread-safe operation)
            let signedURL = try await client.storage
                .from(Config.supabaseBucket)
                .createSignedURL(path: path, expiresIn: 2592000) // 30 days expiration
            
            return signedURL
        } catch {
            // Fallback to public URL if signed URL fails
            let baseURL = "\(Config.supabaseURL)/storage/v1/object/public/\(Config.supabaseBucket)"
            let fullPath = "\(baseURL)/\(path)"
            return URL(string: fullPath)
        }
    }
    
    // MARK: - Download Functionality
    
    func downloadImage(_ item: HistoryItem) async {
        guard let resultURL = item.resultURL else {
            return
        }
        
        // Set loading state
        isDownloading = true
        downloadingItemID = item.id
        
        
        do {
            // Download image data
            let (data, response) = try await URLSession.shared.data(from: resultURL)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                isDownloading = false
                downloadingItemID = nil
                return
            }
            
            // Save to Photos library
            try await saveImageToPhotos(data: data)
            
            
        } catch {
            // Show error to user
            let appError = AppError.from(error)
            errorMessage = appError.errorDescription ?? "Failed to download image"
            showingError = true
        }
        
        // Clear loading state
        isDownloading = false
        downloadingItemID = nil
    }
    
    private func saveImageToPhotos(data: Data) async throws {
        // Request photo library permission
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        switch status {
        case .authorized, .limited:
            // Permission already granted, proceed with saving
            try await performPhotoSave(data: data)
            
        case .notDetermined:
            // Request permission
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            if newStatus == .authorized || newStatus == .limited {
                try await performPhotoSave(data: data)
            } else {
            }
            
        case .denied, .restricted:
            break
            
        @unknown default:
            break
        }
    }
    
    private func performPhotoSave(data: Data) async throws {
        try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                let creationRequest = PHAssetCreationRequest.forAsset()
                creationRequest.addResource(with: .photo, data: data, options: nil)
            }) { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? LibraryError.downloadFailed("Unknown error saving to Photos"))
                }
            }
        }
    }
    
    // MARK: - Image Caching
    
    func getCachedImage(for url: URL) -> UIImage? {
        let key = NSString(string: url.absoluteString)
        return imageCache.object(forKey: key)
    }
    
    func cacheImage(_ image: UIImage, for url: URL) {
        let key = NSString(string: url.absoluteString)
        imageCache.setObject(image, forKey: key)
    }
    
    private func clearImageCache() {
        imageCache.removeAllObjects()
    }
}
