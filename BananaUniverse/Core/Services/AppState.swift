// BananaUniverse/Core/Services/AppState.swift
import Foundation
import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var sessionId: UUID = UUID()
    @Published var selectedToolId: String?
    @Published var currentPrompt: String?

    func selectPreset(id: String, prompt: String) {
        // Always start a fresh session
        selectedToolId = id
        currentPrompt = prompt
        sessionId = UUID()
    }
}