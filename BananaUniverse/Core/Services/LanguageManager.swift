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
        }
    }
    
    private init() {
        // 1. Check if user already saved a preference
        if let savedLanguage = UserDefaults.standard.string(forKey: "app_language") {
            self.currentLanguage = savedLanguage
        } else {
            // 2. Resolve based on device language
            self.currentLanguage = LanguageManager.resolveDeviceLanguage().rawValue
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
    
    /// Returns the bundle for the current language
    var bundle: Bundle {
        print("🌐 [LanguageManager] Current Language: \(currentLanguage)")
        if let path = Bundle.main.path(forResource: currentLanguage, ofType: "lproj") {
            print("🌐 [LanguageManager] Found bundle path: \(path)")
            if let bundle = Bundle(path: path) {
                return bundle
            }
        }
        print("🌐 [LanguageManager] Bundle NOT found for \(currentLanguage), falling back to .main")
        return .main
    }
    
    func setLanguage(_ language: String) {
        print("🌐 [LanguageManager] Setting language to: \(language)")
        withAnimation {
            currentLanguage = language
        }
    }
}
