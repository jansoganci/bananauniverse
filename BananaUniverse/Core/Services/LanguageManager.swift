//
//  LanguageManager.swift
//  BananaUniverse
//
//  Created by AI Assistant on 28.01.2026.
//

import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case turkish = "tr"
    case spanish = "es"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .turkish: return "Türkçe"
        case .spanish: return "Español"
        }
    }
}

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @Published var currentLanguage: String {
        didSet {
            UserDefaults.standard.set(currentLanguage, forKey: "app_language")
            updateBundle()
        }
    }
    
    /// Cached bundle to avoid repeated path lookups and logging
    private(set) var bundle: Bundle = .main
    
    private init() {
        // 1. Check if user already saved a preference
        let savedLanguage = UserDefaults.standard.string(forKey: "app_language") 
            ?? LanguageManager.resolveDeviceLanguage().rawValue
        
        self.currentLanguage = savedLanguage
        updateBundle()
    }
    
    private func updateBundle() {
        if let path = Bundle.main.path(forResource: currentLanguage, ofType: "lproj"),
           let newBundle = Bundle(path: path) {
            self.bundle = newBundle
        } else {
            self.bundle = .main
        }
    }
    
    static func resolveDeviceLanguage() -> AppLanguage {
        let preferredLanguages = Locale.preferredLanguages
        
        for lang in preferredLanguages {
            if lang.hasPrefix("tr") {
                return .turkish
            } else if lang.hasPrefix("es") {
                return .spanish
            } else if lang.hasPrefix("en") {
                return .english
            }
        }
        
        return .english // Fallback
    }
    
    func setLanguage(_ language: String) {
        withAnimation {
            currentLanguage = language
        }
    }
}
