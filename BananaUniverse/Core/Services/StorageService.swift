//
//  StorageService.swift
//  noname_banana
//
//  Created by AI Assistant on 13.10.2025.
//

import Foundation
import UIKit
import Photos
import PhotosUI
import CoreImage

@MainActor
class StorageService: ObservableObject {
    static let shared = StorageService()
    
    @Published var errorMessage: String?
    
    private let supabase: SupabaseService
    
    init(supabase: SupabaseService) {
        self.supabase = supabase
    }
    
    convenience init() {
        self.init(supabase: SupabaseService.shared)
    }
    
    // MARK: - Image Download
    func downloadImage(from path: String) async throws -> UIImage {
        errorMessage = nil
        
        do {
            let data = try await supabase.downloadImage(path: path)
            
            guard let image = UIImage(data: data) else {
                throw StorageError.invalidImage
            }
            
            return image
        } catch {
            let appError = AppError.from(error)
            errorMessage = appError.errorDescription ?? "Storage operation failed"
            throw appError
        }
    }
    
    // MARK: - Photos Library
    func saveToPhotos(_ image: UIImage) async throws {
        errorMessage = nil
        
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.creationRequestForAsset(from: image)
            }
        } catch {
            let appError = AppError.from(error)
            errorMessage = appError.errorDescription ?? "Storage operation failed"
            throw appError
        }
    }
    
    func requestPhotoLibraryPermission() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        switch status {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            return newStatus == .authorized || newStatus == .limited
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
    
    // MARK: - Image Processing
    func compressImage(_ image: UIImage, maxSize: CGSize = CGSize(width: 1024, height: 1024)) -> UIImage {
        var tempImage: UIImage?
        var tempData: Data?
        
        defer {
            tempImage = nil
            tempData = nil
            #if DEBUG
            print("💾 Image compression completed, memory released successfully")
            #endif
        }
        
        return autoreleasepool {
            guard let cgImage = image.cgImage else { return image }
            
            // Create Core Image context for efficient GPU-based processing
            let ciImage = CIImage(cgImage: cgImage)
            let context = CIContext(options: [.useSoftwareRenderer: false])
            defer {
                context.clearCaches()
                #if DEBUG
                print("🧹 Core Image caches cleared after compression")
                #endif
            }
            
            // Calculate scaling factor
            let widthScale = maxSize.width / CGFloat(cgImage.width)
            let heightScale = maxSize.height / CGFloat(cgImage.height)
            let scale = min(widthScale, heightScale, 1.0)
            
            // Skip if no scaling needed
            if scale >= 1.0 {
                return image
            }
            
            // Resize using Core Image instead of UIGraphics
            let transform = CGAffineTransform(scaleX: scale, y: scale)
            let resized = ciImage.transformed(by: transform)
            
            // Render the resized image
            if let outputCGImage = context.createCGImage(resized, from: resized.extent) {
                tempImage = UIImage(cgImage: outputCGImage)
                #if DEBUG
                print("✅ Image compressed efficiently using Core Image")
                #endif
                return tempImage ?? image
            }
            
            return image
        }
    }
    
    // MARK: - Optimized Image Compression with Quality Control
    func compressImageToData(_ image: UIImage, maxDimension: CGFloat = 1024, quality: CGFloat = 0.8) -> Data? {
        var tempImage: UIImage?
        var tempData: Data?
        
        defer {
            tempImage = nil
            tempData = nil
            #if DEBUG
            print("💾 Image compression to data completed, memory released successfully")
            #endif
        }
        
        return autoreleasepool {
            // CRITICAL FIX: Preserve orientation by fixing it before processing
            guard let fixedImage = image.fixedOrientation() else { return nil }
            guard let cgImage = fixedImage.cgImage else { return nil }
            
            // Create Core Image context for efficient GPU-based processing
            let ciImage = CIImage(cgImage: cgImage)
            let context = CIContext(options: [.useSoftwareRenderer: false])
            defer {
                context.clearCaches()
                #if DEBUG
                print("🧹 Core Image caches cleared after data compression")
                #endif
            }
            
            // Resize using Core Image instead of UIGraphics
            let scale = min(maxDimension / CGFloat(cgImage.width), maxDimension / CGFloat(cgImage.height))
            let transform = CGAffineTransform(scaleX: scale, y: scale)
            let resized = ciImage.transformed(by: transform)
            
            // Render the resized image and compress it once
            if let outputCGImage = context.createCGImage(resized, from: resized.extent) {
                // Now orientation is already fixed, so cgImage is correct
                tempImage = UIImage(cgImage: outputCGImage)
                tempData = tempImage?.jpegData(compressionQuality: quality)
                #if DEBUG
                print("✅ Image compressed to data efficiently using Core Image (orientation preserved)")
                #endif
                return tempData
            }
            return nil
        }
    }
    
    // MARK: - Memory Management
    func cleanupTemporaryImageData() {
        DispatchQueue.global(qos: .background).async {
            autoreleasepool {
                URLCache.shared.removeAllCachedResponses()
                #if DEBUG
                print("🧽 Background image cache cleanup complete")
                #endif
            }
        }
    }
    
    // MARK: - Share Image
    func shareImage(_ image: UIImage) -> UIActivityViewController {
        let activityViewController = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        
        // Configure for iPad
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
            popover.sourceRect = CGRect(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        return activityViewController
    }
    
    func clearError() {
        errorMessage = nil
    }
}

// MARK: - Errors
enum StorageError: Error {
    case invalidImage
    case saveFailed
    case permissionDenied
    case uploadFailed
    
    var localizedDescription: String {
        switch self {
        case .invalidImage:
            return "Invalid image data"
        case .saveFailed:
            return "Failed to save image to Photos"
        case .permissionDenied:
            return "Photo library access denied"
        case .uploadFailed:
            return "Failed to upload image"
        }
    }
}

// MARK: - UIImage Extension for Orientation Fix
extension UIImage {
    /// Fixes image orientation by redrawing the image in the correct orientation
    /// This ensures EXIF orientation data is applied to the actual pixel data
    func fixedOrientation() -> UIImage? {
        // If image is already in correct orientation, return as is
        if imageOrientation == .up {
            return self
        }
        
        // Calculate the transform needed to rotate/flip the image
        var transform = CGAffineTransform.identity
        
        switch imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: size.height)
            transform = transform.rotated(by: .pi)
            
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.rotated(by: .pi / 2)
            
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: size.height)
            transform = transform.rotated(by: -.pi / 2)
            
        case .up, .upMirrored:
            break
            
        @unknown default:
            break
        }
        
        // Apply mirroring if needed
        switch imageOrientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
            
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: size.height, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
            
        default:
            break
        }
        
        // Draw the image with the correct orientation
        guard let cgImage = cgImage,
              let colorSpace = cgImage.colorSpace,
              let context = CGContext(
                data: nil,
                width: Int(size.width),
                height: Int(size.height),
                bitsPerComponent: cgImage.bitsPerComponent,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: cgImage.bitmapInfo.rawValue
              ) else {
            return nil
        }
        
        context.concatenate(transform)
        
        // Draw based on orientation
        switch imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.height, height: size.width))
            
        default:
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        }
        
        guard let newCGImage = context.makeImage() else {
            return nil
        }
        
        return UIImage(cgImage: newCGImage)
    }
}
