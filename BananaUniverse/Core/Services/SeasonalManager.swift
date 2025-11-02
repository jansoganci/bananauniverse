//
//  SeasonalManager.swift
//  BananaUniverse
//
//  Created by AI Assistant on 31.10.2025.
//  Seasonal event management and featured tool rotation
//

import Foundation

// MARK: - Seasonal Event Manager
class SeasonalManager {
    
    // MARK: - Seasonal Events
    enum SeasonalEvent: String, CaseIterable {
        case thanksgiving = "thanksgiving"
        case christmas = "christmas"
        case newYear = "new_year"
        case general = "general"
        
        var featuredToolId: String {
            switch self {
            case .thanksgiving:
                return "thanksgiving_magic"
            case .christmas:
                return "christmas_magic"
            case .newYear:
                return "new_year_glamour"
            case .general:
                return "thanksgiving_magic" // Default fallback
            }
        }
        
        var displayName: String {
            switch self {
            case .thanksgiving:
                return "Thanksgiving"
            case .christmas:
                return "Christmas"
            case .newYear:
                return "New Year"
            case .general:
                return "Seasonal"
            }
        }
    }
    
    // MARK: - Singleton Instance
    static let shared = SeasonalManager()
    private init() {}
    
    // MARK: - Current Event Detection
    /// Determines the current seasonal event based on date
    /// - Returns: Current active seasonal event
    func currentSeasonalEvent() -> SeasonalEvent {
        let calendar = Calendar.current
        let now = Date()
        let month = calendar.component(.month, from: now)
        let day = calendar.component(.day, from: now)
        
        switch (month, day) {
        case (11, 15...30):
            return .thanksgiving
        case (12, 1...25):
            return .christmas
        case (12, 26...31), (1, 1...7):
            return .newYear
        default:
            return .general
        }
    }
    
    // MARK: - Featured Tool Selection
    /// Returns the featured tool ID for current season
    /// - Returns: Tool ID string for current seasonal featured tool
    func currentFeaturedToolId() -> String {
        return currentSeasonalEvent().featuredToolId
    }
    
    // MARK: - Event Display
    /// Returns the display name for current seasonal event
    /// - Returns: Human-readable seasonal event name
    func currentEventDisplayName() -> String {
        return currentSeasonalEvent().displayName
    }
    
    // MARK: - Debug/Testing
    /// Override current date for testing purposes
    private var _testDate: Date?
    
    func setTestDate(_ date: Date?) {
        _testDate = date
    }
    
    private var testableCurrentDate: Date {
        return _testDate ?? Date()
    }
}

// MARK: - Static Convenience Methods
extension SeasonalManager {
    
    /// Static convenience method for current seasonal event
    static func currentEvent() -> SeasonalEvent {
        return shared.currentSeasonalEvent()
    }
    
    /// Static convenience method for current featured tool ID
    static func featuredToolId() -> String {
        return shared.currentFeaturedToolId()
    }
}