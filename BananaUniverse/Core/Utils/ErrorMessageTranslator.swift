//
//  ErrorMessageTranslator.swift
//  BananaUniverse
//
//  Created by AI Assistant on 2025-11-21.
//  Purpose: Translates technical error messages into user-friendly messages
//

import Foundation

/// Utility for converting technical error messages into user-friendly ones
enum ErrorMessageTranslator {

    /// Converts technical error messages into user-friendly messages
    /// - Parameter error: The error to translate
    /// - Returns: A user-friendly error message string
    static func userFriendlyMessage(for error: Error) -> String {
        let errorDescription = error.localizedDescription.lowercased()

        // Network offline errors
        if errorDescription.contains("internet connection appears to be offline") ||
           errorDescription.contains("network connection was lost") ||
           errorDescription.contains("not connected to the internet") {
            return "You're offline. Please check your internet connection and try again."
        }

        // Timeout errors
        if errorDescription.contains("timed out") ||
           errorDescription.contains("timeout") ||
           errorDescription.contains("request timeout") {
            return "Connection timed out. Please check your network and try again."
        }

        // DNS / Server unreachable
        if errorDescription.contains("could not connect") ||
           errorDescription.contains("cannot connect") ||
           errorDescription.contains("failed to connect") ||
           errorDescription.contains("connection failed") {
            return "Can't reach our servers. Check your internet connection."
        }

        // URL errors
        if errorDescription.contains("url") &&
           (errorDescription.contains("invalid") || errorDescription.contains("bad")) {
            return "Invalid request. Please try again."
        }

        // Default fallback - generic but friendly
        return "Something went wrong. Please try again."
    }

    /// Checks if an error is related to network connectivity
    /// - Parameter error: The error to check
    /// - Returns: True if the error is network-related, false otherwise
    static func isNetworkError(_ error: Error) -> Bool {
        let errorDescription = error.localizedDescription.lowercased()

        return errorDescription.contains("offline") ||
               errorDescription.contains("network") ||
               errorDescription.contains("connection") ||
               errorDescription.contains("internet") ||
               errorDescription.contains("timeout") ||
               errorDescription.contains("timed out") ||
               errorDescription.contains("unreachable") ||
               errorDescription.contains("connect")
    }
}
