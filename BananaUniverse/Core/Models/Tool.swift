//
//  Tool.swift
//  BananaUniverse
//
//  Created by AI Assistant on 16.10.2025.
//  Tool Type Alias - Backward Compatibility
//
//  Tool is now a typealias for Theme (database-driven model).
//  This ensures existing code using Tool continues to work.
//
//  All tool data is now fetched from the database via ThemeService.
//  See Theme.swift for the actual model definition.
//

import Foundation
import SwiftUI

// MARK: - Tool Type Alias (Backward Compatibility)

/// Tool is now a typealias for Theme
/// This allows existing code using `Tool` to continue working
/// while the actual implementation uses the database-driven Theme model
typealias Tool = Theme

