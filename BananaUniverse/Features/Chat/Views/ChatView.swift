//
//  ChatView.swift
//  noname_banana
//
//  Rebuilt with Modern WhatsApp-Style Architecture
//  Steve Jobs Philosophy: "Simplicity is the ultimate sophistication"
//

import SwiftUI
import PhotosUI

// MARK: - Main Chat Container View

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        ChatContainerView(
            viewModel: viewModel
        )
        .photosPicker(
            isPresented: $viewModel.showingImagePicker,
            selection: $viewModel.selectedImageItem,
            matching: .images
        )
        .onChange(of: viewModel.selectedImageItem) { _ in
            viewModel.handleImageItemSelection()
        }
        .sheet(isPresented: $viewModel.showingPaywall) {
            PaywallPreview()
        }
        .sheet(isPresented: $viewModel.showingLogin) {
            LoginView()
        }
        .alert("chat_error_title".localized, isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("chat_ok".localized) { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

// MARK: - Chat Container View (Root Layout)

struct ChatContainerView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject private var creditManager = CreditManager.shared
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appState: AppState
    @FocusState private var isInputFocused: Bool
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastType: ToastType = .success
    @State private var showPermissionAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            UnifiedHeaderBar(
                title: "",  // Empty title since logo serves as identifier
                leftContent: .appLogo(32),
                rightContent: .quotaBadge(creditManager.creditsRemaining, { 
                    viewModel.showingPaywall = true
                })
            )
            
            // Messages Area
            ChatMessagesView(
                messages: viewModel.messages,
                isProcessing: viewModel.isProcessing,
                uploadProgress: viewModel.uploadProgress,
                selectedImage: viewModel.selectedImage,
                onUploadTap: handleUploadTap,
                onSaveMessage: handleSaveMessage,
                onShareMessage: viewModel.shareMessageImage
            )
            
            // Input Area
            ChatInputView(
                text: $viewModel.currentPrompt,
                hasImageSelected: viewModel.selectedImage != nil,
                canSend: canSendMessage,
                isProcessing: viewModel.isProcessing,
                isFocused: $isInputFocused,
                onImageTap: handleUploadTap,
                onSendTap: handleSendMessage
            )
        }
        .background(
            DesignTokens.Background.primary(themeManager.resolvedColorScheme)
                .ignoresSafeArea()
        )
        .overlay(alignment: .top) {
            // Toast Overlay
            if showToast {
                ToastView(message: toastMessage, type: toastType)
                    .padding(.top, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(DesignTokens.Animation.smooth, value: showToast)
            }
        }
        .onTapGesture {
            // Dismiss keyboard on tap outside
            isInputFocused = false
        }
        .onChange(of: appState.sessionId) { _ in
            if appState.currentPrompt != nil && !appState.currentPrompt!.isEmpty {
                viewModel.showingImagePicker = true
            }
        }
        .alert("chat_photo_access_title".localized, isPresented: $showPermissionAlert) {
            Button("chat_open_settings".localized) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("chat_cancel".localized, role: .cancel) { }
        } message: {
            Text("chat_photo_access_message".localized)
        }
    }
    
    // MARK: - Computed Properties
    
    private var canSendMessage: Bool {
        guard !viewModel.currentPrompt.isEmpty else { return false }
        return viewModel.selectedImage != nil && creditManager.canProcessImage() && !viewModel.isProcessing
    }
    
    // MARK: - Actions
    
    private func handleUploadTap() {
        // Check credits for ALL users (anonymous AND authenticated)
        if !creditManager.canProcessImage() {
            viewModel.showingPaywall = true
        } else {
            viewModel.showingImagePicker = true
        }
    }
    
    private func handleSendMessage() {
        guard canSendMessage else { return }

        // Haptic feedback
        DesignTokens.Haptics.impact(.light)
        
        // Send message with original prompt
        Task {
            await viewModel.processSelectedImage()
            
            // Clear input field (WhatsApp-style) - only after processing completes
            await MainActor.run {
                viewModel.currentPrompt = ""
            }
        }
        
        // Dismiss keyboard
        isInputFocused = false
        
        // Show feedback
        showToastMessage("chat_processing_toast".localized, type: .info)
    }
    
    private func handleSaveMessage(_ messageId: UUID) {
        showToastMessage("chat_saving_toast".localized, type: .info)
        
        Task {
            let result = await viewModel.saveMessageImage(messageId)
            await MainActor.run {
                switch result {
                case .success:
                    showToastMessage("chat_saved_toast".localized, type: .success)
                    
                case .failure(.permissionDenied):
                    showPermissionAlert = true
                    
                case .failure(.noImage):
                    showToastMessage("chat_no_image_toast".localized, type: .error)
                    
                case .failure(.saveFailed(let error)):
                    showToastMessage("chat_save_failed_toast".localized(error), type: .error)
                }
            }
        }
    }
    
    private func showToastMessage(_ message: String, type: ToastType) {
        toastMessage = message
        toastType = type
        withAnimation(DesignTokens.Animation.smooth) {
            showToast = true
        }
        
        // Auto-dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(DesignTokens.Animation.smooth) {
                showToast = false
            }
        }
    }
}

