//
//  OutputFormat.swift
//  BananaUniverse
//
//  Created by AI Assistant on 2025-11-20.
//  Purpose: Defines output format options for generated images
//

import Foundation

/// Output format for generated images
/// Each format has different characteristics (quality, file size, compatibility)
enum OutputFormat: String, Codable, CaseIterable, Identifiable {
    case jpeg = "jpeg"
    case png = "png"
    case webp = "webp"

    var id: String { rawValue }

    // MARK: - Display Properties

    /// User-friendly display name for UI
    var displayName: String {
        rawValue.uppercased()
    }

    /// Detailed description with benefits
    var description: String {
        switch self {
        case .jpeg:
            return "Smaller files, web-friendly"
        case .png:
            return "High quality, transparency"
        case .webp:
            return "Modern format, best compression"
        }
    }

    /// Icon name (SF Symbols)
    var iconName: String {
        switch self {
        case .jpeg:
            return "photo.on.rectangle"
        case .png:
            return "photo.on.rectangle.angled"
        case .webp:
            return "photo.badge.checkmark"
        }
    }

    // MARK: - Format Characteristics

    /// Whether this format supports transparency
    var supportsTransparency: Bool {
        switch self {
        case .jpeg:
            return false
        case .png, .webp:
            return true
        }
    }

    /// Relative file size (1=smallest, 3=largest)
    var relativeFileSize: Int {
        switch self {
        case .webp:
            return 1 // Best compression
        case .jpeg:
            return 2 // Good compression
        case .png:
            return 3 // Larger files
        }
    }

    /// Quality level (1-3 scale)
    var qualityLevel: Int {
        switch self {
        case .jpeg:
            return 2
        case .png:
            return 3
        case .webp:
            return 3
        }
    }

    /// Whether this is widely supported across platforms
    var isUniversallySupported: Bool {
        switch self {
        case .jpeg, .png:
            return true
        case .webp:
            return false // Modern, but not all platforms
        }
    }

    /// File extension for saving
    var fileExtension: String {
        rawValue
    }

    /// MIME type for API requests
    var mimeType: String {
        switch self {
        case .jpeg:
            return "image/jpeg"
        case .png:
            return "image/png"
        case .webp:
            return "image/webp"
        }
    }

    // MARK: - Recommendations

    /// Whether this is the recommended default
    var isRecommended: Bool {
        self == .png
    }

    /// Badge text for UI
    var badgeText: String? {
        switch self {
        case .png:
            return "Recommended"
        case .webp:
            return "Best Quality"
        case .jpeg:
            return "Smallest"
        }
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension OutputFormat {
    static var preview: OutputFormat { .png }
}
#endif
