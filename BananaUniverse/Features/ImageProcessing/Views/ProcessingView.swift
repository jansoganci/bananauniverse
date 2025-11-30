//
//  ProcessingView.swift
//  BananaUniverse
//
//  Created by AI Assistant on 2025-11-21.
//  Purpose: Loading screen shown while AI processes the image
//

import SwiftUI

struct ProcessingView: View {
    let jobId: String
    let theme: Theme
    let onComplete: (String) -> Void  // Called with image URL when done
    let onError: (String) -> Void      // Called with error message

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var progress: Double = 0.0
    @State private var statusMessage: String = "Starting generation..."
    @State private var isCompleted: Bool = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var progressAnimationTask: Task<Void, Never>?
    @State private var hasHandledCompletion: Bool = false  // Guard against duplicate handlers

    var body: some View {
        ZStack {
            // Background
            DesignTokens.Background.primary(colorScheme)
                .ignoresSafeArea()

            VStack(spacing: DesignTokens.Spacing.xl) {
                // Close button
                HStack {
                    Spacer()
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(DesignTokens.Text.secondary(colorScheme))
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)

                Spacer()

                // Animated logo/icon
                ZStack {
                    Circle()
                        .fill(DesignTokens.Brand.primary(colorScheme).opacity(0.1))
                        .frame(width: 120, height: 120)
                        .scaleEffect(pulseScale)
                        .animation(
                            .easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true),
                            value: pulseScale
                        )

                    Image(systemName: "sparkles")
                        .font(.system(size: 50))
                        .foregroundStyle(DesignTokens.Brand.primary(colorScheme))
                }
                .onAppear {
                    pulseScale = 1.2
                }

                // Theme name
                Text(theme.name)
                    .font(DesignTokens.Typography.title2)
                    .foregroundStyle(DesignTokens.Text.primary(colorScheme))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignTokens.Spacing.lg)

                // Status message
                Text(statusMessage)
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(DesignTokens.Text.secondary(colorScheme))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignTokens.Spacing.lg)

                // Progress bar
                VStack(spacing: DesignTokens.Spacing.sm) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                                .fill(DesignTokens.Background.secondary(colorScheme))
                                .frame(height: 8)

