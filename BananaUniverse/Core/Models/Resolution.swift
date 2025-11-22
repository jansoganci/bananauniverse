//
//  Resolution.swift
//  BananaUniverse
//
//  Created by AI Assistant on 2025-11-20.
//  Purpose: Defines resolution tiers for Pro model
//

import Foundation

/// Resolution tiers for nano-banana-pro model
/// Higher resolution = better quality but more credits
enum Resolution: String, Codable, CaseIterable, Identifiable {
    case oneK = "1K"
    case twoK = "2K"
    case fourK = "4K"

    var id: String { rawValue }

    // MARK: - Display Properties

    /// User-friendly display name for UI
    var displayName: String {
        rawValue
    }

    /// Detailed description with quality info
    var description: String {
        switch self {
        case .oneK:
            return "Good quality - 4 credits"
        case .twoK:
            return "High quality - 4 credits"
        case .fourK:
            return "Ultra HD - 8 credits"
        }
    }

    /// Icon name (SF Symbols)
    var iconName: String {
        switch self {
        case .oneK:
            return "photo"
        case .twoK:
            return "photo.fill"
        case .fourK:
            return "sparkles"
        }
    }

    // MARK: - Credit Cost

    /// Credit cost for this resolution tier
    var creditCost: Int {
        switch self {
        case .oneK:
            return 4
        case .twoK:
            return 4
        case .fourK:
            return 8
        }
    }

    // MARK: - Quality Indicators

    /// Quality level (1-3 scale)
    var qualityLevel: Int {
        switch self {
        case .oneK:
            return 1
        case .twoK:
            return 2
        case .fourK:
            return 3
        }
    }

    /// Badge color for UI (based on quality)
    var badgeColor: String {
        switch self {
        case .oneK:
            return "blue"
        case .twoK:
            return "purple"
        case .fourK:
            return "orange"
        }
    }

    /// Whether this is the recommended default option
    var isRecommended: Bool {
        self == .twoK
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension Resolution {
    static var preview: Resolution { .twoK }
}
#endif
