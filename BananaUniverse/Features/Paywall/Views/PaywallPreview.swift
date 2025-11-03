//
//  PaywallPreview.swift
//  BananaUniverse
//
//  Created by AI Assistant - Premium Redesign
//  Modern, engaging paywall with premium visual design
//

import SwiftUI
import StoreKit

struct PaywallPreview: View {
    @StateObject private var storeKitService = StoreKitService.shared
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @State private var selectedProduct: Product?
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showRetryAlert = false
    @State private var retryAction: (() -> Void)?
    @State private var animateGradient = false
    @State private var selectedProductId: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                // Premium animated background
                premiumBackground
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Hero Section
                        heroSection
                            .padding(.top, 20)
                            .padding(.bottom, DesignTokens.Spacing.xl)
                        
                        // Benefits Section
                        benefitsSection
                            .padding(.bottom, DesignTokens.Spacing.xl)
                        
                        // Products Section
                        if storeKitService.isLoading {
                            loadingSection
                                .padding(.bottom, DesignTokens.Spacing.xl)
                        } else if storeKitService.hasProducts {
                            productsSection
                                .padding(.bottom, DesignTokens.Spacing.lg)
                        } else {
                            errorSection
                                .padding(.bottom, DesignTokens.Spacing.xl)
                        }
                        
                        // CTA Button
                        ctaButton
                            .padding(.bottom, DesignTokens.Spacing.lg)
                        
