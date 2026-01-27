//
//  SearchHistoryService.swift
//  BananaUniverse
//
//  Created by AI Assistant on 2026-01-27.
//  Simple UserDefaults-based storage for recent searches
//

import Foundation

/// Service for managing search history
/// Stores up to 10 recent searches in UserDefaults
class SearchHistoryService {
    static let shared = SearchHistoryService()
    
    private let userDefaults = UserDefaults.standard
    private let key = "recent_searches"
    private let maxItems = 10
    
    private init() {}
    
    /// Add a search query to history
    /// - Parameter query: Search query string (will be trimmed and sanitized)
    func addSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        var searches = getRecentSearches()
        
        // Remove if already exists (to move to top)
        searches.removeAll { $0.lowercased() == trimmed.lowercased() }
        
        // Add to beginning
        searches.insert(trimmed, at: 0)
        
        // Keep only max items
        if searches.count > maxItems {
            searches = Array(searches.prefix(maxItems))
        }
        
        // Save to UserDefaults
        userDefaults.set(searches, forKey: key)
    }
    
    /// Get recent searches (most recent first)
    /// - Returns: Array of recent search queries
    func getRecentSearches() -> [String] {
        return userDefaults.stringArray(forKey: key) ?? []
    }
    
    /// Clear all search history
    func clearHistory() {
        userDefaults.removeObject(forKey: key)
    }
}
