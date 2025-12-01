//
//  OnboardingView.swift
//  BananaUniverse
//
//  Created by Claude on 2025-11-22.
//  Purpose: Main onboarding container with TabView paging
//

import SwiftUI

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @Environment(\.colorScheme) var colorScheme

    let onComplete: () -> Void

    var body: some View {
        ZStack {
            // Background
            DesignTokens.Background.primary(colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button (only show if not on last screen)
                if !viewModel.isLastScreen {
                    HStack {
                        Spacer()
                        Button("Skip") {
                            viewModel.skip()
                            onComplete()
                        }
                        .font(DesignTokens.Typography.callout)
                        .foregroundColor(DesignTokens.Text.tertiary(colorScheme))
                    }
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.top, DesignTokens.Spacing.md)
                }

                // Content (TabView with paging)
                TabView(selection: $viewModel.currentScreen) {
                    OnboardingScreen1()
                        .tag(OnboardingViewModel.OnboardingScreen.welcome)

                    OnboardingScreen2()
                        .tag(OnboardingViewModel.OnboardingScreen.howItWorks)

                    OnboardingScreen3(onComplete: {
                        viewModel.nextScreen()
                    })
                    .tag(OnboardingViewModel.OnboardingScreen.credits)
                    
                    OnboardingScreen4(onComplete: {
                        viewModel.complete()
                        onComplete()
                    })
                    .tag(OnboardingViewModel.OnboardingScreen.dataPolicy)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Progress dots
                OnboardingProgressDots(
                    currentIndex: viewModel.currentScreen.rawValue,
                    totalCount: OnboardingViewModel.OnboardingScreen.allCases.count
                )
                .padding(.bottom, DesignTokens.Spacing.md)

                // Navigation buttons
                HStack(spacing: DesignTokens.Spacing.md) {
                    // Back button (only show if not on first screen)
                    if !viewModel.isFirstScreen {
                        SecondaryButton(
                            title: "Back",
                            icon: "chevron.left",
                            accentColor: DesignTokens.Brand.secondary,
                            action: { viewModel.previousScreen() }
                        )
                        .frame(maxWidth: 100)
                    }

                    Spacer()

                    // Next button (only if not last screen)
                    if !viewModel.isLastScreen {
                        PrimaryButton(
                            title: "Next",
                            icon: "arrow.right",
                            accentColor: DesignTokens.Brand.secondary,
                            action: { viewModel.nextScreen() }
                        )
                        .frame(maxWidth: 100)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.bottom, DesignTokens.Spacing.lg)
            }
        }
        .environmentObject(viewModel)
        .onAppear {
            // ✅ CRITICAL: Set flag IMMEDIATELY when onboarding appears
            // This ensures user NEVER sees onboarding again (skip or complete)
            UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")

            #if DEBUG
            print("✅ [ONBOARDING] hasSeenOnboarding flag set to true")
            #endif
        }
    }
}

// MARK: - Preview
#if DEBUG
#Preview {
    OnboardingView(onComplete: {
        print("Onboarding completed")
    })
}
#endif
