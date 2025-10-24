//
//  ImageUpscalerView.swift
//  noname_banana
//
//  Created by AI Assistant on 13.10.2025.
//

import SwiftUI
import PhotosUI

struct ImageUpscalerView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var supabaseService = SupabaseService.shared
    @StateObject private var creditManager = HybridCreditManager.shared
    @StateObject private var authService = HybridAuthService.shared
    
    @State private var selectedImage: UIImage?
    @State private var upscaledImageURL: URL?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var upscaleFactor: Int = 2
    @State private var showImagePicker = false
    @State private var usageInfo: String = ""
    @State private var debugInfo: String = ""
    @State private var showPaywall = false
    
    let tool: Tool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(tool.title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Enhance your images with AI-powered upscaling")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "A0A9B0"))
                        
                        // Quota display
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(Color(hex: "33C3A4"))
                            Text("Quota: \(creditManager.quotaDisplayText)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            // User state indicator
                            HStack(spacing: 4) {
                                Image(systemName: authService.isAuthenticated ? "person.circle.fill" : "person.circle")
                                    .foregroundColor(authService.isAuthenticated ? .green : .orange)
                                Text(authService.isAuthenticated ? "Signed In" : "Anonymous")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            
                            if authService.isAuthenticated {
                                Image(systemName: "checkmark.icloud.fill")
                                    .foregroundColor(Color(hex: "33C3A4"))
                                    .font(.system(size: 12))
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(hex: "2C2F32"))
                        .cornerRadius(8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Upscale Factor Selector
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Upscale Factor")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        HStack(spacing: 12) {
                            ForEach([2, 4], id: \.self) { factor in
                                Button(action: {
                                    upscaleFactor = factor
                                }) {
                                    Text("\(factor)x")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(upscaleFactor == factor ? .white : Color(hex: "A0A9B0"))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(upscaleFactor == factor ? Color(hex: "33C3A4") : Color(hex: "2C2F32"))
                                        .cornerRadius(12)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Image Selection
                    if let image = selectedImage {
                        VStack(spacing: 16) {
                            Text("Original Image")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 300)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Select Image Button
                    Button(action: {
                        showImagePicker = true
                    }) {
                        HStack {
                            Image(systemName: "photo.fill")
                            Text(selectedImage == nil ? "Select Image" : "Change Image")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(hex: "4D7CFF"))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    .disabled(isProcessing)
                    
                    // Upscale Button
                    if selectedImage != nil {
                        Button(action: {
                            Task {
                                await upscaleImage()
                            }
                        }) {
                            HStack {
                                if isProcessing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    Text("Processing...")
                                        .font(.system(size: 16, weight: .semibold))
                                } else {
                                    Image(systemName: "arrow.up.backward.and.arrow.down.forward")
                                    Text("Upscale Image (\(upscaleFactor)x)")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(isProcessing ? Color.gray : Color(hex: "33C3A4"))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                        .disabled(isProcessing)
                    }
                    
                    // Error Message
                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                    }
                    
                    // Usage Info
                    if !usageInfo.isEmpty {
                        Text(usageInfo)
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "A0A9B0"))
                            .padding()
                            .background(Color(hex: "2C2F32"))
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                    }
                    
                    // Debug Info
                    if !debugInfo.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Debug Info")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.orange)
                            
                            Text(debugInfo)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                    }
                    
                    // Result Image
                    if let url = upscaledImageURL {
                        VStack(spacing: 16) {
                            Text("Upscaled Image (\(upscaleFactor)x)")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .cornerRadius(12)
                                case .failure:
                                    VStack {
                                        Image(systemName: "exclamationmark.triangle")
                                        Text("Failed to load image")
                                    }
                                    .foregroundColor(.red)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .frame(maxHeight: 400)
                            
                            // Download/Share Button
                            Button(action: {
                                // TODO: Implement save/share
                            }) {
                                HStack {
                                    Image(systemName: "square.and.arrow.down")
                                    Text("Save Result")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(hex: "4D7CFF"))
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    Spacer(minLength: 40)
                }
            }
            .background(Color(hex: "0E1012"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage)
        }
        .sheet(isPresented: $showPaywall) {
            PreviewPaywallView()
        }
    }
    
    private func upscaleImage() async {
        // Check network connectivity before making API calls
        guard NetworkMonitor.shared.checkConnectivity() else {
            errorMessage = NetworkMonitor.shared.networkErrorMessage
            return
        }
        
        // Check image size limit (10MB)
        guard let image = selectedImage else {
            errorMessage = "Please select an image first"
            return
        }
        
        let maxSize = 10_000_000 // 10 MB
        if let data = image.jpegData(compressionQuality: 1.0),
           data.count > maxSize {
            errorMessage = "🚫 Image too large (\(data.count / 1_000_000) MB). Please select an image under 10 MB."
            return
        }
        
        // Check quota first (works for both anonymous and authenticated users)
        guard creditManager.hasQuotaLeft else {
            errorMessage = "Daily limit reached. Come back tomorrow or upgrade for unlimited access."
            showPaywall = true
            // TODO: insert Adapty Paywall ID here - placement: upscaler_pro_feature
            return
        }
        
        guard let imageData = StorageService.shared.compressImageToData(image, maxDimension: 1024, quality: 0.8) else {
            errorMessage = "Failed to process image data"
            return
        }
        
        isProcessing = true
        errorMessage = nil
        usageInfo = ""
        debugInfo = "Starting upscale process..."
        
        do {
            // Debug: Check user state
            if authService.isAuthenticated {
                debugInfo = "User: Authenticated"
                if let user = authService.currentUser {
                    debugInfo += "\nUser ID: \(user.id)"
                    debugInfo += "\nEmail: \(user.email ?? "No email")"
                }
            } else {
                debugInfo = "User: Anonymous"
                debugInfo += "\nDevice ID: \(authService.identifier)"
            }
            debugInfo += "\nQuota before: \(creditManager.quotaDisplayText)"
            
            let response = try await supabaseService.upscaleImage(
                imageData: imageData,
                upscaleFactor: upscaleFactor
            )
            
            // Quota automatically consumed in SupabaseService
            debugInfo += "\nQuota after: \(creditManager.quotaDisplayText)"
            
            if let urlString = response.resultUrl,
               let url = URL(string: urlString) {
                upscaledImageURL = url
                
                // Show success info
                usageInfo = """
                ✅ Success! 
                Quota remaining: \(creditManager.remainingQuota)
                User type: \(authService.isAuthenticated ? "Authenticated (Synced)" : "Anonymous (Local)")
                """
                
                debugInfo += "\n✅ Processing complete"
            } else {
                errorMessage = "Processing completed but no result URL received"
            }
            
        } catch let error as SupabaseError {
            let appError = error.appError
            errorMessage = appError.errorDescription ?? "Processing failed"
            if case .insufficientCredits = appError {
                showPaywall = true
                // TODO: insert Adapty Paywall ID here - placement: upscaler_pro_feature
            }
            debugInfo += "\nError: \(appError)"
        } catch {
            let appError = AppError.from(error)
            errorMessage = appError.errorDescription ?? "An unexpected error occurred"
            debugInfo += "\nUnexpected error: \(appError)"
        }
        
        // Clean up temporary image data after processing
        StorageService.shared.cleanupTemporaryImageData()
        
        isProcessing = false
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    ImageUpscalerView(tool:     Tool(
        id: "image_upscaler",
        title: "Image Upscaler",
                imageURL: nil,
        category: "restoration",
        requiresPro: false,
        modelName: "upscale",
        placeholderIcon: "arrow.up.backward.and.arrow.down.forward",
        prompt: "Upscale this image by 2x while maintaining quality"
    ))
}

