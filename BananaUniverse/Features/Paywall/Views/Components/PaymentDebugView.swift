//
//  PaymentDebugView.swift
//  BananaUniverse
//
//  Debug view to check payment system status
//

import SwiftUI
import RevenueCat

struct PaymentDebugView: View {
    @StateObject private var revenueCatService = RevenueCatService.shared
    @StateObject private var creditManager = CreditManager.shared
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text("Payment System Status")
                .font(.headline)
                .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
            
            Divider()
            
            // RevenueCat Status
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("RevenueCat SDK:")
                        .font(.subheadline)
                        .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                    Spacer()
                    Text("Configured")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
            
            Divider()
            
            // Credit Balance
            VStack(alignment: .leading, spacing: 8) {
                Text("Credit Balance")
                    .font(.subheadline)
                    .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                Text("\(creditManager.creditsRemaining) credits")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
            }
            
            Divider()
            
            // Offerings Status
            VStack(alignment: .leading, spacing: 8) {
                Text("Offerings Loaded")
                    .font(.subheadline)
                    .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                
                if revenueCatService.isLoading {
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.gray)
                } else if let offering = revenueCatService.currentOffering {
                    Text("\(offering.availablePackages.count) packages available")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    ForEach(offering.availablePackages) { package in
                        HStack {
                            Text("• \(package.identifier)")
                                .font(.caption)
                            Spacer()
                            Text(package.storeProduct.localizedPriceString)
                                .font(.caption)
                        }
                        .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                    }
                } else {
                    Text("No offerings loaded")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            Divider()
            
            // Payment Status
            VStack(alignment: .leading, spacing: 8) {
                Text("Payment Status")
                    .font(.subheadline)
                    .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                
                if let error = revenueCatService.errorMessage {
                    Text("Error: \(error)")
                        .font(.caption)
                        .foregroundColor(.red)
                } else {
                    Text("Ready")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            // Instructions
            VStack(alignment: .leading, spacing: 8) {
                Text("How to Test:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("1. Use an Apple Sandbox account")
                    Text("2. Try to purchase credits from paywall")
                    Text("3. Check if credits increase")
                    Text("4. Check Xcode console for RevenueCat logs")
                }
                .font(.caption)
                .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(DesignTokens.Background.secondary(themeManager.resolvedColorScheme))
        )
    }
}

#Preview {
    PaymentDebugView()
        .environmentObject(ThemeManager())
}

