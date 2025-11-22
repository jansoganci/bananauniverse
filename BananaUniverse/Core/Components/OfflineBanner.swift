//
//  OfflineBanner.swift
//  BananaUniverse
//
//  Created by AI Assistant on 2025-11-21.
//  Purpose: Global offline connectivity banner with auto-dismiss on reconnection
//

import SwiftUI

/// Displays a banner at the top of the screen when the user is offline
/// Automatically appears when connectivity is lost and dismisses when restored
struct OfflineBanner: View {
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @State private var isDismissed = false
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        Group {
            if !networkMonitor.isConnected && !isDismissed {
                HStack(spacing: 12) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("You're Offline")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)

                        Text("Check your internet connection")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.white.opacity(0.9))
                    }

                    Spacer()

                    Button(action: {
                        withAnimation(.easeOut(duration: 0.3)) {
                            isDismissed = true
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 24, height: 24)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Color.orange
                        .ignoresSafeArea(edges: .top)
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .onChange(of: networkMonitor.isConnected) { newValue in
                    if newValue {
                        // Auto-dismiss when back online
                        withAnimation(.easeOut(duration: 0.3)) {
                            isDismissed = false
                        }
                    } else {
                        // Reappear when offline (even if previously dismissed)
                        withAnimation(.easeIn(duration: 0.3)) {
                            isDismissed = false
                        }
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: networkMonitor.isConnected)
        .animation(.easeInOut(duration: 0.3), value: isDismissed)
    }
}

#Preview("Offline State") {
    OfflineBanner()
        .environmentObject(ThemeManager())
}
