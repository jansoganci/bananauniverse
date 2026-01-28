//
//  PaywallPreview.swift
//  BananaUniverse
//
//  Paywall with featured card + 3 horizontal standard cards
//

import SwiftUI
import RevenueCat

struct PaywallPreview: View {
    @StateObject private var revenueCatService = RevenueCatService.shared
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var selectedPackage: Package?
    @State private var selectedPackageId: String?
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showRetryAlert = false
    @State private var retryAction: (() -> Void)?

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                DesignTokens.Background.primary(colorScheme)
                    .ignoresSafeArea()

                GeometryReader { geometry in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            // Header
                            headerSection
                                .padding(.top, DesignTokens.Spacing.xl)

                            Spacer()
                                .frame(minHeight: DesignTokens.Spacing.xl)

                            // Products
                            if revenueCatService.isLoading {
                                loadingSection
                            } else if let offering = revenueCatService.currentOffering,
                                      !offering.availablePackages.isEmpty {
                                productsSection(offering: offering)
                            } else {
                                errorSection
                            }

                            Spacer()
                                .frame(minHeight: DesignTokens.Spacing.xl)

                            // CTA Button
                            ctaButton

                            Spacer()
                                .frame(minHeight: DesignTokens.Spacing.lg)

                            // Footer
                            footerSection
                                .padding(.bottom, DesignTokens.Spacing.lg)
                        }
                        .padding(.horizontal, DesignTokens.Spacing.lg)
                        .frame(minHeight: geometry.size.height)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(DesignTokens.Text.tertiary(colorScheme))
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("paywall_alert_ok".localized, role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .alert("paywall_alert_success_title".localized, isPresented: $revenueCatService.shouldShowSuccessAlert) {
                Button("paywall_alert_ok".localized, role: .cancel) {
                    revenueCatService.dismissSuccessAlert()
                }
            } message: {
                Text(revenueCatService.successAlertMessage)
            }
            .alert("paywall_alert_retry_title".localized, isPresented: $showRetryAlert) {
                Button("paywall_alert_cancel".localized, role: .cancel) { }
                Button("paywall_alert_retry".localized) { retryAction?() }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                Task {
                    await revenueCatService.fetchOfferings()
                    // Pre-select 100 credits
                    if let offering = revenueCatService.currentOffering,
                       let featured = offering.availablePackages.first(where: {
                           $0.storeProduct.productIdentifier.contains("100")
                       }) {
                        selectedPackage = featured
                        selectedPackageId = featured.identifier
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            Text("paywall_title".localized)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(DesignTokens.Text.primary(colorScheme))

            Text("paywall_subtitle".localized)
                .font(.system(size: 15))
                .foregroundColor(DesignTokens.Text.secondary(colorScheme))
        }
    }

    // MARK: - Loading

    private var loadingSection: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ProgressView()
                .scaleEffect(1.2)
            Text("paywall_loading".localized)
                .font(.subheadline)
                .foregroundColor(DesignTokens.Text.secondary(colorScheme))
        }
        .frame(height: 200)
    }

    // MARK: - Error

