//
//  GetResultResponse.swift
//  BananaUniverse
//
//  Created by AI Assistant on 13.11.2025.
//

import Foundation

struct GetResultResponse: Decodable {
    let success: Bool
    let status: String?         // 'pending' | 'completed' | 'failed'
    let imageUrl: String?       // Signed URL to processed image (if completed)
    let error: String?          // Error message (if failed)
    let createdAt: String?
    let completedAt: String?

    enum CodingKeys: String, CodingKey {
        case success
        case status
        case imageUrl = "image_url"
        case error
        case createdAt = "created_at"
        case completedAt = "completed_at"
    }
}
