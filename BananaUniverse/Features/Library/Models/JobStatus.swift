//
//  JobStatus.swift
//  noname_banana
//
//  Created by AI Assistant on 16.10.2025.
//  Job status enum for Library screen
//

import SwiftUI

// MARK: - Job Status Enum
enum JobStatus: String, Codable {
    case completed
    case processing
    case failed
    case cancelled
    
    var displayText: String {
        switch self {
        case .completed: return "Completed"
        case .processing: return "Processing"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }
    
    func badgeColor(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .completed: return DesignTokens.Brand.secondary(colorScheme)
        case .processing: return DesignTokens.Brand.primary(.light)
        case .failed: return DesignTokens.Semantic.error(colorScheme)
        case .cancelled: return DesignTokens.Text.quaternary(colorScheme)
        }
    }
}
