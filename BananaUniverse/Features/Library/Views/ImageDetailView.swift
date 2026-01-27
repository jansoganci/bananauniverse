//
//  ImageDetailView.swift
//  BananaUniverse
//
//  Created by AI Assistant on 17.10.2025.
//

import SwiftUI
import PhotosUI

struct ImageDetailView: View {
    let imageURL: URL
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showingShareSheet = false
    @State private var isDownloading = false
    @State private var downloadSuccess = false
    
    var body: some View {
        ZStack {
            // Background
            DesignTokens.Surface.overlay(themeManager.resolvedColorScheme)
                .ignoresSafeArea()
            
            // Main content
            VStack(spacing: 0) {
                // Top bar with close button
                HStack {
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            dismiss()
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(DesignTokens.Text.inverse)
                            .frame(width: 44, height: 44)
                            .background(DesignTokens.Surface.overlay(themeManager.resolvedColorScheme))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    // Action buttons
                    HStack(spacing: 16) {
                        // Download button
                        Button(action: {
                            Task {
                                await downloadImage()
                            }
                        }) {
                            Group {
                                if isDownloading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else if downloadSuccess {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(DesignTokens.Semantic.success(themeManager.resolvedColorScheme))
                                } else {
                                    Image(systemName: "arrow.down.circle")
                                        .foregroundColor(DesignTokens.Text.inverse)
                                }
                            }
                            .frame(width: 44, height: 44)
                            .background(DesignTokens.Surface.overlay(themeManager.resolvedColorScheme))
                            .clipShape(Circle())
                        }
                        .disabled(isDownloading)
                        
                        // Share button
                        Button(action: {
                            showingShareSheet = true
                        }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(DesignTokens.Text.inverse)
                            .frame(width: 44, height: 44)
                            .background(DesignTokens.Surface.overlay(themeManager.resolvedColorScheme))
                            .clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                // Image content
                GeometryReader { geometry in
                    CachedAsyncImage(
                        url: imageURL,
                        contentMode: .fit
                    )
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        SimultaneousGesture(
                            // Magnification gesture for zoom
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8)) {
                                        scale = min(max(scale * delta, 1.0), 5.0)
                                    }
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if scale < 1.0 {
                                            scale = 1.0
                                            offset = .zero
                                        } else if scale > 5.0 {
                                            scale = 5.0
                                        }
                                    }
                                },
                            
                            // Drag gesture for pan
                            DragGesture()
                                .onChanged { value in
                                    let newOffset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                    
                                    // Limit pan based on zoom level
                                    let maxOffsetX = max(0, (geometry.size.width * (scale - 1)) / 2)
                                    let maxOffsetY = max(0, (geometry.size.height * (scale - 1)) / 2)
                                    
                                    offset = CGSize(
                                        width: min(max(newOffset.width, -maxOffsetX), maxOffsetX),
                                        height: min(max(newOffset.height, -maxOffsetY), maxOffsetY)
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                    )
                    .onTapGesture(count: 2) {
                        // Double tap to reset zoom
                        withAnimation(.easeInOut(duration: 0.3)) {
                            scale = 1.0
                            offset = .zero
                            lastScale = 1.0
                            lastOffset = .zero
                        }
                    }
                    .onAppear {
                        // Reset gestures when image appears
                        scale = 1.0
                        lastScale = 1.0
                        offset = .zero
                        lastOffset = .zero
                    }
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: [imageURL])
        }
    }
    
    // MARK: - Download Functionality
    
    private func downloadImage() async {
        guard !isDownloading else { return }
        
        isDownloading = true
        downloadSuccess = false
        
        do {
            // Download image data
            let (data, response) = try await URLSession.shared.data(from: imageURL)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                isDownloading = false
                return
            }
            
            // Save to Photos library
            try await saveImageToPhotos(data: data)
            
            downloadSuccess = true
            
            // Reset success state after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                downloadSuccess = false
            }
            
        } catch {
        }
        
        isDownloading = false
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
                throw ImageDetailError.permissionDenied
            }
            
        case .denied, .restricted:
            throw ImageDetailError.permissionDenied
            
        @unknown default:
            throw ImageDetailError.permissionDenied
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
                    continuation.resume(throwing: error ?? ImageDetailError.saveFailed("Unknown error saving to Photos"))
                }
            }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Error Types

enum ImageDetailError: LocalizedError {
    case permissionDenied
    case saveFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Photo library access denied"
        case .saveFailed(let message):
            return "Failed to save image: \(message)"
        }
    }
}

// MARK: - Preview

#Preview {
    ImageDetailView(imageURL: URL(string: "https://example.com/image.jpg")!)
}
