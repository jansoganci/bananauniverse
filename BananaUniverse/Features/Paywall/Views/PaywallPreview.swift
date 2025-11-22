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
            mainContent
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    closeButton
                }
                .alert(alertTitle, isPresented: $showAlert) {
                    Button("OK", role: .cancel) { dismissAlert() }
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
                    Button("Cancel", role: .cancel) { dismissRetryAlert() }
                    Button("Retry") {
                        retryAction?()
                        dismissRetryAlert()
                    }
                } message: {
                    Text(alertMessage)
                }
                .onAppear(perform: handleAppear)
        }
    }
    
    private var mainContent: some View {
        ZStack {
            PaywallBackground(animateGradient: animateGradient)
            scrollContent
        }
    }
    
    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                PaywallHeroSection()
                    .padding(.top, 20)
                    .padding(.bottom, DesignTokens.Spacing.xl)
                
                PaywallBenefitsSection()
                    .padding(.bottom, DesignTokens.Spacing.xl)
                
                productsContent
                
                PaywallCTAButton(
                    selectedProduct: selectedProduct,
                    isLoading: storeKitService.isLoading,
                    onPurchase: handlePurchase
                )
                .padding(.bottom, DesignTokens.Spacing.lg)
                
                PaywallFooterSection(
                    isLoading: storeKitService.isLoading,
                    onRestore: handleRestore
                )
                .padding(.bottom, DesignTokens.Spacing.xl)
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
        }
    }
    
    @ViewBuilder
    private var productsContent: some View {
        if storeKitService.isLoading {
            PaywallLoadingSection()
                .padding(.bottom, DesignTokens.Spacing.xl)
        } else if storeKitService.hasCreditProducts {
            productsSection
                .padding(.bottom, DesignTokens.Spacing.lg)
        } else {
            PaywallErrorSection(
                errorMessage: storeKitService.errorMessage,
                onRetry: {
                    Task {
                        await storeKitService.loadProducts()
                    }
                }
            )
            .padding(.bottom, DesignTokens.Spacing.xl)
        }
    }
    
    private var closeButton: some ToolbarContent {
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
    
    private func handleAppear() {
        Task {
            await storeKitService.loadProducts()
            if let bestValue = storeKitService.creditProducts.first(where: { $0.id == "credits_100" }) {
                selectedProduct = bestValue
                selectedProductId = bestValue.id
            } else if let firstProduct = storeKitService.creditProducts.first {
                selectedProduct = firstProduct
                selectedProductId = firstProduct.id
            }
        }
        
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: true)) {
            animateGradient.toggle()
        }
    }
    
    private func handlePurchase() {
        Task {
            guard let selectedProduct = selectedProduct else {
                showAlert(title: "No Package Selected", message: "Please select a credit package to continue.")
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
    }
    
    private func handleRestore() {
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
    }
    
    // MARK: - Products Section
    
    private var productsSection: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ForEach(sortedCreditProducts, id: \.id) { product in
                CreditProductCard(
                    product: product,
                    isSelected: selectedProductId == product.id,
                    isBestValue: product.id == "credits_100",
                    isMostPopular: product.id == "credits_25",
                    onTap: {
                        DesignTokens.Haptics.selectionChanged()
                        selectedProduct = product
                        selectedProductId = product.id
                    }
                )
            }
        }
    }
    
    private var sortedCreditProducts: [Product] {
        storeKitService.creditProducts.sorted(by: { 
            CreditAmountHelper.getAmount(from: $0.id) < CreditAmountHelper.getAmount(from: $1.id) 
        })
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
        
        let (title, message) = PaywallErrorHandler.getErrorMessage(for: error, type: .purchase)
        
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
        
        let (title, message) = PaywallErrorHandler.getErrorMessage(for: error, type: .restore)
        
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
