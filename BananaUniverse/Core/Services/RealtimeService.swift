//
//  RealtimeService.swift
//  BananaUniverse
//
//  Created by AI Assistant on 2025-11-21.
//  Purpose: Manage Supabase Realtime subscriptions for job status updates
//

import Foundation
import Supabase

/// Manages Supabase Realtime subscriptions for live job updates
@MainActor
class RealtimeService: ObservableObject {
    static let shared = RealtimeService()

    private let supabaseClient: SupabaseClient

    // Connection state
    @Published var isConnected = false
    @Published var connectionError: String?

    // Active subscriptions
    private var activeChannels: [String: RealtimeChannelV2] = [:]

    private init() {
        self.supabaseClient = SupabaseService.shared.client
        setupConnectionMonitoring()
    }

    // MARK: - Connection Monitoring

    private func setupConnectionMonitoring() {
        // Monitor Realtime connection state
        Task {
            await monitorConnection()
        }
    }

    private func monitorConnection() async {
        // Simple connection check
        isConnected = true

        #if DEBUG
        print("🔌 [Realtime] Service initialized")
        #endif
    }

    // MARK: - Job Status Subscription

    /// Subscribe to job status updates for a specific job
    /// - Parameter jobId: The fal_job_id (TEXT) returned from backend as job_id
    /// - Returns: AsyncStream of GetResultResponse updates
    func subscribeToJobUpdates(jobId: String) -> AsyncStream<GetResultResponse> {
        #if DEBUG
        print("🎧 [Realtime] Subscribing to job: \(jobId)")
        #endif

        return AsyncStream { continuation in
            Task {
                // CRITICAL: Set device_id session variable for RLS before subscribing
                // This allows RLS policies to filter job_results by device_id
                let userState = HybridAuthService.shared.userState

                if let deviceId = userState.deviceId {
                    do {
                        // Set session variable for anonymous users
                        _ = try await supabaseClient.rpc(
                            "set_device_id_session",
                            params: ["p_device_id": AnyJSON.string(deviceId)]
                        ).execute().value

                        #if DEBUG
                        print("🔐 [Realtime] Set device_id session variable: \(deviceId)")
                        #endif
                    } catch {
                        #if DEBUG
                        print("⚠️ [Realtime] Failed to set device_id session: \(error)")
                        #endif
                    }
                }

                // Create unique channel for this job
                let channelName = "job:\(jobId)"

                // Remove existing channel if any
                if let existing = activeChannels[channelName] {
                    await existing.unsubscribe()
                    activeChannels.removeValue(forKey: channelName)
                }

                // Create new channel
                let channel = supabaseClient.realtimeV2.channel(channelName)

                // Store channel reference
                activeChannels[channelName] = channel

                // Subscribe to UPDATE events on job_results table
                // NOTE: jobId is the fal_job_id (TEXT), returned from backend as job_id
                let updates = channel.postgresChange(
                    UpdateAction.self,
                    schema: "public",
                    table: "job_results",
                    filter: "fal_job_id=eq.\(jobId)"
                )

                // Subscribe to the channel (RLS will now allow updates)
                await channel.subscribe()

                #if DEBUG
                print("✅ [Realtime] Subscribed to channel: \(channelName) with filter: fal_job_id=eq.\(jobId)")
                #endif

                // Handle cleanup when stream is cancelled
                continuation.onTermination = { @Sendable _ in
                    Task { @MainActor in
                        await self.unsubscribeFromJob(jobId: jobId)
                    }
                }

                // Listen for updates with timeout protection
                // Use Task.select to race between updates and timeout
                var hasReceivedUpdate = false
                
                // Create a task that listens for updates
                let updateTask = Task {
                    for await update in updates {
                        hasReceivedUpdate = true
                        await MainActor.run {
                            handleJobUpdate(action: update, continuation: continuation)
                        }
                    }
                }
                
                // Create timeout task (60 seconds)
                let timeoutTask = Task {
                    try? await Task.sleep(nanoseconds: 60_000_000_000) // 60 seconds
                    if !hasReceivedUpdate {
                        #if DEBUG
                        print("⏱️ [Realtime] Timeout reached (60s), no updates received for job: \(jobId)")
                        #endif
                        updateTask.cancel()
                    }
                }
                
                // Wait for update task to complete or timeout
                await updateTask.value
                timeoutTask.cancel()
                
                // If no updates received, start fallback polling
                if !hasReceivedUpdate {
                    #if DEBUG
                    print("🔄 [Realtime] Starting fallback polling for job: \(jobId)")
                    #endif
                    
                    // Start fallback polling
                    for await pollUpdate in pollJobStatus(jobId: jobId, maxAttempts: 30) {
                        continuation.yield(pollUpdate)
                        if pollUpdate.status == "completed" || pollUpdate.status == "failed" {
                            continuation.finish()
                            return
                        }
                    }
                }
            }
        }
    }

