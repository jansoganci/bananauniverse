//
//  AspectRatio.swift
//  BananaUniverse
//
//  Created by AI Assistant on 2025-11-20.
//  Purpose: Defines aspect ratio options for image processing
//

import Foundation

/// Aspect ratio options for generated images
/// Supports 11 ratios from ultrawide to portrait formats
enum AspectRatio: String, Codable, CaseIterable, Identifiable {
    case auto = "auto"
    case square = "1:1"
    case widescreen = "16:9"
    case portrait = "9:16"
    case classic = "4:3"
    case photography = "3:2"
    case ultrawide = "21:9"
    case fiveByFour = "5:4"
    case fourByFive = "4:5"
    case threeByFour = "3:4"
    case twoByThree = "2:3"

    var id: String { rawValue }

    // MARK: - Display Properties

    /// User-friendly display name for UI
    var displayName: String {
        switch self {
        case .auto:
            return "Auto"
        case .square:
            return "Square"
        case .widescreen:
            return "Widescreen"
        case .portrait:
            return "Portrait"
        case .classic:
            return "Classic"
        case .photography:
            return "Photography"
        case .ultrawide:
            return "Ultrawide"
        case .fiveByFour:
            return "5:4"
        case .fourByFive:
            return "4:5"
        case .threeByFour:
            return "3:4"
        case .twoByThree:
            return "2:3"
        }
    }

    /// Short description of use case
    var description: String {
        switch self {
        case .auto:
            return "Let AI decide"
        case .square:
            return "Instagram, profile pics"
        case .widescreen:
            return "YouTube, presentations"
        case .portrait:
            return "Stories, TikTok"
        case .classic:
            return "Traditional photos"
        case .photography:
            return "DSLR standard"
        case .ultrawide:
            return "Cinema format"
        case .fiveByFour:
            return "4x5 camera"
        case .fourByFive:
            return "Portrait 4x5"
        case .threeByFour:
            return "Portrait classic"
        case .twoByThree:
            return "Portrait photo"
        }
    }

    /// Icon name (SF Symbols)
    var iconName: String {
        switch self {
        case .auto:
            return "wand.and.stars"
        case .square:
            return "square"
        case .widescreen, .ultrawide:
            return "rectangle"
        case .portrait, .fourByFive, .threeByFour, .twoByThree:
            return "rectangle.portrait"
        case .classic, .photography, .fiveByFour:
            return "photo"
        }
    }

    // MARK: - Grouping for UI

    /// Popular aspect ratios (for quick access)
    static var popular: [AspectRatio] {
        [.auto, .square, .widescreen, .portrait, .classic, .photography]
    }

    /// All aspect ratios (for advanced picker)
    static var all: [AspectRatio] {
        AspectRatio.allCases
    }

    /// Whether this is a landscape orientation
    var isLandscape: Bool {
        switch self {
        case .widescreen, .classic, .photography, .ultrawide, .fiveByFour:
            return true
        case .portrait, .fourByFive, .threeByFour, .twoByThree:
            return false
        case .auto, .square:
            return false // Neutral
        }
    }

    /// Whether this is a portrait orientation
    var isPortrait: Bool {
        switch self {
        case .portrait, .fourByFive, .threeByFour, .twoByThree:
            return true
        case .widescreen, .classic, .photography, .ultrawide, .fiveByFour:
            return false
        case .auto, .square:
            return false // Neutral
        }
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension AspectRatio {
    static var preview: AspectRatio { .auto }
}
#endif