// MARK: - 💬 CHAT MESSAGES VIEW

struct ChatMessagesView: View {
    let messages: [ChatMessage]
    let isProcessing: Bool
    let uploadProgress: Double
    let selectedImage: UIImage?
    let onUploadTap: () -> Void
    let onSaveMessage: (UUID) -> Void
    let onShareMessage: (UUID) -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    // Empty state / Upload area
                    if messages.isEmpty {
                        EmptyStateView(
                            selectedImage: selectedImage,
                            isProcessing: isProcessing,
                            uploadProgress: uploadProgress,
                            onTap: onUploadTap
                        )
                    }
                    
                    // Messages
                    ForEach(messages) { message in
                        MessageBubbleView(
                            message: message,
                            onSave: onSaveMessage,
                            onShare: onShareMessage
                        )
                        .id(message.id)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                    
                    // Processing indicator
                    if isProcessing {
                        ProcessingBubbleView(progress: uploadProgress)
                            .id("processing")
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
            }
            .background(DesignTokens.Background.primary(themeManager.resolvedColorScheme))
            .onChange(of: messages.count) { _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: isProcessing) { processing in
                if processing {
                    scrollToBottom(proxy: proxy)
                }
            }
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(DesignTokens.Animation.spring) {
                if isProcessing {
                    proxy.scrollTo("processing", anchor: .bottom)
                } else if let lastMessage = messages.last {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
    }
}

// MARK: - ⌨️ CHAT INPUT VIEW

struct ChatInputView: View {
    @Binding var text: String
    let hasImageSelected: Bool
    let canSend: Bool
    let isProcessing: Bool
    var isFocused: FocusState<Bool>.Binding
    @EnvironmentObject var themeManager: ThemeManager
    let onImageTap: () -> Void
    let onSendTap: () -> Void
    
    var body: some View {
        HStack(alignment: .bottom, spacing: DesignTokens.Spacing.sm) {
            // Attachment button
            Button(action: onImageTap) {
                Image(systemName: hasImageSelected ? "photo.fill" : "photo")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(hasImageSelected ? DesignTokens.Brand.primary(themeManager.resolvedColorScheme) : DesignTokens.Text.tertiary(themeManager.resolvedColorScheme))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(DesignTokens.Surface.input(themeManager.resolvedColorScheme))
                            .shadow(
                                color: themeManager.resolvedColorScheme == .dark
                                    ? DesignTokens.ShadowColors.primary(themeManager.resolvedColorScheme)
                                    : Color.clear,
                                radius: 8,
                                x: 0,
                                y: 0
                            )
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isProcessing)
            
            // Text input
            TextField("chat_input_placeholder".localized, text: $text, axis: .vertical)
                .font(DesignTokens.Typography.body)
                .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                .focused(isFocused)
                .lineLimit(1...6)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                        .fill(DesignTokens.Surface.input(themeManager.resolvedColorScheme))
                        .shadow(
                            color: themeManager.resolvedColorScheme == .dark
                                ? DesignTokens.ShadowColors.primary(themeManager.resolvedColorScheme).opacity(0.15)
                                : Color.clear,
                            radius: 8,
                            x: 0,
                            y: 0
                        )
                )
                .disabled(isProcessing)
            
            // Send button
            Button(action: onSendTap) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(canSend ? DesignTokens.Brand.primary(themeManager.resolvedColorScheme) : DesignTokens.Text.quaternary(themeManager.resolvedColorScheme))
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!canSend || isProcessing)
            .scaleEffect(canSend ? 1.0 : 0.9)
            .animation(DesignTokens.Animation.quick, value: canSend)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(
            // iMessage-style blurred background
            ZStack {
                DesignTokens.Surface.primary(themeManager.resolvedColorScheme)
                    .opacity(0.95)
                Rectangle()
                    .fill(.ultraThinMaterial)
            }
            .shadow(
                color: DesignTokens.ShadowColors.default(themeManager.resolvedColorScheme).opacity(themeManager.resolvedColorScheme == .dark ? 0.3 : 0.05),
                radius: 8,
                x: 0,
                y: -2
            )
        )
    }
}

// MARK: - Message Bubble View

// MARK: - Visual Enhancements from ChatPreview (Gradient, Blur, Shadow, FontWeight)

struct MessageBubbleView: View {
    let message: ChatMessage
    let onSave: (UUID) -> Void
    let onShare: (UUID) -> Void
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingFullScreenImage = false

