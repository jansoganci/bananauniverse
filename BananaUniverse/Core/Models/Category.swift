//
//  Category.swift
//  BananaUniverse
//
//  Created by AI Assistant on 2025.
//  Category data model - database-driven category management
//

import Foundation

/// Category represents a grouping of themes/tools
/// This model is fetched from Supabase database and supports remote content management
struct Category: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let displayOrder: Int
    let iconURL: String?
    let thumbnailURL: String?
    let isActive: Bool
    let createdAt: Date?
    let updatedAt: Date?

    // MARK: - CodingKeys for snake_case mapping

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case displayOrder = "display_order"
        case iconURL = "icon_url"
        case thumbnailURL = "thumbnail_url"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // MARK: - Custom Decoding

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        displayOrder = try container.decode(Int.self, forKey: .displayOrder)
        iconURL = try container.decodeIfPresent(String.self, forKey: .iconURL)
        thumbnailURL = try container.decodeIfPresent(String.self, forKey: .thumbnailURL)
        isActive = try container.decode(Bool.self, forKey: .isActive)

        // Decode dates (handled by custom date decoder in CategoryService)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    // MARK: - Custom Encoding

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(displayOrder, forKey: .displayOrder)
        try container.encodeIfPresent(iconURL, forKey: .iconURL)
        try container.encodeIfPresent(thumbnailURL, forKey: .thumbnailURL)
        try container.encode(isActive, forKey: .isActive)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }

    // MARK: - Initializer

    init(
        id: String,
        name: String,
        displayOrder: Int = 0,
        iconURL: String? = nil,
        thumbnailURL: String? = nil,
        isActive: Bool = true,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.displayOrder = displayOrder
        self.iconURL = iconURL
        self.thumbnailURL = thumbnailURL
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Mock Data for Previews

#if DEBUG
extension Category {
    static let mockCategories: [Category] = [
        Category(id: "main_tools", name: "Photo Editor", displayOrder: 1),
        Category(id: "seasonal", name: "Seasonal", displayOrder: 2),
        Category(id: "pro_looks", name: "Pro Photos", displayOrder: 3),
        Category(id: "restoration", name: "Enhancer", displayOrder: 4)
    ]
}
#endif

