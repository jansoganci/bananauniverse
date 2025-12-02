//
//  PaymentDebugView.swift
//  BananaUniverse
//
//  Debug view to check payment system status
//

import SwiftUI

struct PaymentDebugView: View {
    @StateObject private var storeKitService = StoreKitService.shared
    @StateObject private var creditManager = CreditManager.shared
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text("Payment System Status")
                .font(.headline)
                .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
            
            Divider()
            
            // Test Mode Status
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Test Mode:")
                        .font(.subheadline)
                        .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                    Spacer()
                    if Config.enablePaymentTestMode {
                        Text("ENABLED")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    } else {
                        Text("DISABLED")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                }
                
                if Config.enablePaymentTestMode {
                    Text("Purchases will be simulated (no real payment)")
                        .font(.caption)
                        .foregroundColor(.orange)
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
            
            // Products Status
            VStack(alignment: .leading, spacing: 8) {
                Text("Products Loaded")
                    .font(.subheadline)
                    .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                
                if storeKitService.isLoading {
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.gray)
                } else if storeKitService.hasCreditProducts {
                    Text("\(storeKitService.creditProducts.count) products available")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    ForEach(storeKitService.creditProducts, id: \.id) { product in
                        HStack {
                            Text("• \(product.id)")
                                .font(.caption)
                            Spacer()
                            Text(product.displayPrice)
                                .font(.caption)
                        }
                        .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                    }
                } else {
                    Text("No products loaded")
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
                
                if let error = storeKitService.errorMessage {
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
                    Text("1. Check if Test Mode is enabled")
                    Text("2. Try to purchase credits")
                    Text("3. Check if credits increase")
                    Text("4. Check Xcode console for logs")
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

