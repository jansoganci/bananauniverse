//
//  PreviewPaywallView.swift
//  BananaUniverse
//
//  Created by AI Assistant on 14.10.2025.
//  Preview paywall for App Store submission
//

import SwiftUI
import StoreKit

struct PreviewPaywallView: View {
    @StateObject private var storeKitService = StoreKitService.shared
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedProduct: Product?
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showRetryAlert = false
    @State private var retryAction: (() -> Void)?
    @State private var showAI_Disclosure = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                backgroundGradient
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Header section
                        headerSection
                        
                        // Benefits section
                        benefitsSection
                        
                        // Products section
                        if storeKitService.isLoading {
                            loadingSection
                        } else if storeKitService.hasCreditProducts {
                            productsSection
                        } else {
                            errorSection
                        }
                        
                        // CTA button
                        ctaButton
                        
                        // Footer links
                        footerSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                }
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK", role: .cancel) {
                    dismissAlert()
                }
            } message: {
                Text(alertMessage)
            }
            .alert("Success!", isPresented: $storeKitService.shouldShowSuccessAlert) {
                Button("OK", role: .cancel) {
                    storeKitService.dismissSuccessAlert()
                    // REMOVED AUTO-DISMISS - Let user manually close paywall
                }
            } message: {
                Text(storeKitService.successAlertMessage)
            }
            .alert("Retry Action", isPresented: $showRetryAlert) {
                Button("Cancel", role: .cancel) {
                    dismissRetryAlert()
                }
                Button("Retry") {
                    retryAction?()
                    dismissRetryAlert()
                }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                Task {
                    await storeKitService.loadProducts()
                }
            }
            .sheet(isPresented: $showAI_Disclosure) {
                AI_Disclosure_View()
                    .environmentObject(themeManager)
            }
        }
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                DesignTokens.Background.primary(themeManager.resolvedColorScheme),
                DesignTokens.Background.secondary(themeManager.resolvedColorScheme)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Title
            Text("Get More Credits")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                .multilineTextAlignment(.center)

            // Subtitle
            Text("Keep creating amazing photos")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Benefits Section
    
    private var benefitsSection: some View {
        VStack(spacing: 20) {
            // Benefit 1
                            PreviewPaywallBenefitRow(
                icon: "wand.and.stars",
                title: "🎭 Boring → Viral",
                description: "One tap away"
            )
            .accessibilityLabel("Transform boring photos to viral content. One tap away")
            .accessibilityHint("Feature benefit")

            // Benefit 2
                            PreviewPaywallBenefitRow(
                icon: "camera.fill",
                title: "📸 Your best look",
                description: "Every single time"
            )
            .accessibilityLabel("Your best look. Every single time")
            .accessibilityHint("Feature benefit")

            // Benefit 3
                            PreviewPaywallBenefitRow(
                icon: "bolt.fill",
                title: "⚡ Instant magic",
                description: "Zero effort"
            )
            .accessibilityLabel("Instant magic. Zero effort")
            .accessibilityHint("Feature benefit")
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignTokens.Surface.primary(themeManager.resolvedColorScheme).opacity(0.8))
                .shadow(color: DesignTokens.ShadowColors.default(themeManager.resolvedColorScheme), radius: 10, x: 0, y: 4)
        )
    }
    
    // MARK: - Loading Section
    
    private var loadingSection: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(DesignTokens.Brand.primary(themeManager.resolvedColorScheme))
            
            Text("Loading products...")
                .font(.subheadline)
                .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
        }
        .padding(DesignTokens.Spacing.xl)
    }
    
    // MARK: - Products Section
    
    private var productsSection: some View {
        VStack(spacing: 16) {
            // Credit Products
            ForEach(Array(storeKitService.creditProducts.enumerated()), id: \.element.id) { index, product in
                let isBestValue = product.id == "credits_100"
                let isMostPopular = product.id == "credits_25"
                CreditProductCard(
                    product: product,
                    isSelected: selectedProduct?.id == product.id,
                    isBestValue: isBestValue,
                    isMostPopular: isMostPopular
                ) {
                    selectedProduct = product
                }
            }
        }
    }
    
    // MARK: - Error Section
    
    private var errorSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(DesignTokens.Semantic.warning(themeManager.resolvedColorScheme))
            
            Text("Unable to Load Products")
                .font(.headline)
                .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
            
            Text(storeKitService.errorMessage ?? "Please check your internet connection and try again.")
                .font(.subheadline)
                .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                Task {
                    await storeKitService.loadProducts()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(DesignTokens.Spacing.xl)
    }
    
    // MARK: - CTA Button
    
    private var ctaButton: some View {
        Button(action: {
            Task {
                guard let selectedProduct = selectedProduct else {
                    showAlert(title: "No Product Selected", message: "Please select a credit package to continue.")
                    return
                }
                
                do {
                    // Purchase will be handled by StoreKitService with proper transaction verification
                    // Success alert will be shown by StoreKitService only after verified transaction
                    _ = try await storeKitService.purchase(selectedProduct)
                    // No immediate success alert - wait for transaction listener
                } catch {
                    DispatchQueue.main.async {
                        self.handlePurchaseError(error)
                    }
                }
            }
        }) {
            HStack(spacing: 12) {
                if storeKitService.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                }

                Text("Continue Creating")
                    .font(.system(size: 18, weight: .bold))

                if !storeKitService.isLoading {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundColor(DesignTokens.Text.onBrand(themeManager.resolvedColorScheme))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [
                        DesignTokens.Gradients.primaryStart(themeManager.resolvedColorScheme),
                        DesignTokens.Gradients.primaryEnd(themeManager.resolvedColorScheme)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(DesignTokens.CornerRadius.lg)
            .shadow(color: DesignTokens.ShadowColors.primary(themeManager.resolvedColorScheme), radius: 12, x: 0, y: 6)
        }
        .disabled(selectedProduct == nil || storeKitService.isLoading)
        .opacity((selectedProduct != nil && !storeKitService.isLoading) ? 1.0 : 0.6)
        .accessibilityLabel("Buy Credits")
        .accessibilityHint("Tap to purchase selected product")
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        VStack(spacing: 16) {
            // Restore purchases button
            Button(action: {
                Task {
                    do {
                        try await storeKitService.restorePurchases()
                        DispatchQueue.main.async {
                            self.showAlert(title: "Success!", message: "Purchases restored successfully!")
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.handleRestoreError(error)
                        }
                    }
                }
            }) {
                HStack(spacing: 8) {
                    if storeKitService.isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .medium))
                    }
                    Text("Restore Purchases")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(DesignTokens.Text.link(themeManager.resolvedColorScheme))
            }
            .disabled(storeKitService.isLoading)
            .accessibilityLabel("Restore Purchases")
            .accessibilityHint("Tap to restore previous purchases")
            
            // Legal links
            HStack(spacing: 24) {
                Button("Terms of Service") {
                    if let url = URL(string: Config.termsOfServiceURL) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(DesignTokens.Text.link(themeManager.resolvedColorScheme))
                .accessibilityLabel("Terms of Service")
                
                Button("Privacy Policy") {
                    if let url = URL(string: Config.privacyPolicyURL) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(DesignTokens.Text.link(themeManager.resolvedColorScheme))
                .accessibilityLabel("Privacy Policy")

                Button("AI Disclosure") {
                    showAI_Disclosure = true
                }
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(DesignTokens.Text.link(themeManager.resolvedColorScheme))
                .accessibilityLabel("AI Service Disclosure")
            }
        }
        .padding(.bottom, 20)
    }
}

// MARK: - Benefit Row Component

struct PreviewPaywallBenefitRow: View {
    let icon: String
    let title: String
    let description: String
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(DesignTokens.Brand.primary(themeManager.resolvedColorScheme))
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(DesignTokens.Brand.primary(themeManager.resolvedColorScheme).opacity(0.1))
                )
            
            // Text content
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                
                Text(description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Product Card Component

struct PreviewPaywallProductCard: View {
    let product: MockProduct
    let isSelected: Bool
    let shouldHighlight: Bool
    let shouldShowTrialBadge: Bool
    let onTap: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Trial badge at top center
                if shouldShowTrialBadge {
                    Text("3-Day Free Trial")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.vertical, DesignTokens.Spacing.xs)
                        .background(DesignTokens.Semantic.success(themeManager.resolvedColorScheme))
                        .foregroundColor(DesignTokens.Text.inverse)
                        .cornerRadius(DesignTokens.CornerRadius.xs)
                }
                
                // Header with title
                HStack {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text(product.localizedTitle)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                        
                        Text(product.localizedDescription)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                            .lineLimit(2)
                    }
                    
                    Spacer()
                }
                
                // Price and savings
                HStack {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text(product.localizedPrice)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                        
                        if let savings = product.savings {
                            Text(savings)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(DesignTokens.Semantic.error(themeManager.resolvedColorScheme))
                        }
                    }
                    
                    Spacer()
                    
                    // Selection indicator
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(DesignTokens.Brand.primary(themeManager.resolvedColorScheme))
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                    .fill(DesignTokens.Surface.primary(themeManager.resolvedColorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                            .stroke(
                                isSelected ? DesignTokens.Brand.primary(themeManager.resolvedColorScheme) : (shouldHighlight ? DesignTokens.Semantic.success(themeManager.resolvedColorScheme) : Color.clear),
                                lineWidth: isSelected ? 2 : (shouldHighlight ? 1 : 0)
                            )
                    )
            )
            .scaleEffect(shouldHighlight ? 1.02 : 1.0)
            .shadow(
                color: DesignTokens.ShadowColors.default(themeManager.resolvedColorScheme),
                radius: 8,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .animation(.easeInOut(duration: 0.2), value: shouldHighlight)
    }
}

