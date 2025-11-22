//
//  ModelType.swift
//  BananaUniverse
//
//  Created by AI Assistant on 2025-11-20.
//  Purpose: Defines AI model types for image processing
//

import Foundation

/// AI Model selection for image processing
/// - nanoBanana: Standard model (1 credit, no resolution options)
/// - nanoBananaPro: Pro model (4-8 credits, with resolution control)
enum ModelType: String, Codable, CaseIterable, Identifiable {
    case nanoBanana = "nano-banana"
    case nanoBananaPro = "nano-banana-pro"

    var id: String { rawValue }

    // MARK: - Display Properties

    /// User-friendly display name for UI
    var displayName: String {
        switch self {
        case .nanoBanana:
            return "Standard"
        case .nanoBananaPro:
            return "Pro"
        }
    }

    /// Short description of model capabilities
    var description: String {
        switch self {
        case .nanoBanana:
            return "Fast processing, 1 credit"
        case .nanoBananaPro:
            return "Higher quality, resolution control"
        }
    }

    /// Icon name for model (SF Symbols)
    var iconName: String {
        switch self {
        case .nanoBanana:
            return "bolt.fill"
        case .nanoBananaPro:
            return "sparkles"
        }
    }

    // MARK: - Credit Cost Calculation

    /// Calculate credit cost based on model type and resolution
    /// - Parameter resolution: Resolution tier (only for Pro model)
    /// - Returns: Credit cost (1 for standard, 4-8 for pro)
    func creditCost(resolution: Resolution?) -> Int {
        switch self {
        case .nanoBanana:
            return 1
        case .nanoBananaPro:
            guard let resolution = resolution else {
                return 4 // Default to 2K pricing if no resolution specified
            }
            return resolution.creditCost
        }
    }

    // MARK: - Feature Availability

    /// Whether this model supports resolution selection
    var supportsResolution: Bool {
        self == .nanoBananaPro
    }

    /// Default resolution for this model (nil for standard)
    var defaultResolution: Resolution? {
        switch self {
        case .nanoBanana:
            return nil
        case .nanoBananaPro:
            return .twoK // Default to 2K as specified
        }
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension ModelType {
    static var preview: ModelType { .nanoBananaPro }
}
#endif