    private var isFromUser: Bool { message.type == .user }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isFromUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: isFromUser ? .trailing : .leading, spacing: 6) {
                // Message bubble
                VStack(alignment: isFromUser ? .trailing : .leading, spacing: 8) {
                    // Text content
                    Text(message.content)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(isFromUser ? DesignTokens.Text.inverse : DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Group {
                                if isFromUser {
                                    // User bubble with gradient
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            DesignTokens.Gradients.primaryStart(themeManager.resolvedColorScheme),
                                            DesignTokens.Gradients.primaryEnd(themeManager.resolvedColorScheme)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                } else {
                                    // AI bubble with existing color logic
                                    bubbleColor
                                }
                            }
                            .clipShape(ChatBubbleShape(isFromUser: isFromUser))
                            .shadow(
                                color: DesignTokens.ShadowColors.default(themeManager.resolvedColorScheme).opacity(themeManager.resolvedColorScheme == .dark ? 0.3 : 0.1),
                                radius: 4,
                                x: 0,
                                y: 2
                            )
                        )
                    
                    // Image if present
                    if let image = message.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 250, maxHeight: 300)
                            .cornerRadius(DesignTokens.CornerRadius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                                    .stroke(DesignTokens.Special.borderDefault(themeManager.resolvedColorScheme), lineWidth: 1)
                            )
                            .onTapGesture {
                                DesignTokens.Haptics.impact(.light)
                                showingFullScreenImage = true
                            }

                        // Action buttons for AI messages with images
                        if !isFromUser && message.image != nil {
                            MessageActionButtons(
                                messageId: message.id,
                                onSave: onSave,
                                onShare: onShare
                            )
                        }
                    }
                }
                
                // Timestamp
                Text(formatTime(message.timestamp))
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(DesignTokens.Text.tertiary(themeManager.resolvedColorScheme))
                    .padding(.horizontal, 6)
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            
            if !isFromUser {
                Spacer(minLength: 60)
            }
        }
        .fullScreenCover(isPresented: $showingFullScreenImage) {
            if let image = message.image {
                FullScreenImageViewer(image: image, isPresented: $showingFullScreenImage)
            }
        }
    }

    private var bubbleColor: Color {
        switch message.type {
        case .user:
            return DesignTokens.Brand.primary(themeManager.resolvedColorScheme)
        case .assistant:
            return DesignTokens.Surface.chatBubbleIncoming(themeManager.resolvedColorScheme)
        case .error:
            return DesignTokens.Semantic.error(themeManager.resolvedColorScheme).opacity(0.15)
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Chat Bubble Shape (WhatsApp-style)

struct ChatBubbleShape: Shape {
    let isFromUser: Bool
    
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 18
        let tailSize: CGFloat = 6
        
        var path = Path()
        
        if isFromUser {
            // User bubble (right side with tail on bottom right)
            path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY + radius),
                control: CGPoint(x: rect.maxX, y: rect.minY)
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius - tailSize))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - radius, y: rect.maxY - tailSize),
                control: CGPoint(x: rect.maxX, y: rect.maxY - tailSize)
            )
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.maxY - tailSize))
            
            // Tail
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.maxY - tailSize))
            
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY - tailSize))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY - radius - tailSize),
                control: CGPoint(x: rect.minX, y: rect.maxY - tailSize)
            )
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + radius, y: rect.minY),
                control: CGPoint(x: rect.minX, y: rect.minY)
            )
        } else {
            // AI bubble (left side with tail on bottom left)
            path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY + radius),
                control: CGPoint(x: rect.maxX, y: rect.minY)
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius - tailSize))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - radius, y: rect.maxY - tailSize),
                control: CGPoint(x: rect.maxX, y: rect.maxY - tailSize)
            )
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY - tailSize))
            
            // Tail
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY - tailSize))
            
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY - radius - tailSize),
                control: CGPoint(x: rect.minX, y: rect.maxY - tailSize)
            )
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + radius, y: rect.minY),
                control: CGPoint(x: rect.minX, y: rect.minY)
            )
        }
        
        path.closeSubpath()
        return path
    }
}

