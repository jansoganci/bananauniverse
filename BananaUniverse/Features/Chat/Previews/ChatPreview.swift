//
//  ChatPreview.swift
//  BananaUniverse
//
//  PREVIEW ONLY - Modern Apple HIG-compliant Chat screen design
//  Does not affect the actual app. Safe to preview in Xcode.
//
//  Design Philosophy:
//  - Clean, modern chat layout with natural message flow
//  - WhatsApp-style bubble design with proper alignment
//  - 8pt grid spacing system
//  - Theme-aware (light/dark mode)
//

import SwiftUI

// MARK: - Preview: Modern Chat Screen Structure

struct ChatPreview: View {
    @Environment(\.colorScheme) var systemColorScheme
    @StateObject private var themeManager = ThemeManager()
    @State private var messageText: String = ""
    
    private var colorScheme: ColorScheme {
        themeManager.resolvedColorScheme
    }
    
    // Mock messages
    private let mockMessages: [MockChatMessage] = [
        MockChatMessage(
            id: UUID(),
            content: "Hey Banana, can you enhance this image?",
            isFromUser: true,
            timestamp: Date().addingTimeInterval(-3600)
        ),
        MockChatMessage(
            id: UUID(),
            content: "Sure! Upload it and I'll apply the enhancement filters.",
            isFromUser: false,
            timestamp: Date().addingTimeInterval(-3550)
        )
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Fixed Header
                headerView
                
                // Scrollable Messages
                messagesView
                
                // Input Bar
                inputBarView
            }
            .background(DesignTokens.Background.primary(colorScheme))
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
        }
        .environmentObject(themeManager)
        .onAppear {
            themeManager.updateResolvedScheme(systemScheme: systemColorScheme)
        }
        .onChange(of: systemColorScheme) { newScheme in
            themeManager.updateResolvedScheme(systemScheme: newScheme)
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        UnifiedHeaderBar(
            title: "Chat",
            leftContent: nil,
            rightContent: nil
        )
    }
    
    // MARK: - Messages View
    
    private var messagesView: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.md) {
                ForEach(mockMessages) { message in
                    ChatBubbleView(
                        message: message,
                        colorScheme: colorScheme
                    )
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.md)
        }
    }
    
    // MARK: - Input Bar View
    
    private var inputBarView: some View {
        HStack(alignment: .bottom, spacing: DesignTokens.Spacing.sm) {
            // Photo button
            Button(action: {}) {
                Image(systemName: "photo")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(DesignTokens.Text.tertiary(colorScheme))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(DesignTokens.Surface.input(colorScheme))
                    )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Text input
            TextField("Message", text: $messageText, axis: .vertical)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(DesignTokens.Text.primary(colorScheme))
                .lineLimit(1...6)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                        .fill(DesignTokens.Surface.input(colorScheme))
                )
            
            // Send button
            Button(action: {}) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(
                        !messageText.isEmpty
                            ? DesignTokens.Brand.primary(colorScheme)
                            : DesignTokens.Text.quaternary(colorScheme)
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(messageText.isEmpty)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .padding(.bottom, DesignTokens.Spacing.sm)
        .background(
            // iMessage-style blurred background
            ZStack {
                DesignTokens.Surface.primary(colorScheme)
                    .opacity(0.95)
                Rectangle()
                    .fill(.ultraThinMaterial)
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 8, x: 0, y: -2)
        )
    }
}

// MARK: - Chat Bubble View

struct ChatBubbleView: View {
    let message: MockChatMessage
    let colorScheme: ColorScheme
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isFromUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 6) {
                // Message bubble
                Text(message.content)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(
                        message.isFromUser
                            ? .white
                            : DesignTokens.Text.primary(colorScheme)
                    )
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Group {
                            if message.isFromUser {
                                // User bubble with gradient
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        DesignTokens.Gradients.energeticStart(colorScheme),
                                        DesignTokens.Gradients.energeticEnd(colorScheme)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            } else {
                                // AI bubble with solid color
                                DesignTokens.Surface.secondary(colorScheme)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg))
                        .shadow(
                            color: .black.opacity(colorScheme == .dark ? 0.3 : 0.1),
                            radius: 4,
                            x: 0,
                            y: 2
                        )
                    )
                
                // Timestamp
                Text(formatTime(message.timestamp))
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(DesignTokens.Text.tertiary(colorScheme))
                    .padding(.horizontal, 6)
            }
            
            if !message.isFromUser {
                Spacer(minLength: 60)
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Mock Chat Message Model

struct MockChatMessage: Identifiable {
    let id: UUID
    let content: String
    let isFromUser: Bool
    let timestamp: Date
}

// MARK: - Xcode Preview

#Preview("ChatPreview_Light") {
    ChatPreview()
        .preferredColorScheme(.light)
}

#Preview("ChatPreview_Dark") {
    ChatPreview()
        .preferredColorScheme(.dark)
}

