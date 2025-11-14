//
//  AppError.swift
//  BananaUniverse
//
//  Created by AppError on 2024.
//  Centralized error handling with user-friendly messages
//

import Foundation

/// Centralized error types with user-friendly messages and recovery suggestions
enum AppError: LocalizedError {
    // MARK: - Network & Connectivity
    case networkUnavailable
    case requestTimeout
    case serverUnavailable
    case invalidResponse
    
    // MARK: - Image Processing
    case imageTooLarge
    case imageFormatUnsupported
    case processingTimeout
    case processingFailed(String)
    case noImageSelected
    case imageLoadFailed
    
    // MARK: - Credits & Quota
    case insufficientCredits
    case dailyQuotaExceeded
    case quotaResetRequired
    
    // MARK: - Storage & Permissions
    case photoLibraryAccessDenied
    case storageFull
    case saveFailed
    case downloadFailed
    
    // MARK: - Authentication
    case authenticationFailed
    case sessionExpired
    case accountSuspended
    case signInRequired
    
    // MARK: - Payments
    case purchaseFailed
    case restoreFailed
    case productNotFound
    
    // MARK: - General
    case unknown(String)
    case serviceUnavailable
    
    // MARK: - User-Friendly Error Descriptions
    var errorDescription: String? {
        switch self {
        // Network & Connectivity
        case .networkUnavailable:
            return "No internet connection. Please check your network and try again."
        case .requestTimeout:
            return "The request took too long. Please check your connection and try again."
        case .serverUnavailable:
            return "Our servers are temporarily unavailable. Please try again in a few minutes."
        case .invalidResponse:
            return "Received an unexpected response. Please try again."
            
        // Image Processing
        case .imageTooLarge:
            return "Image is too large. Please select an image under 10MB for best results."
        case .imageFormatUnsupported:
            return "This image format isn't supported. Please try a JPEG or PNG image."
        case .processingTimeout:
            return "Processing took too long. Please try with a smaller image."
        case .processingFailed(let message):
            return "Image processing failed: \(message)"
        case .noImageSelected:
            return "Please select an image first."
        case .imageLoadFailed:
            return "Failed to load the selected image. Please try a different one."
            
        // Credits & Quota
        case .insufficientCredits:
            return "You're out of credits! Tap here to get more and continue processing images."
        case .dailyQuotaExceeded:
            return "You've reached your daily limit. Come back tomorrow or purchase more credits."
        case .quotaResetRequired:
            return "Your daily quota has been reset. You can now process more images."
            
        // Storage & Permissions
        case .photoLibraryAccessDenied:
            return "Photo library access is required to save images. Please enable it in Settings."
        case .storageFull:
            return "Your device storage is full. Please free up space and try again."
        case .saveFailed:
            return "Failed to save image. Please try again or check your storage space."
        case .downloadFailed:
            return "Failed to download image. Please check your connection and try again."
            
        // Authentication
        case .authenticationFailed:
            return "Sign in failed. Please check your credentials and try again."
        case .sessionExpired:
            return "Your session has expired. Please sign in again."
        case .accountSuspended:
            return "Your account has been suspended. Please contact support."
        case .signInRequired:
            return "Please sign in to continue."
            
        // Payments
        case .purchaseFailed:
            return "Purchase failed. Please check your payment method and try again."
        case .restoreFailed:
            return "Failed to restore purchases. Please try again or contact support."
        case .productNotFound:
            return "Product not available. Please try again later."
            
        // General
        case .unknown(let message):
            return "An unexpected error occurred: \(message)"
        case .serviceUnavailable:
            return "Service temporarily unavailable. Please try again in a few minutes."
        }
    }
    
    // MARK: - Recovery Suggestions
    var recoverySuggestion: String? {
        switch self {
        case .networkUnavailable:
            return "Check your WiFi or cellular connection"
        case .requestTimeout:
            return "Try again with a better connection"
        case .serverUnavailable:
            return "Wait a few minutes and try again"
        case .imageTooLarge:
            return "Compress your image or select a smaller one"
        case .insufficientCredits:
            return "Purchase more credits or wait for daily reset"
        case .dailyQuotaExceeded:
            return "Purchase more credits to continue"
        case .photoLibraryAccessDenied:
            return "Go to Settings > Privacy > Photos and enable access"
        case .authenticationFailed:
            return "Check your email and password"
        case .purchaseFailed:
            return "Verify your payment method"
        default:
            return "Try again or contact support if the problem persists"
        }
    }
    
    // MARK: - Error Severity
    var severity: ErrorSeverity {
        switch self {
        case .networkUnavailable, .requestTimeout, .serverUnavailable:
            return .warning
        case .insufficientCredits, .dailyQuotaExceeded:
            return .info
        case .authenticationFailed, .sessionExpired, .accountSuspended:
            return .error
        case .photoLibraryAccessDenied, .storageFull:
            return .error
        case .purchaseFailed, .restoreFailed:
            return .error
        default:
            return .warning
        }
    }
}

// MARK: - Error Severity Levels
enum ErrorSeverity {
    case info
    case warning
    case error
    case critical
}

// MARK: - Error Mapping Extensions
extension AppError {
    /// Maps technical errors to user-friendly AppError
    static func from(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        
        // Map common system errors
        let nsError = error as NSError
        switch nsError.domain {
        case NSURLErrorDomain:
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
                return .networkUnavailable
            case NSURLErrorTimedOut:
                return .requestTimeout
            case NSURLErrorCannotConnectToHost, NSURLErrorCannotFindHost:
                return .serverUnavailable
            default:
                return .unknown("Network error: \(nsError.localizedDescription)")
            }
        case "SupabaseError":
            // Map Supabase errors
            if nsError.localizedDescription.contains("insufficient") {
                return .insufficientCredits
            } else if nsError.localizedDescription.contains("timeout") {
                return .processingTimeout
            } else {
                return .unknown("Service error: \(nsError.localizedDescription)")
            }
        default:
            return .unknown(nsError.localizedDescription)
        }
    }
}