    private var errorSection: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(DesignTokens.Semantic.warning(colorScheme))
            Text("paywall_error_title".localized)
                .font(.headline)
            Button("paywall_error_retry".localized) {
                Task { await revenueCatService.fetchOfferings() }
            }
            .foregroundColor(DesignTokens.Brand.primary(colorScheme))
        }
        .frame(height: 200)
    }

    // MARK: - Products Section (NEW LAYOUT)

    private func productsSection(offering: Offering) -> some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            // === FEATURED CARD (100 credits) - AT TOP ===
            if let featured = offering.availablePackages.first(where: {
                $0.storeProduct.productIdentifier.contains("100")
            }) {
                featuredCard(package: featured)
            }

            // === 3 STANDARD CARDS - HORIZONTAL ROW ===
            HStack(spacing: DesignTokens.Spacing.sm) {
                ForEach([50, 25, 10], id: \.self) { credits in
                    if let pkg = offering.availablePackages.first(where: {
                        creditAmount(for: $0) == credits
                    }) {
                        standardCard(package: pkg)
                    }
                }
            }
        }
    }

    // MARK: - Featured Card (100 credits)

    private func featuredCard(package: Package) -> some View {
        let isSelected = selectedPackageId == package.identifier

        return Button(action: {
            DesignTokens.Haptics.selectionChanged()
            selectedPackage = package
            selectedPackageId = package.identifier
        }) {
            VStack(alignment: .leading, spacing: 6) {
                // Top row: Badge + Savings
                HStack {
                    Text("paywall_badge_best_value".localized)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(DesignTokens.Brand.primary(colorScheme)))

                    Spacer()

                    Text("paywall_card_save".localized(44))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(DesignTokens.Semantic.success(colorScheme))
                }

                // Credits
                Text("paywall_card_credits".localized(100))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(DesignTokens.Text.primary(colorScheme))

                // Per credit
                Text("paywall_card_per_credit".localized("$0.50"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignTokens.Semantic.success(colorScheme))

                // Value + Price
                HStack {
                    Text("paywall_card_value_description".localized(100))
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                    Spacer()
                    Text(package.storeProduct.localizedPriceString)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(DesignTokens.Text.primary(colorScheme))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.green.opacity(0.08) : DesignTokens.Surface.primary(colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected ? DesignTokens.Semantic.success(colorScheme) : DesignTokens.Special.borderDefault(colorScheme).opacity(0.3),
                        lineWidth: isSelected ? 2.5 : 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Standard Card (50, 25, 10 credits)

    private func standardCard(package: Package) -> some View {
        let isSelected = selectedPackageId == package.identifier
        let credits = creditAmount(for: package)
        let savings = savingsPercent(for: credits)

        return Button(action: {
            DesignTokens.Haptics.selectionChanged()
            selectedPackage = package
            selectedPackageId = package.identifier
        }) {
            VStack(spacing: 4) {
                // Credits
                Text("paywall_card_credits".localized(credits))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignTokens.Text.primary(colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                // Per credit
                Text(perCreditPrice(for: credits))
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Text.secondary(colorScheme))

                // Savings (if any)
                if let savings = savings {
                    Text("paywall_card_save".localized(savings))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(DesignTokens.Brand.accent(colorScheme))
                } else {
                    Text(" ")
                        .font(.system(size: 10))
                }

                Spacer()

                // Price
                Text(package.storeProduct.localizedPriceString)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(DesignTokens.Text.primary(colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 90)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.green.opacity(0.08) : DesignTokens.Surface.primary(colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? DesignTokens.Semantic.success(colorScheme) : DesignTokens.Special.borderDefault(colorScheme).opacity(0.3),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - CTA Button

    private var ctaButton: some View {
        Button(action: handlePurchase) {
            ZStack {
                if revenueCatService.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("paywall_button_cta_dynamic".localized(selectedPackage.map { creditAmount(for: $0) } ?? 100))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(DesignTokens.Text.onBrand(colorScheme))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        selectedPackage != nil
                            ? DesignTokens.Brand.primary(colorScheme)
                            : DesignTokens.Brand.primary(colorScheme).opacity(0.4)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(selectedPackage == nil || revenueCatService.isLoading)
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            Button("paywall_footer_restore".localized) {
                handleRestore()
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(DesignTokens.Text.link(colorScheme))

            HStack(spacing: DesignTokens.Spacing.lg) {
                Button("paywall_footer_terms".localized) {
                    if let url = URL(string: Config.termsOfServiceURL) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("paywall_footer_privacy".localized) {
                    if let url = URL(string: Config.privacyPolicyURL) {
                        UIApplication.shared.open(url)
                    }
                }
            }
            .font(.system(size: 12))
            .foregroundColor(DesignTokens.Text.tertiary(colorScheme))
        }
    }

    // MARK: - Helpers

    private func creditAmount(for package: Package) -> Int {
        let id = package.storeProduct.productIdentifier
        if id.contains("100") { return 100 }
        if id.contains("50") { return 50 }
        if id.contains("25") { return 25 }
        if id.contains("10") { return 10 }
        return 0
    }

    private func savingsPercent(for credits: Int) -> Int? {
        switch credits {
        case 50: return 33
        case 25: return 20
        default: return nil
        }
    }

    private func perCreditPrice(for credits: Int) -> String {
        switch credits {
        case 50: return "$0.60/credit"
        case 25: return "$0.72/credit"
        case 10: return "$0.90/credit"
        default: return ""
        }
    }

    private func handlePurchase() {
        Task {
            guard let pkg = selectedPackage else {
                alertTitle = "paywall_error_no_package_title".localized
                alertMessage = "paywall_error_no_package_message".localized
                showAlert = true
                return
            }
            DesignTokens.Haptics.impact(.medium)
            do {
                _ = try await revenueCatService.purchase(pkg)
            } catch {
                alertTitle = "paywall_error_purchase_failed".localized
                alertMessage = error.localizedDescription
                retryAction = { handlePurchase() }
                showRetryAlert = true
            }
        }
    }

    private func handleRestore() {
        Task {
            do {
                _ = try await revenueCatService.restorePurchases()
                alertTitle = "paywall_alert_success_title".localized
                alertMessage = "paywall_alert_purchases_restored".localized
                showAlert = true
            } catch {
                alertTitle = "paywall_error_restore_failed".localized
                alertMessage = error.localizedDescription
                retryAction = { handleRestore() }
                showRetryAlert = true
            }
        }
    }
}

// MARK: - Preview

#Preview("Light") {
    PaywallPreview()
        .environmentObject(ThemeManager())
}

#Preview("Dark") {
    PaywallPreview()
        .environmentObject(ThemeManager())
        .preferredColorScheme(.dark)
}