// MARK: - Message Action Buttons

struct MessageActionButtons: View {
    let messageId: UUID
    let onSave: (UUID) -> Void
    let onShare: (UUID) -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var isSaving = false
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Save button
            Button(action: {
                guard !isSaving else { return }
                DesignTokens.Haptics.impact(.light)
                
                withAnimation(DesignTokens.Animation.quick) {
                    isSaving = true
                }
                onSave(messageId)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(DesignTokens.Animation.quick) {
                        isSaving = false
                    }
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: isSaving ? "checkmark" : "arrow.down.circle")
                        .font(.system(size: 14, weight: .medium))
                    Text(isSaving ? "chat_saved_button".localized : "chat_save_button".localized)
                        .font(DesignTokens.Typography.caption1)
                        .fontWeight(.medium)
                }
                .foregroundColor(DesignTokens.Text.inverse)
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(
                    Capsule()
                        .fill(isSaving ? DesignTokens.Brand.secondary(themeManager.resolvedColorScheme) : DesignTokens.Brand.primary(themeManager.resolvedColorScheme))
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isSaving)
            
            // Share button
            Button(action: {
                DesignTokens.Haptics.impact(.light)
                onShare(messageId)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .medium))
                    Text("chat_share_button".localized)
                        .font(DesignTokens.Typography.caption1)
                        .fontWeight(.medium)
                }
                .foregroundColor(DesignTokens.Brand.primary(themeManager.resolvedColorScheme))
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(
                    Capsule()
                        .stroke(DesignTokens.Brand.primary(themeManager.resolvedColorScheme), lineWidth: 1.5)
                        .background(Capsule().fill(DesignTokens.Surface.primary(themeManager.resolvedColorScheme)))
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: - ⏳ PROCESSING BUBBLE VIEW

struct ProcessingBubbleView: View {
    let progress: Double
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: DesignTokens.Brand.primary(themeManager.resolvedColorScheme)))
                        .scaleEffect(0.9)
                    
                    Text("chat_processing_message".localized)
                        .font(DesignTokens.Typography.callout)
                        .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                }
                
                if progress > 0 {
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: DesignTokens.Brand.primary(themeManager.resolvedColorScheme)))
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                ChatBubbleShape(isFromUser: false)
                    .fill(DesignTokens.Surface.chatBubbleIncoming(themeManager.resolvedColorScheme))
            )
            .padding(.horizontal, DesignTokens.Spacing.md)
            
            Spacer(minLength: 60)
        }
    }
}

// MARK: - 📭 EMPTY STATE VIEW