                        // Footer Section
                        footerSection
                            .padding(.bottom, DesignTokens.Spacing.xl)
                    }
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        DesignTokens.Haptics.impact(.light)
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                            .symbolRenderingMode(.hierarchical)
                    }
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
                // Auto-select best value product
                Task {
                    await storeKitService.loadProducts()
                    if let yearly = storeKitService.yearlyProduct {
                        selectedProduct = yearly
                        selectedProductId = yearly.id
                    } else if let weekly = storeKitService.weeklyProduct {
                        selectedProduct = weekly
                        selectedProductId = weekly.id
                    }
                }
                
                // Start gradient animation
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: true)) {
                    animateGradient.toggle()
                }
            }
            .onReceive(HybridCreditManager.shared.$isPremiumUser) { isPremium in
                #if DEBUG
                print("🔄 PaywallPreview: Premium status changed to \(isPremium)")
                #endif
            }
        }
    }
    
    // MARK: - Premium Background
    
    private var premiumBackground: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    DesignTokens.Background.primary(colorScheme),
                    DesignTokens.Background.secondary(colorScheme),
                    DesignTokens.Background.primary(colorScheme)
                ],
                startPoint: animateGradient ? .topLeading : .bottomTrailing,
                endPoint: animateGradient ? .bottomTrailing : .topLeading
            )
            .ignoresSafeArea()
            
            // Accent gradient overlay
            LinearGradient(
                colors: [
                    DesignTokens.Gradients.premiumStart(colorScheme).opacity(0.1),
                    DesignTokens.Gradients.premiumEnd(colorScheme).opacity(0.05),
                    DesignTokens.Gradients.energeticStart(colorScheme).opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
    
    // MARK: - Hero Section
    
    private var heroSection: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // Premium Icon/Emoji
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignTokens.Gradients.premiumStart(colorScheme).opacity(0.3),
                                DesignTokens.Gradients.energeticStart(colorScheme).opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .blur(radius: 20)
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                DesignTokens.Gradients.energeticStart(colorScheme),
                                DesignTokens.Gradients.energeticEnd(colorScheme)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .padding(.bottom, DesignTokens.Spacing.sm)
            
            // Title
            Text("Unlock Unlimited AI Magic")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(DesignTokens.Text.primary(colorScheme))
                .multilineTextAlignment(.center)
                .lineLimit(3)
            
            // Subtitle with free trial emphasis
            VStack(spacing: DesignTokens.Spacing.xs) {
                Text("Start your 3-day free trial")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(DesignTokens.Gradients.energeticStart(colorScheme))
                
                Text("Cancel anytime • No commitment")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(DesignTokens.Text.secondary(colorScheme))
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
    }
    
    // MARK: - Benefits Section
    
    private var benefitsSection: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ForEach(benefits, id: \.title) { benefit in
                PremiumBenefitCard(
                    icon: benefit.icon,
                    title: benefit.title,
                    description: benefit.description
                )
            }
        }
    }
    
    private struct Benefit {
        let icon: String
        let title: String
        let description: String
    }
    
    private var benefits: [Benefit] {
        [
            Benefit(
                icon: "sparkles",
                title: "Unlimited AI Image Edits",
                description: "Process as many images as you want, no limits"
            ),
            Benefit(
                icon: "bolt.fill",
                title: "Faster Processing Priority",
                description: "Skip the queue and get results instantly"
            ),
            Benefit(
                icon: "star.fill",
                title: "Exclusive Premium Filters",
                description: "Access to advanced AI models and effects"
            )
        ]
    }
    
    // MARK: - Loading Section
    
    private var loadingSection: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(DesignTokens.Brand.accent(colorScheme))
            
            Text("Loading products...")
                .font(DesignTokens.Typography.subheadline)
                .foregroundColor(DesignTokens.Text.secondary(colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(DesignTokens.Spacing.xl)
    }
    
    // MARK: - Products Section
    
    private var productsSection: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // Weekly Product
            if let weeklyProduct = storeKitService.weeklyProduct {
                PremiumProductCard(
                    product: weeklyProduct,
                    isSelected: selectedProductId == weeklyProduct.id,
                    isBestValue: false,
                    savingsPercent: nil,
                    showTrialBadge: false,
                    onTap: {
                        DesignTokens.Haptics.selectionChanged()
                        selectedProduct = weeklyProduct
                        selectedProductId = weeklyProduct.id
                    }
                )
            }
            
            // Yearly Product (if available)
            if let yearlyProduct = storeKitService.yearlyProduct {
                PremiumProductCard(
                    product: yearlyProduct,
                    isSelected: selectedProductId == yearlyProduct.id,
                    isBestValue: true,
                    savingsPercent: 70,
                    showTrialBadge: true,
                    onTap: {
                        DesignTokens.Haptics.selectionChanged()
                        selectedProduct = yearlyProduct
                        selectedProductId = yearlyProduct.id
                    }
                )
            }
        }
    }
    
    // MARK: - Error Section
    
    private var errorSection: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(DesignTokens.Semantic.warning(colorScheme))
            
            Text("Unable to Load Products")
                .font(DesignTokens.Typography.headline)
                .foregroundColor(DesignTokens.Text.primary(colorScheme))
            
            Text(storeKitService.errorMessage ?? "Please check your internet connection and try again.")
                .font(DesignTokens.Typography.subheadline)
                .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                .multilineTextAlignment(.center)
            
            Button(action: {
                Task {
                    await storeKitService.loadProducts()
                }
            }) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry")
                }
                .font(DesignTokens.Typography.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: DesignTokens.Layout.buttonHeight)
                .background(
                    LinearGradient(
                        colors: [
                            DesignTokens.Gradients.premiumStart(colorScheme),
                            DesignTokens.Gradients.premiumEnd(colorScheme)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(DesignTokens.CornerRadius.md)
            }
            .padding(.top, DesignTokens.Spacing.sm)
        }
        .padding(DesignTokens.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                .fill(DesignTokens.Surface.secondary(colorScheme))
        )
    }
    
    // MARK: - CTA Button
    
    private var ctaButton: some View {
        Button(action: {
            Task {
                guard let selectedProduct = selectedProduct else {
                    showAlert(title: "No Product Selected", message: "Please select a subscription plan to continue.")
                    return
                }
                
                DesignTokens.Haptics.impact(.medium)
                
                do {
                    _ = try await storeKitService.purchase(selectedProduct)
                } catch {
                    DispatchQueue.main.async {
                        self.handlePurchaseError(error)
                    }
                }
            }
        }) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                if storeKitService.isLoading {
                    ProgressView()
                        .scaleEffect(0.9)
                        .tint(.white)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                }
                
                Text(ctaButtonText)
                    .font(.system(size: 18, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                Group {
                    if selectedProduct != nil && !storeKitService.isLoading {
                        LinearGradient(
                            colors: [
                                DesignTokens.Gradients.energeticStart(colorScheme),
                                DesignTokens.Gradients.energeticEnd(colorScheme)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        LinearGradient(
                            colors: [
                                DesignTokens.Gradients.premiumStart(colorScheme).opacity(0.5),
                                DesignTokens.Gradients.premiumEnd(colorScheme).opacity(0.5)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                }
            )
            .cornerRadius(DesignTokens.CornerRadius.lg)
            .shadow(
                color: selectedProduct != nil ? DesignTokens.Gradients.energeticStart(colorScheme).opacity(0.4) : Color.clear,
                radius: selectedProduct != nil ? 16 : 0,
                x: 0,
                y: 8
            )
        }
        .disabled(selectedProduct == nil || storeKitService.isLoading)
        .opacity((selectedProduct != nil && !storeKitService.isLoading) ? 1.0 : 0.6)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedProduct != nil)
        .accessibilityLabel(ctaButtonText)
        .accessibilityHint("Tap to purchase selected product")
    }
    
    private var ctaButtonText: String {
        if storeKitService.isLoading {
            return "Processing..."
        } else if selectedProduct?.id.contains("yearly") == true {
            return "Start Free Trial"
        } else {
            return "Unlock Premium"
        }
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // Restore purchases
            Button(action: {
                Task {
                    do {
                        try await storeKitService.restorePurchases()
                        DispatchQueue.main.async {
                            self.showAlert(title: "Success!", message: "Purchases restored successfully! Welcome back to Premium.")
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.handleRestoreError(error)
                        }
                    }
                }
            }) {
                HStack(spacing: DesignTokens.Spacing.sm) {
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
                .foregroundColor(DesignTokens.Text.link(colorScheme))
            }
            .disabled(storeKitService.isLoading)
            
            // Legal links
            HStack(spacing: DesignTokens.Spacing.lg) {
                Button("Terms") {
                    if let url = URL(string: Config.termsOfServiceURL) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(DesignTokens.Text.link(colorScheme))
                
                Text("•")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Text.tertiary(colorScheme))
                
                Button("Privacy") {
                    if let url = URL(string: Config.privacyPolicyURL) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(DesignTokens.Text.link(colorScheme))
            }
        }
    }
    
    // MARK: - Helper Methods
    
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
        
        retryAction = {
            Task {
                guard let selectedProduct = self.selectedProduct else { return }
                do {
                    _ = try await self.storeKitService.purchase(selectedProduct)
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
        
        retryAction = {
            Task {
                do {
                    try await self.storeKitService.restorePurchases()
                    DispatchQueue.main.async {
                        self.showAlert(title: "Success!", message: "Purchases restored successfully! Welcome back to Premium.")
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
        
        if errorDescription.contains("network") || errorDescription.contains("connection") ||
           errorDescription.contains("internet") || errorDescription.contains("timeout") {
            return ("We Couldn't Connect", "Network connection lost. Please check your internet connection and try again.")
        }
        
        if errorDescription.contains("storekit") || errorDescription.contains("payment") ||
           errorDescription.contains("purchase") || errorDescription.contains("apple id") {
            return ("Payment Issue", "Payment could not be processed. Please check your Apple ID or try again later.")
        }
        
        if type == .restore && (errorDescription.contains("restore") || errorDescription.contains("subscription")) {
            return ("No Active Subscriptions", "Restore failed. You may not have any active subscriptions to restore.")
        }
        
        return ("Something Went Wrong", "We encountered an unexpected issue. Please try again.")
    }
}

// MARK: - Premium Benefit Card Component

struct PremiumBenefitCard: View {
    let icon: String
    let title: String
    let description: String
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignTokens.Gradients.premiumStart(colorScheme).opacity(0.2),
                                DesignTokens.Gradients.energeticStart(colorScheme).opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                DesignTokens.Gradients.premiumStart(colorScheme),
                                DesignTokens.Gradients.energeticStart(colorScheme)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            // Text content
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(DesignTokens.Text.primary(colorScheme))
                
                Text(description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                .fill(DesignTokens.Surface.secondary(colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    DesignTokens.Gradients.premiumStart(colorScheme).opacity(0.2),
                                    Color.clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(
            color: DesignTokens.ShadowColors.default(colorScheme),
            radius: 4,
            x: 0,
            y: 2
        )
    }
}

// MARK: - Premium Product Card Component

struct PremiumProductCard: View {
    let product: Product
    let isSelected: Bool
    let isBestValue: Bool
    let savingsPercent: Int?
    let showTrialBadge: Bool
    let onTap: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: {
            onTap()
        }) {
            VStack(spacing: 0) {
                // Best Value Badge
                if isBestValue {
                    HStack {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                        Text("BEST VALUE")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(
                        LinearGradient(
                            colors: [
                                DesignTokens.Gradients.energeticStart(colorScheme),
                                DesignTokens.Gradients.energeticEnd(colorScheme)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(DesignTokens.CornerRadius.xs, corners: [.topLeft, .topRight])
                }
                
                VStack(spacing: DesignTokens.Spacing.md) {
                    // Trial Badge
                    if showTrialBadge {
                        HStack(spacing: DesignTokens.Spacing.xs) {
                            Image(systemName: "gift.fill")
                                .font(.system(size: 12))
                            Text("3-Day Free Trial")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(DesignTokens.Semantic.success(colorScheme))
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .padding(.vertical, DesignTokens.Spacing.xs)
                        .background(
                            DesignTokens.Semantic.success(colorScheme).opacity(0.1)
                        )
                        .cornerRadius(DesignTokens.CornerRadius.sm)
                    }
                    
                    // Product info
                    HStack {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text(product.displayName)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(DesignTokens.Text.primary(colorScheme))
                            
                            if let savings = savingsPercent {
                                Text("Save \(savings)%")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(DesignTokens.Semantic.success(colorScheme))
                            }
                            
                            Text(product.description)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                                .lineLimit(2)
                        }
                        
                        Spacer()
                        
                        // Price
                        VStack(alignment: .trailing, spacing: DesignTokens.Spacing.xs) {
                            Text(product.displayPrice)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(DesignTokens.Text.primary(colorScheme))
                            
                            if product.id.contains("yearly") {
                                Text("per year")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(DesignTokens.Text.tertiary(colorScheme))
                            }
                        }
                    }
                    
                    // Selection indicator
                    if isSelected {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(DesignTokens.Gradients.energeticStart(colorScheme))
                            Text("Selected")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(DesignTokens.Gradients.energeticStart(colorScheme))
                        }
                        .padding(.top, DesignTokens.Spacing.xs)
                    }
                }
                .padding(DesignTokens.Spacing.lg)
            }
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                    .fill(DesignTokens.Surface.primary(colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                            .stroke(
                                isSelected
                                    ? LinearGradient(
                                        colors: [
                                            DesignTokens.Gradients.energeticStart(colorScheme),
                                            DesignTokens.Gradients.energeticEnd(colorScheme)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                    : LinearGradient(
                                        colors: [DesignTokens.Special.borderDefault(colorScheme)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                lineWidth: isSelected ? 3 : 1
                            )
                    )
            )
            .shadow(
                color: isSelected
                    ? DesignTokens.Gradients.energeticStart(colorScheme).opacity(0.3)
                    : DesignTokens.ShadowColors.default(colorScheme),
                radius: isSelected ? 12 : 4,
                x: 0,
                y: isSelected ? 6 : 2
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Helper Extension for Corner Radius

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Error Type

private enum ErrorType {
    case purchase
    case restore
}

// MARK: - Preview

#Preview("iPhone 14 Pro Max") {
    PaywallPreview()
        .environmentObject(ThemeManager())
}

#Preview("iPhone SE") {
    PaywallPreview()
        .environmentObject(ThemeManager())
}

#Preview("Dark Mode") {
    PaywallPreview()
        .environmentObject(ThemeManager())
        .preferredColorScheme(.dark)
}