// MARK: - StoreKit Product Card Component

struct StoreKitProductCard: View {
    let product: Product
    let isSelected: Bool
    let shouldHighlight: Bool
    let shouldShowTrialBadge: Bool
    let onTap: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Trial badge at top center
                if shouldShowTrialBadge {
                    Text("3-Day Free Trial")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.vertical, DesignTokens.Spacing.xs)
                        .background(DesignTokens.Semantic.success(themeManager.resolvedColorScheme))
                        .foregroundColor(DesignTokens.Text.inverse)
                        .cornerRadius(DesignTokens.CornerRadius.xs)
                }
                
                // Header with title
                HStack {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text(product.displayName)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                        
                        Text(product.description)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                            .lineLimit(2)
                    }
                    
                    Spacer()
                }
                
                // Price and savings
                HStack {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text(product.displayPrice)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                        
                        if product.id.contains("yearly") {
                            Text("Save 70%")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(DesignTokens.Semantic.error(themeManager.resolvedColorScheme))
                        }
                    }
                    
                    Spacer()
                    
                    // Selection indicator
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(DesignTokens.Brand.primary(themeManager.resolvedColorScheme))
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                    .fill(DesignTokens.Surface.primary(themeManager.resolvedColorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                            .stroke(
                                isSelected ? DesignTokens.Brand.primary(themeManager.resolvedColorScheme) : (shouldHighlight ? DesignTokens.Semantic.success(themeManager.resolvedColorScheme) : Color.clear),
                                lineWidth: isSelected ? 2 : (shouldHighlight ? 1 : 0)
                            )
                    )
            )
            .scaleEffect(shouldHighlight ? 1.02 : 1.0)
            .shadow(
                color: DesignTokens.ShadowColors.default(themeManager.resolvedColorScheme),
                radius: 8,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .animation(.easeInOut(duration: 0.2), value: shouldHighlight)
    }
}