struct EmptyStateView: View {
    let selectedImage: UIImage?
    let isProcessing: Bool
    let uploadProgress: Double
    let onTap: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: DesignTokens.Spacing.lg) {
                if let image = selectedImage {
                    // Selected image preview
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 280, maxHeight: 350)
                        .cornerRadius(DesignTokens.CornerRadius.lg)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                                .stroke(DesignTokens.Special.borderDefault(themeManager.resolvedColorScheme), lineWidth: 1)
                        )
                        .opacity(isProcessing ? 0.6 : 1.0)
                } else {
                    // Upload prompt
                    VStack(spacing: DesignTokens.Spacing.md) {
                        ZStack {
                            Circle()
                                .fill(DesignTokens.Brand.primary(themeManager.resolvedColorScheme).opacity(0.1))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 36, weight: .medium))
                                .foregroundColor(DesignTokens.Brand.primary(themeManager.resolvedColorScheme))
                        }
                        
                        VStack(spacing: 8) {
                            Text("chat_empty_title".localized)
                                .font(DesignTokens.Typography.title3)
                                .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                            
                            Text("chat_empty_subtitle".localized)
                                .font(DesignTokens.Typography.callout)
                                .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                
                if isProcessing {
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: DesignTokens.Brand.primary(themeManager.resolvedColorScheme)))
                            .scaleEffect(1.2)
                        
                        Text("chat_uploading".localized)
                            .font(DesignTokens.Typography.callout)
                            .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isProcessing)
    }
}

// MARK: - Chat Design System

// ChatDesignSystem has been consolidated into DesignTokens.swift for app-wide consistency

// MARK: - Toast View

enum ToastType {
    case success, error, info
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }
    
    func color(_ colorScheme: ColorScheme) -> Color {
        switch self {
        case .success: return DesignTokens.Brand.secondary(colorScheme)
        case .error: return DesignTokens.Semantic.error(colorScheme)
        case .info: return DesignTokens.Brand.primary(colorScheme)
        }
    }
}

struct ToastView: View {
    let message: String
    let type: ToastType
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: type.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(type.color(themeManager.resolvedColorScheme))
            
            Text(message)
                .font(DesignTokens.Typography.callout)
                .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(DesignTokens.Surface.primary(themeManager.resolvedColorScheme))
                .shadow(color: DesignTokens.ShadowColors.default(themeManager.resolvedColorScheme).opacity(0.15), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, DesignTokens.Spacing.md)
    }
}

// Color(hex:) extension is already defined in Color+DesignSystem.swift

// MARK: - 🖼️ FULL SCREEN IMAGE VIEWER

struct FullScreenImageViewer: View {
    let image: UIImage
    @Binding var isPresented: Bool
    @EnvironmentObject var themeManager: ThemeManager
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @GestureState private var dragOffset: CGSize = .zero

    var body: some View {
        ZStack {
            // Background
            DesignTokens.Surface.overlay(themeManager.resolvedColorScheme)
                .ignoresSafeArea()
                .onTapGesture {
                    DesignTokens.Haptics.impact(.light)
                    isPresented = false
                }

            // Image with zoom and pan
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(scale)
                .offset(x: offset.width + dragOffset.width, y: offset.height + dragOffset.height)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = lastScale * value
                        }
                        .onEnded { value in
                            lastScale = scale
                            // Reset if zoomed out too far
                            if scale < 1.0 {
                                withAnimation(.spring()) {
                                    scale = 1.0
                                    lastScale = 1.0
                                    offset = .zero
                                    lastOffset = .zero
                                }
                            }
                        }
                )
                .gesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in
                            state = value.translation
                        }
                        .onEnded { value in
                            offset.width += value.translation.width
                            offset.height += value.translation.height
                            lastOffset = offset

                            // Dismiss if swiped down significantly
                            if value.translation.height > 150 && scale <= 1.0 {
                                DesignTokens.Haptics.impact(.light)
                                isPresented = false
                            }
                        }
                )

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        DesignTokens.Haptics.impact(.light)
                        isPresented = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(DesignTokens.Text.inverse.opacity(0.8))
                            .padding()
                    }
                }
                Spacer()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ChatView(viewModel: ChatViewModel())
        .environmentObject(AppState())
        .environmentObject(ThemeManager())
}