                            // Progress
                            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                                .fill(DesignTokens.Brand.primary(colorScheme))
                                .frame(width: geometry.size.width * progress, height: 8)
                                .animation(.linear(duration: 0.3), value: progress)
                        }
                    }
                    .frame(height: 8)

                    // Progress percentage
                    Text("\(Int(progress * 100))%")
                        .font(DesignTokens.Typography.caption1)
                        .foregroundStyle(DesignTokens.Text.tertiary(colorScheme))
                }
                .padding(.horizontal, DesignTokens.Spacing.xl)

                // Fun facts or tips
                VStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "lightbulb.fill")
                        .font(.title3)
                        .foregroundStyle(DesignTokens.Semantic.warning(colorScheme))

                    Text("AI is working its magic...")
                        .font(DesignTokens.Typography.caption2)
                        .foregroundStyle(DesignTokens.Text.tertiary(colorScheme))
                }
                .padding(.top, DesignTokens.Spacing.lg)

                Spacer()
            }
            .padding(.top, DesignTokens.Spacing.lg)
        }
        .task {
            // Start progress animation (visual feedback while waiting)
            startProgressAnimation()
            
            // Subscribe to job updates
            await subscribeToJobUpdates()
        }
        .onDisappear {
            // Cancel progress animation when view disappears
            progressAnimationTask?.cancel()
        }
    }

    // MARK: - Realtime Subscription

    private func subscribeToJobUpdates() async {
        #if DEBUG
        print("🎬 [ProcessingView] Starting Realtime subscription for job: \(jobId)")
        #endif

        // Get the AsyncStream from SupabaseService
        let stream = SupabaseService.shared.subscribeToJobUpdates(jobId: jobId)

        // Listen for updates with overall timeout (5 minutes max)
        let overallTimeout = Task {
            try? await Task.sleep(nanoseconds: 300_000_000_000) // 5 minutes

            // Check if already handled before firing timeout
            await MainActor.run {
                if !hasHandledCompletion {
                    #if DEBUG
                    print("⏱️ [ProcessingView] Overall timeout reached (5min) for job: \(jobId)")
                    #endif
                    hasHandledCompletion = true
                    onError("Processing timed out. Please check your connection and try again.")
                } else {
                    #if DEBUG
                    print("⚠️ [ProcessingView] Timeout fired but already handled")
                    #endif
                }
            }
        }

        // Listen for updates
        for await update in stream {
            #if DEBUG
            print("📨 [ProcessingView] Received update: \(update.status)")
            #endif

            // Update UI based on status
            await MainActor.run {
                updateUI(with: update)
            }

            // Handle completion
            if update.status == "completed" {
                if let imageUrl = update.imageUrl {
                    await MainActor.run {
                        statusMessage = "Complete!"
                        progress = 1.0
                        isCompleted = true
                    }

                    // Wait a moment to show completion
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s

                    // Guard against duplicate completion
                    await MainActor.run {
                        if !hasHandledCompletion {
                            hasHandledCompletion = true
                            overallTimeout.cancel() // Cancel timeout immediately
                            onComplete(imageUrl)
                        } else {
                            #if DEBUG
                            print("⚠️ [ProcessingView] Duplicate completion ignored")
                            #endif
                        }
                    }
                }
                return // Exit function
            } else if update.status == "failed" {
                await MainActor.run {
                    statusMessage = "Failed"
                    progress = 0.0
                }

                let errorMessage = update.error ?? "Generation failed"

                // Guard against duplicate error
                await MainActor.run {
                    if !hasHandledCompletion {
                        hasHandledCompletion = true
                        overallTimeout.cancel() // Cancel timeout immediately
                        onError(errorMessage)
                    } else {
                        #if DEBUG
                        print("⚠️ [ProcessingView] Duplicate error ignored")
                        #endif
                    }
                }
                return // Exit function
            }
        }

        // If stream ends without completion, cancel timeout
        overallTimeout.cancel()
    }

    // MARK: - Progress Animation

    private func startProgressAnimation() {
        progressAnimationTask?.cancel()
        
        progressAnimationTask = Task {
            var currentProgress: Double = 0.0
            let startTime = Date()
            let fastPhaseDuration: TimeInterval = 5.0 // 5 seconds fast phase
            let fastPhaseTarget: Double = 0.6 // Target 60% quickly
            
            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(startTime)
                
                if elapsed < fastPhaseDuration {
                    // PHASE 1: Fast Progress (0% -> 60% in 5 seconds)
                    let fastProgress = (elapsed / fastPhaseDuration) * fastPhaseTarget
                    currentProgress = min(fastProgress, fastPhaseTarget)
                    
                    await MainActor.run {
                        // Only update if we haven't received a better real update
                        if progress < fastPhaseTarget {
                            withAnimation(.linear(duration: 0.1)) {
                                progress = currentProgress
                            }
                        }
                    }
                    
                    // Update every 0.1s for smoothness
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    
                } else {
                    // PHASE 2: Slow Progress (60% -> 95%)
                    // Slow down significantly to show work is happening but taking time
                    let slowPhaseElapsed = elapsed - fastPhaseDuration
                    // Target 95% over next 60 seconds
                    let slowProgress = fastPhaseTarget + (slowPhaseElapsed / 60.0) * 0.35 
                    currentProgress = min(slowProgress, 0.95) // Cap at 95%
                    
                    await MainActor.run {
                        if progress < 0.95 {
                            withAnimation(.linear(duration: 1.0)) {
                                progress = currentProgress
                            }
                        }
                    }
                    
                    // Update every 1s
                    try? await Task.sleep(nanoseconds: 1_000_000_000) 
                }
            }
        }
    }

    // MARK: - UI Updates

    @MainActor
    private func updateUI(with response: GetResultResponse) {
        switch response.status {
        case "pending":
            // Jump to 60% if behind (show activity)
            if progress < 0.6 {
                withAnimation(.easeOut(duration: 0.3)) {
                    progress = 0.6
                }
            }
            statusMessage = "Queued..."
            
        case "processing":
            // Ensure we are at least at 60%
            if progress < 0.6 {
                withAnimation(.easeOut(duration: 0.3)) {
                    progress = 0.6
                }
            }
            statusMessage = "Creating your masterpiece..."
            
        case "completed":
            // Cancel fake progress and finish
            progressAnimationTask?.cancel()
            withAnimation(.easeOut(duration: 0.5)) {
                progress = 1.0
            }
            statusMessage = "Complete!"
            
        case "failed":
            progressAnimationTask?.cancel()
            statusMessage = "Something went wrong"
            progress = 0.0
            
        default:
            statusMessage = "Processing..."
        }
    }
}

#Preview {
    ProcessingView(
        jobId: "test-job-123",
        theme: Theme(
            id: "1",
            name: "Christmas Magic",
            description: "Add festive holiday magic",
            thumbnailURL: nil,
            category: "seasonal",
            modelName: "fal-ai/flux-lora",
            placeholderIcon: "sparkles",
            prompt: "christmas theme",
            isFeatured: false,
            isAvailable: true,
            requiresPro: false,
            defaultSettings: nil,
            createdAt: Date()
        ),
        onComplete: { imageUrl in
            print("Completed with URL: \(imageUrl)")
        },
        onError: { error in
            print("Error: \(error)")
        }
    )
}
