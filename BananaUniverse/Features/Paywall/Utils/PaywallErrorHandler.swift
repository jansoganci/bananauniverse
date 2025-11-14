//
//  PaywallErrorHandler.swift
//  BananaUniverse
//
//  Error handling utilities for paywall
//

import Foundation

struct PaywallErrorHandler {
    static func getErrorMessage(for error: Error, type: PaywallErrorType) -> (title: String, message: String) {
        let errorDescription = error.localizedDescription.lowercased()
        
        if errorDescription.contains("network") || errorDescription.contains("connection") ||
           errorDescription.contains("internet") || errorDescription.contains("timeout") {
            return ("We Couldn't Connect", "Network connection lost. Please check your internet connection and try again.")
        }
        
        if errorDescription.contains("storekit") || errorDescription.contains("payment") ||
           errorDescription.contains("purchase") || errorDescription.contains("apple id") {
            return ("Payment Issue", "Payment could not be processed. Please check your Apple ID or try again later.")
        }
        
        if type == .restore && (errorDescription.contains("restore") || errorDescription.contains("purchase")) {
            return ("No Purchases Found", "No previous purchases were found to restore.")
        }
        
        return ("Something Went Wrong", "We encountered an unexpected issue. Please try again.")
    }
}

