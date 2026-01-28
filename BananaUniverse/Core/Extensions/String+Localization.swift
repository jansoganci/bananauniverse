//
//  String+Localization.swift
//  BananaUniverse
//
//  Created by AI Assistant on 14.10.2025.
//  String localization extension for easy access
//

import Foundation

extension String {
    /// Localized string using NSLocalizedString
    var localized: String {
        let bundle = LanguageManager.shared.bundle
        return NSLocalizedString(self, bundle: bundle, comment: "")
    }
    
    /// Localized string with format arguments
    func localized(_ arguments: CVarArg...) -> String {
        let bundle = LanguageManager.shared.bundle
        let localizedString = NSLocalizedString(self, bundle: bundle, comment: "")
        return String(format: localizedString, arguments: arguments)
    }
    
    /// Localized string with specific table name
    func localized(tableName: String? = nil, bundle: Bundle = .main) -> String {
        NSLocalizedString(self, tableName: tableName, bundle: bundle, comment: "")
    }
}

