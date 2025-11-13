//
//  SubmitJobResponse.swift
//  BananaUniverse
//
//  Created by AI Assistant on 13.11.2025.
//

import Foundation

struct SubmitJobResponse: Decodable {
    let success: Bool
    let jobId: String
    let status: String
    let estimatedTime: Int?  // Estimated processing time in seconds (webhook architecture)
    let creditInfo: CreditInfo?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case success
        case jobId = "job_id"
        case status
        case estimatedTime = "estimated_time"
        case creditInfo = "quota_info"  // Backend still returns "quota_info" key
        case error
    }
}
