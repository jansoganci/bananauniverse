//
//  CategoryFeaturedMapping.swift
//  BananaUniverse
//
//  Created by AI Assistant on 22.10.2025.
//  Utility for mapping categories to featured tools
//

import Foundation

// MARK: - Category Featured Mapping Utility
struct CategoryFeaturedMapping {
    
    // MARK: - Featured Tool Selection
    /// Returns the featured tool for a given category
    /// - Parameter category: The category ID
    /// - Returns: The featured tool for the category, or nil if not found
    static func featuredTool(for category: String) -> Tool? {
        switch category {
        case "main_tools":
            return Tool.mainTools.first { $0.id == "remove_object" }
        case "pro_looks":
            return Tool.proLooksTools.first { $0.id == "linkedin_headshot" }
        case "restoration":
            return Tool.restorationTools.first { $0.id == "image_upscaler" }
        default:
            return nil
        }
    }
    
    // MARK: - Remaining Tools
    /// Returns the remaining tools for a category (excluding the featured tool)
    /// - Parameter category: The category ID
    /// - Returns: Array of tools excluding the featured tool
    static func remainingTools(for category: String) -> [Tool] {
        let allTools = currentTools(for: category)
        let featured = featuredTool(for: category)
        return allTools.filter { $0.id != featured?.id }
    }
    
    // MARK: - All Tools for Category
    /// Returns all tools for a given category
    /// - Parameter category: The category ID
    /// - Returns: Array of all tools in the category
    static func currentTools(for category: String) -> [Tool] {
        switch category {
        case "main_tools":
            return Tool.mainTools
        case "pro_looks":
            return Tool.proLooksTools
        case "restoration":
            return Tool.restorationTools
        default:
            return Tool.mainTools
        }
    }
    
    // MARK: - Category Validation
    /// Validates if a category ID is valid
    /// - Parameter category: The category ID to validate
    /// - Returns: True if the category is valid, false otherwise
    static func isValidCategory(_ category: String) -> Bool {
        return ["main_tools", "pro_looks", "restoration"].contains(category)
    }
    
    // MARK: - Featured Tool Reasons
    /// Returns the reason why a tool is featured for a category
    /// - Parameter category: The category ID
    /// - Returns: A description of why the tool is featured
    static func featuredToolReason(for category: String) -> String {
        switch category {
        case "main_tools":
            return "Most Popular This Week"
        case "pro_looks":
            return "Most Valuable Pro Tool"
        case "restoration":
            return "Most Useful Restoration Tool"
        default:
            return "Featured Tool"
        }
    }
    
    // MARK: - Category Display Names
    /// Returns the display name for a category
    /// - Parameter category: The category ID
    /// - Returns: The display name for the category
    static func categoryDisplayName(for category: String) -> String {
        switch category {
        case "main_tools":
            return "Photo Editor"
        case "pro_looks":
            return "Pro Photos"
        case "restoration":
            return "Enhancer"
        default:
            return "Unknown Category"
        }
    }
}

// MARK: - Featured Tool Selection Logic
extension CategoryFeaturedMapping {
    
    /// The logic behind featured tool selection:
    /// - Main Tools: "Remove Object" - Most popular free tool, high user engagement
    /// - Pro Looks: "LinkedIn Headshot" - Most valuable premium tool, high conversion potential
    /// - Restoration: "Image Upscaler" - Most useful restoration tool, broad appeal
    
    static let featuredToolIds: [String: String] = [
        "main_tools": "remove_object",
        "pro_looks": "linkedin_headshot", 
        "restoration": "image_upscaler"
    ]
    
    /// Returns the featured tool ID for a category
    /// - Parameter category: The category ID
    /// - Returns: The featured tool ID, or nil if not found
    static func featuredToolId(for category: String) -> String? {
        return featuredToolIds[category]
    }
}