    // MARK: - Message Handling

    @MainActor
    private func handleJobUpdate(action: UpdateAction, continuation: AsyncStream<GetResultResponse>.Continuation) {
        #if DEBUG
        print("📨 [Realtime] Received update: \(action.record)")
        #endif

        // Extract job data from the record
        let record = action.record

        let status = record["status"]?.stringValue ?? "pending"
        let imageUrl = record["image_url"]?.stringValue
        let error = record["error"]?.stringValue
        let createdAt = record["created_at"]?.stringValue
        let completedAt = record["completed_at"]?.stringValue

        // Create response object
        let response = GetResultResponse(
            success: status == "completed",
            status: status,
            imageUrl: imageUrl,
            error: error,
            createdAt: createdAt,
            completedAt: completedAt
        )

        // Yield the update
        continuation.yield(response)

        // If job is completed or failed, finish the stream
        if status == "completed" || status == "failed" {
            #if DEBUG
            print("✅ [Realtime] Job \(status), finishing stream")
            #endif
            continuation.finish()
        }
    }

    // MARK: - Cleanup

    /// Unsubscribe from a specific job
    func unsubscribeFromJob(jobId: String) async {
        let channelName = "job:\(jobId)"

        guard let channel = activeChannels[channelName] else {
            return
        }

        await channel.unsubscribe()
        activeChannels.removeValue(forKey: channelName)

        #if DEBUG
        print("🔌 [Realtime] Unsubscribed from: \(channelName)")
        #endif
    }

    /// Unsubscribe from all active channels
    func unsubscribeAll() async {
        #if DEBUG
        print("🔌 [Realtime] Unsubscribing from all channels (\(activeChannels.count))")
        #endif

        for (_, channel) in activeChannels {
            await channel.unsubscribe()
        }

        activeChannels.removeAll()
    }

    // MARK: - Fallback Polling

    /// Poll for job status (fallback when Realtime fails)
    func pollJobStatus(jobId: String, maxAttempts: Int = 30) -> AsyncStream<GetResultResponse> {
        #if DEBUG
        print("🔄 [Realtime] Starting fallback polling for job: \(jobId)")
        #endif

        return AsyncStream { continuation in
            Task {
                var attempts = 0

                while attempts < maxAttempts {
                    do {
                        // Poll the API
                        let response = try await SupabaseService.shared.getJobResult(jobId: jobId)

                        // Yield the result
                        continuation.yield(response)

                        // Check if done
                        if response.status == "completed" || response.status == "failed" {
                            continuation.finish()
                            return
                        }

                        // Wait before next poll (5 seconds)
                        try await Task.sleep(nanoseconds: 5_000_000_000)
                        attempts += 1

                    } catch {
                        #if DEBUG
                        print("❌ [Realtime] Polling error: \(error)")
                        #endif

                        if attempts >= maxAttempts - 1 {
                            continuation.finish()
                        }
                    }
                }

                continuation.finish()
            }
        }
    }
}
