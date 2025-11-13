//
//  ProfileViewModel.swift
//  noname_banana
//
//  Created by AI Assistant on 16.10.2025.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class ProfileViewModel: ObservableObject {
    // Single source of truth for premium status
    @Published private(set) var isPremiumUser: Bool = false
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""
    @Published var showDeleteConfirmation: Bool = false
    @Published var isDeletingAccount: Bool = false
    @Published var profile: UserProfile? = nil
    @Published var isProfileLoading: Bool = false
    @Published var profileError: String? = nil
    @Published var isLoadingSubscription: Bool = false
    
    // Success alert handling from StoreKitService
    @Published var shouldShowSuccessAlert: Bool = false
    @Published var successAlertMessage: String = ""
    
    private let supabaseService = SupabaseService.shared
    private let authService = HybridAuthService.shared
    private let creditManager = CreditManager.shared
    private let storeKitService = StoreKitService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Computed property for backward compatibility
    var isPRO: Bool {
        isPremiumUser
    }
    
    init() {
        // Initialize premium status from CreditManager
        self.isPremiumUser = creditManager.isPremiumUser
        
        // Subscribe to CreditManager's premium status updates
        creditManager.$isPremiumUser
            .receive(on: RunLoop.main)
            .sink { [weak self] newValue in
                self?.isPremiumUser = newValue
                #if DEBUG
                print("🔄 Premium status updated: \(newValue)")
                #endif
            }
            .store(in: &cancellables)
        
        // Subscribe to StoreKitService success alerts
        storeKitService.$shouldShowSuccessAlert
            .receive(on: RunLoop.main)
            .sink { [weak self] shouldShow in
                self?.shouldShowSuccessAlert = shouldShow
            }
            .store(in: &cancellables)
        
        storeKitService.$successAlertMessage
            .receive(on: RunLoop.main)
            .sink { [weak self] message in
                self?.successAlertMessage = message
            }
            .store(in: &cancellables)
    }
    
    @MainActor
    func restorePurchases() async {
        do {
            try await StoreKitService.shared.restorePurchases()
            // isPRO will be updated automatically via CreditManager subscription
            #if DEBUG
            print("✅ Restore successful – user upgraded to PRO")
            #endif
        } catch {
            #if DEBUG
            print("⚠️ Restore failed – please try again later: \(error.localizedDescription)")
            #endif
            
            await MainActor.run {
                self.handleRestoreError(error)
            }
        }
    }
    
    func openManageSubscription() {
        DispatchQueue.main.async {
            if let manageURL = URL(string: "https://apps.apple.com/account/subscriptions") {
                UIApplication.shared.open(manageURL)
            }
        }
    }
    
    // MARK: - Subscription Status Display
    
    func getSubscriptionStatusText() -> String {
        let isPremium = creditManager.isPremiumUser
        
        if isPremium {
            if let renewalDate = StoreKitService.shared.subscriptionRenewalDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
                let formattedDate = formatter.string(from: renewalDate)
                return "Active Subscription – renews on \(formattedDate)"
            } else {
                return "Active Subscription – renews on –"
            }
        } else {
            return "Subscription inactive – renew to continue premium access"
        }
    }
    
    @MainActor
    func refreshSubscriptionDetails() async {
        isLoadingSubscription = true
        
        do {
            await CreditManager.shared.refreshSubscriptionInBackground()
            #if DEBUG
            print("✅ Subscription details refreshed")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to refresh subscription details: \(error.localizedDescription)")
            #endif
            
            alertMessage = "We couldn't retrieve your subscription details. Please try again later."
            showAlert = true
        }
        
        isLoadingSubscription = false
    }
    
    // MARK: - Account Deletion
    
    func showDeleteAccountConfirmation() {
        showDeleteConfirmation = true
    }
    
    func deleteAccount() async {
        guard !isDeletingAccount else { return }
        
        await MainActor.run {
            isDeletingAccount = true
        }
        
        do {
            
            // Call Supabase to delete account and all data
            try await supabaseService.deleteUserAccount()
            
            // Sign out the user after successful deletion
            try await authService.signOut()
            
            await MainActor.run {
                isDeletingAccount = false
                showDeleteConfirmation = false
                alertMessage = "Your account has been successfully deleted. You have been signed out."
                showAlert = true
            }
            
            
        } catch {
            
            await MainActor.run {
                isDeletingAccount = false
                showDeleteConfirmation = false
                
                // Show user-friendly error message
                if let appError = error as? AppError {
                    alertMessage = appError.errorDescription ?? "Account deletion failed. Please try again."
                } else {
                    alertMessage = "Account deletion failed. Please try again or contact support if the problem persists."
                }
                showAlert = true
            }
        }
    }

    // MARK: - Profile Loading
    func onAuthStateChanged(_ newState: UserState) async {
        switch newState {
        case .authenticated:
            await loadProfile()
        case .anonymous:
            await MainActor.run {
                self.profile = nil
                self.profileError = nil
                self.isProfileLoading = false
            }
        }
    }
    
    func loadProfile() async {
        await MainActor.run {
            self.isProfileLoading = true
            self.profileError = nil
        }
        do {
            let data = try await supabaseService.getUserProfile()
            await MainActor.run {
                self.profile = data
                self.isProfileLoading = false
            }
        } catch {
            await MainActor.run {
                self.profileError = AppError.from(error).errorDescription
                self.isProfileLoading = false
            }
        }
    }
    
    func clearProfile() {
        profile = nil
        profileError = nil
        isProfileLoading = false
    }
    
    // MARK: - Error Handling
    
    private func handleRestoreError(_ error: Error) {
        let errorDescription = error.localizedDescription.lowercased()
        
        // Check for network-related errors
        if errorDescription.contains("network") || errorDescription.contains("connection") || 
           errorDescription.contains("internet") || errorDescription.contains("timeout") {
            alertMessage = "We couldn't connect to restore your purchases. Please check your internet connection and try again."
        }
        // Check for StoreKit specific errors
        else if errorDescription.contains("storekit") || errorDescription.contains("payment") || 
                errorDescription.contains("restore") || errorDescription.contains("subscription") {
            alertMessage = "No active subscriptions found. You may not have any purchases to restore."
        }
        // Default fallback
        else {
            alertMessage = "We encountered an issue restoring your purchases. Please try again later."
        }
        
        showAlert = true
    }
    
    // MARK: - Success Alert Handling
    
    func dismissSuccessAlert() {
        storeKitService.dismissSuccessAlert()
    }
}
