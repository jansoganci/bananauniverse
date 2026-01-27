//
//  PaywallPreview.swift
//  BananaUniverse
//
//  Created by AI Assistant - Premium Redesign
//  Modern, engaging paywall with premium visual design
//

import SwiftUI
import RevenueCat

struct PaywallPreview: View {
    @StateObject private var revenueCatService = RevenueCatService.shared
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @State private var selectedPackage: Package?
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showRetryAlert = false
    @State private var retryAction: (() -> Void)?
    @State private var animateGradient = false
    @State private var selectedPackageId: String?
    
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
                .alert("Success!", isPresented: $revenueCatService.shouldShowSuccessAlert) {
                    Button("OK", role: .cancel) {
                        revenueCatService.dismissSuccessAlert()
                    }
                } message: {
                    Text(revenueCatService.successAlertMessage)
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
                    selectedPackage: selectedPackage,
                    isLoading: revenueCatService.isLoading,
                    onPurchase: handlePurchase
                )
                .padding(.bottom, DesignTokens.Spacing.lg)
                
                PaywallFooterSection(
                    isLoading: revenueCatService.isLoading,
                    onRestore: handleRestore
                )
                .padding(.bottom, DesignTokens.Spacing.xl)
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
        }
    }
    
    @ViewBuilder
    private var productsContent: some View {
        if revenueCatService.isLoading {
            PaywallLoadingSection()
                .padding(.bottom, DesignTokens.Spacing.xl)
        } else if let offering = revenueCatService.currentOffering, !offering.availablePackages.isEmpty {
            productsSection(offering: offering)
                .padding(.bottom, DesignTokens.Spacing.lg)
        } else {
            PaywallErrorSection(
                errorMessage: revenueCatService.errorMessage,
                onRetry: {
                    Task {
                        await revenueCatService.fetchOfferings()
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
            await revenueCatService.fetchOfferings()
            if let offering = revenueCatService.currentOffering {
                if let bestValue = offering.availablePackages.first(where: { $0.storeProduct.productIdentifier.contains("100") }) {
                    selectedPackage = bestValue
                    selectedPackageId = bestValue.identifier
                } else if let firstPackage = offering.availablePackages.first {
                    selectedPackage = firstPackage
                    selectedPackageId = firstPackage.identifier
                }
            }
        }
        
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: true)) {
            animateGradient.toggle()
        }
    }
    
    private func handlePurchase() {
        Task {
            guard let selectedPackage = selectedPackage else {
                showAlert(title: "No Package Selected", message: "Please select a credit package to continue.")
                return
            }
            
            DesignTokens.Haptics.impact(.medium)
            
            do {
                _ = try await revenueCatService.purchase(selectedPackage)
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
                _ = try await revenueCatService.restorePurchases()
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
    
    private func productsSection(offering: Offering) -> some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ForEach(sortedPackages(offering), id: \.identifier) { package in
                CreditProductCard(
                    package: package,
                    isSelected: selectedPackageId == package.identifier,
                    isBestValue: package.storeProduct.productIdentifier.contains("100"),
                    isMostPopular: package.storeProduct.productIdentifier.contains("25"),
                    onTap: {
                        DesignTokens.Haptics.selectionChanged()
                        selectedPackage = package
                        selectedPackageId = package.identifier
                    }
                )
            }
        }
    }
    
    private func sortedPackages(_ offering: Offering) -> [Package] {
        offering.availablePackages.sorted(by: { 
            CreditAmountHelper.getAmount(from: $0.storeProduct.productIdentifier) < 
            CreditAmountHelper.getAmount(from: $1.storeProduct.productIdentifier) 
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
                guard let selectedPackage = self.selectedPackage else { return }
                do {
                    _ = try await self.revenueCatService.purchase(selectedPackage)
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
                    _ = try await self.revenueCatService.restorePurchases()
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
