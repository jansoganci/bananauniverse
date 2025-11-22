//
//  Theme.swift
//  BananaUniverse
//
//  Created by AI Assistant on 2025.
//  Theme/Tool data model - now database-driven with Codable support
//

import Foundation
import SwiftUI

// MARK: - Theme Data Model (Database-Driven)

/// Theme represents a tool/effect that can be applied to images
/// This model is fetched from Supabase database and supports remote content management
struct Theme: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let description: String?
    let shortDescription: String?
    let thumbnailURL: URL?
    let category: String
    let modelName: String
    let placeholderIcon: String
    let prompt: String
    let isFeatured: Bool
    let isAvailable: Bool
    let requiresPro: Bool
    let defaultSettings: [String: Any]?
    let createdAt: Date

    // MARK: - CodingKeys for snake_case mapping

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case shortDescription = "short_description"
        case thumbnailURL = "thumbnail_url"
        case category
        case modelName = "model_name"
        case placeholderIcon = "placeholder_icon"
        case prompt
        case isFeatured = "is_featured"
        case isAvailable = "is_available"
        case requiresPro = "requires_pro"
        case defaultSettings = "default_settings"
        case createdAt = "created_at"
    }

    // MARK: - Custom Decoding

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        shortDescription = try container.decodeIfPresent(String.self, forKey: .shortDescription)

        // Decode thumbnail_url as URL
        if let urlString = try container.decodeIfPresent(String.self, forKey: .thumbnailURL),
           !urlString.isEmpty {
            thumbnailURL = URL(string: urlString)
        } else {
            thumbnailURL = nil
        }

        category = try container.decode(String.self, forKey: .category)
        modelName = try container.decode(String.self, forKey: .modelName)
        placeholderIcon = try container.decode(String.self, forKey: .placeholderIcon)
        prompt = try container.decode(String.self, forKey: .prompt)
        isFeatured = try container.decode(Bool.self, forKey: .isFeatured)
        isAvailable = try container.decode(Bool.self, forKey: .isAvailable)
        requiresPro = try container.decode(Bool.self, forKey: .requiresPro)

        // Decode default_settings JSONB field
        if let settingsData = try container.decodeIfPresent([String: AnyCodable].self, forKey: .defaultSettings) {
            defaultSettings = settingsData.mapValues { $0.value }
        } else {
            defaultSettings = nil
        }

        // Decode created_at (handled by custom date decoder in ThemeService)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    // MARK: - Custom Encoding

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(shortDescription, forKey: .shortDescription)
        try container.encodeIfPresent(thumbnailURL?.absoluteString, forKey: .thumbnailURL)
        try container.encode(category, forKey: .category)
        try container.encode(modelName, forKey: .modelName)
        try container.encode(placeholderIcon, forKey: .placeholderIcon)
        try container.encode(prompt, forKey: .prompt)
        try container.encode(isFeatured, forKey: .isFeatured)
        try container.encode(isAvailable, forKey: .isAvailable)
        try container.encode(requiresPro, forKey: .requiresPro)

        if let settings = defaultSettings {
            let codableSettings = settings.mapValues { AnyCodable($0) }
            try container.encode(codableSettings, forKey: .defaultSettings)
        }

        try container.encode(createdAt, forKey: .createdAt)
    }

    // MARK: - Convenience Initializer for Testing

    init(
        id: String = UUID().uuidString,
        name: String,
        description: String? = nil,
        shortDescription: String? = nil,
        thumbnailURL: URL? = nil,
        category: String,
        modelName: String,
        placeholderIcon: String,
        prompt: String,
        isFeatured: Bool = false,
        isAvailable: Bool = true,
        requiresPro: Bool = false,
        defaultSettings: [String: Any]? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.shortDescription = shortDescription
        self.thumbnailURL = thumbnailURL
        self.category = category
        self.modelName = modelName
        self.placeholderIcon = placeholderIcon
        self.prompt = prompt
        self.isFeatured = isFeatured
        self.isAvailable = isAvailable
        self.requiresPro = requiresPro
        self.defaultSettings = defaultSettings
        self.createdAt = createdAt
    }

    // MARK: - Hashable Conformance

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(category)
        hasher.combine(prompt)
        // Skip defaultSettings as it contains Any which is not hashable
        // ID should be unique enough for hashing purposes
    }

    static func == (lhs: Theme, rhs: Theme) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.prompt == rhs.prompt
    }
}

// MARK: - AnyCodable Helper for JSONB Decoding

/// Helper to decode JSONB fields with mixed types
private struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyCodable value cannot be decoded"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            let codableArray = array.map { AnyCodable($0) }
            try container.encode(codableArray)
        case let dictionary as [String: Any]:
            let codableDict = dictionary.mapValues { AnyCodable($0) }
            try container.encode(codableDict)
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "AnyCodable value cannot be encoded"
                )
            )
        }
    }
}

// MARK: - Static Mock Data for Previews

#if DEBUG
extension Theme {
    /// Mock themes for SwiftUI previews and testing
    static let mockThemes: [Theme] = [
        Theme(
            name: "Remove Object from Image",
            description: "Remove unwanted objects from your photos",
            category: "main_tools",
            modelName: "lama-cleaner",
            placeholderIcon: "eraser.fill",
            prompt: "Remove the selected object naturally",
            isFeatured: true
        ),
        Theme(
            name: "Christmas Magic Edit",
            description: "Add magical christmas elements",
            category: "seasonal",
            modelName: "nano-banana/edit",
            placeholderIcon: "gift.fill",
            prompt: "Add magical christmas elements to this image",
            isFeatured: true
        ),
        Theme(
            name: "LinkedIn Headshot",
            description: "Professional headshots for LinkedIn",
            category: "pro_looks",
            modelName: "professional-headshot",
            placeholderIcon: "person.crop.square",
            prompt: "Transform into a professional LinkedIn headshot",
            isFeatured: false
        )
    ]
}
#endif
