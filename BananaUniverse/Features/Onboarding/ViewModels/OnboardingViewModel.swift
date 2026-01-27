//
//  OnboardingViewModel.swift
//  BananaUniverse
//
//  Created by Claude on 2025-11-22.
//  Purpose: State management for onboarding flow
//

import SwiftUI

@MainActor
class OnboardingViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var currentScreen: OnboardingScreen = .welcome
    @Published var isPresentingOnboarding = false

    // MARK: - Types

    enum OnboardingScreen: Int, CaseIterable {
        case welcome = 0
        case howItWorks = 1
        case credits = 2

        var title: String {
            switch self {
            case .welcome: return "Welcome to Flario"
            case .howItWorks: return "How It Works"
            case .credits: return "Start with 10 Free Credits"
            }
        }
    }

    // MARK: - Computed Properties

    var isFirstScreen: Bool {
        currentScreen.rawValue == 0
    }

    var isLastScreen: Bool {
        currentScreen.rawValue == OnboardingScreen.allCases.count - 1
    }

    var progressPercentage: Double {
        Double(currentScreen.rawValue + 1) / Double(OnboardingScreen.allCases.count)
    }

    // MARK: - Actions

    func nextScreen() {
        guard !isLastScreen else { return }

        withAnimation(DesignTokens.Animation.smooth) {
            currentScreen = OnboardingScreen(rawValue: currentScreen.rawValue + 1) ?? .welcome
        }

        DesignTokens.Haptics.impact(.light)
    }

    func previousScreen() {
        guard !isFirstScreen else { return }

        withAnimation(DesignTokens.Animation.smooth) {
            currentScreen = OnboardingScreen(rawValue: currentScreen.rawValue - 1) ?? .welcome
        }

        DesignTokens.Haptics.impact(.light)
    }

    func complete() {
        DesignTokens.Haptics.success()

        // Note: hasSeenOnboarding flag already set in OnboardingView.onAppear
        // No need to set it again here

        // Just dismiss the sheet
        isPresentingOnboarding = false
    }

    func skip() {
        DesignTokens.Haptics.impact(.light)

        // Note: hasSeenOnboarding flag already set in OnboardingView.onAppear
        // User will never see onboarding again (skip or complete doesn't matter)

        // Just dismiss the sheet
        isPresentingOnboarding = false
    }
}