// MARK: - Helper Methods

extension PreviewPaywallView {
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
    
    private func dismissAlert() {
        showAlert = false
        alertTitle = ""
        alertMessage = ""
    }
    
    private func dismissRetryAlert() {
        showRetryAlert = false
        retryAction = nil
    }
    
    private func handlePurchaseError(_ error: Error) {
        #if DEBUG
        print("❌ Purchase error: \(error.localizedDescription)")
        #endif
        
        let (title, message) = getSpecificErrorMessage(for: error, type: .purchase)
        
        // Set up retry action
        retryAction = {
            Task {
                guard let selectedProduct = self.selectedProduct else { return }
                do {
                    // Purchase will be handled by StoreKitService with proper transaction verification
                    // Success alert will be shown by StoreKitService only after verified transaction
                    _ = try await self.storeKitService.purchase(selectedProduct)
                    // No immediate success alert - wait for transaction listener
                } catch {
                    DispatchQueue.main.async {
                        self.handlePurchaseError(error)
                    }
                }
            }
        }
        
        alertTitle = title
        alertMessage = message
        showRetryAlert = true
    }
    
    private func handleRestoreError(_ error: Error) {
        #if DEBUG
        print("❌ Restore error: \(error.localizedDescription)")
        #endif
        
        let (title, message) = getSpecificErrorMessage(for: error, type: .restore)
        
        // Set up retry action
        retryAction = {
            Task {
                do {
                    try await self.storeKitService.restorePurchases()
                    DispatchQueue.main.async {
                        self.showAlert(title: "Success!", message: "Purchases restored successfully!")
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.handleRestoreError(error)
                    }
                }
            }
        }
        
        alertTitle = title
        alertMessage = message
        showRetryAlert = true
    }
    
    private func getSpecificErrorMessage(for error: Error, type: ErrorType) -> (title: String, message: String) {
        let errorDescription = error.localizedDescription.lowercased()
        
        // Check for network-related errors
        if errorDescription.contains("network") || errorDescription.contains("connection") || 
           errorDescription.contains("internet") || errorDescription.contains("timeout") {
            return ("We Couldn't Connect", "Network connection lost. Please check your internet connection and try again.")
        }
        
        // Check for StoreKit specific errors
        if errorDescription.contains("storekit") || errorDescription.contains("payment") || 
           errorDescription.contains("purchase") || errorDescription.contains("apple id") {
            return ("Payment Issue", "Payment could not be processed. Please check your Apple ID or try again later.")
        }
        
        // Check for restore specific errors
        if type == .restore && (errorDescription.contains("restore") || errorDescription.contains("subscription")) {
            return ("No Purchases Found", "Restore failed. You may not have any previous purchases to restore.")
        }
        
        // Default fallback
        return ("Something Went Wrong", "We encountered an unexpected issue. Please try again.")
    }
}

private enum ErrorType {
    case purchase
    case restore
}

// MARK: - Preview

#Preview("iPhone 14 Pro Max") {
    PreviewPaywallView()
        .environmentObject(ThemeManager())
}

#Preview("iPhone SE") {
    PreviewPaywallView()
        .environmentObject(ThemeManager())
}

#Preview("Dark Mode") {
    PreviewPaywallView()
        .environmentObject(ThemeManager())
        .preferredColorScheme(.dark)
}

