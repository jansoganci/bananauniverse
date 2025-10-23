//
//  ChatView.swift
//  noname_banana
//
//  Rebuilt with Modern WhatsApp-Style Architecture
//  Steve Jobs Philosophy: "Simplicity is the ultimate sophistication"
//

import SwiftUI
import PhotosUI

// MARK: - 🎯 MAIN CHAT CONTAINER VIEW

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    
    let initialPrompt: String?
    
    var body: some View {
        ChatContainerView(
            viewModel: viewModel,
            initialPrompt: initialPrompt
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
            PreviewPaywallView()
        }
        .sheet(isPresented: $viewModel.showingLogin) {
            LoginView()
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

// MARK: - 📦 CHAT CONTAINER VIEW (Root Layout)

struct ChatContainerView: View {
    @ObservedObject var viewModel: ChatViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @FocusState private var isInputFocused: Bool
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastType: ToastType = .success
    @State private var showPermissionAlert = false
    
    let initialPrompt: String?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                DesignTokens.Background.primary(themeManager.resolvedColorScheme)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    UnifiedHeaderBar(
                        title: "",  // Empty title since logo serves as identifier
                        leftContent: .appLogo(32),
                        rightContent: viewModel.isPremiumUser 
                            ? .unlimitedBadge({ 
                                // PRO users can tap to see subscription details
                                // Could open manage subscription or show info
                            })
                            : .quotaBadge(viewModel.remainingQuota, viewModel.dailyQuotaLimit, { 
                                viewModel.showingPaywall = true
                                // TODO: insert Adapty Paywall ID here - placement: chat_quota_exceeded
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
                        text: Binding(
                            get: { viewModel.currentPrompt ?? "" },
                            set: { viewModel.currentPrompt = $0 }
                        ),
                        hasImageSelected: viewModel.selectedImage != nil,
                        canSend: canSendMessage,
                        isProcessing: viewModel.isProcessing,
                        isFocused: $isInputFocused,
                        onImageTap: handleUploadTap,
                        onSendTap: handleSendMessage
                    )
                }
                
                // Toast Overlay
                if showToast {
                    VStack {
                        ToastView(message: toastMessage, type: toastType)
                            .padding(.top, geometry.safeAreaInsets.top + 16)
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(DesignTokens.Animation.smooth, value: showToast)
                }
            }
            .onTapGesture {
                // Dismiss keyboard on tap outside
                isInputFocused = false
            }
            .onAppear {
                if let prompt = initialPrompt {
                    viewModel.setInitialPrompt(prompt)
                }
            }
            .alert("Photo Library Access Required", isPresented: $showPermissionAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please enable photo library access in Settings to save images to your Photos library.")
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var canSendMessage: Bool {
        guard let prompt = viewModel.currentPrompt, !prompt.isEmpty else { return false }
        guard HybridCreditManager.shared.creditsLoaded else { return false }
        return viewModel.selectedImage != nil && viewModel.remainingQuota > 0 && !viewModel.isProcessing
    }
    
    // MARK: - Actions
    
    private func handleUploadTap() {
        if viewModel.remainingQuota <= 0 && !HybridAuthService.shared.isAuthenticated {
            viewModel.showingPaywall = true
            // TODO: insert Adapty Paywall ID here - placement: chat_quota_exceeded
        } else {
            viewModel.showingImagePicker = true
        }
    }
    
    private func handleSendMessage() {
        guard canSendMessage else { return }
        
        // Haptic feedback
        DesignTokens.Haptics.impact(.medium)
        
        // Send message with original prompt
        Task {
            await viewModel.processSelectedImage()
            
            // Clear input field (WhatsApp-style) - only after processing completes
            await MainActor.run {
                viewModel.currentPrompt = nil
            }
        }
        
        // Dismiss keyboard
        isInputFocused = false
        
        // Show feedback
        showToastMessage("✨ Processing your request...", type: .info)
    }
    
    private func handleSaveMessage(_ messageId: UUID) {
        showToastMessage("Saving...", type: .info)
        
        Task {
            let result = await viewModel.saveMessageImage(messageId)
            await MainActor.run {
                switch result {
                case .success:
                    showToastMessage("✅ Saved to Photos!", type: .success)
                    
                case .failure(.permissionDenied):
                    showPermissionAlert = true
                    
                case .failure(.noImage):
                    showToastMessage("❌ No image to save", type: .error)
                    
                case .failure(.saveFailed(let error)):
                    showToastMessage("❌ Save failed: \(error)", type: .error)
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
            List {
                // Empty state / Upload area
                if messages.isEmpty {
                    EmptyStateView(
                        selectedImage: selectedImage,
                        isProcessing: isProcessing,
                        uploadProgress: uploadProgress,
                        onTap: onUploadTap
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                
                // Messages
                ForEach(messages) { message in
                    MessageBubbleView(
                        message: message,
                        onSave: onSaveMessage,
                        onShare: onShareMessage
                    )
                    .id(message.id)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(
                        top: 4,
                        leading: 0,
                        bottom: 4,
                        trailing: 0
                    ))
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
                
                // Processing indicator
                if isProcessing {
                    ProcessingBubbleView(progress: uploadProgress)
                        .id("processing")
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(
                            top: 4,
                            leading: 0,
                            bottom: 4,
                            trailing: 0
                        ))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
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
                    .foregroundColor(hasImageSelected ? DesignTokens.Brand.primary(.light) : DesignTokens.Text.tertiary(themeManager.resolvedColorScheme))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(DesignTokens.Surface.inputBackground(themeManager.resolvedColorScheme))
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isProcessing)
            
            // Text input
            TextField("Message", text: $text, axis: .vertical)
                .font(DesignTokens.Typography.body)
                .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                .focused(isFocused)
                .lineLimit(1...6)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                        .fill(DesignTokens.Surface.inputBackground(themeManager.resolvedColorScheme))
                )
                .disabled(isProcessing)
            
            // Send button
            Button(action: onSendTap) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(canSend ? DesignTokens.Brand.primary(.light) : DesignTokens.Text.quaternary(themeManager.resolvedColorScheme))
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!canSend || isProcessing)
            .scaleEffect(canSend ? 1.0 : 0.9)
            .animation(DesignTokens.Animation.quick, value: canSend)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(
            DesignTokens.Surface.primary(themeManager.resolvedColorScheme)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: -1)
        )
    }
}

// MARK: - 💭 MESSAGE BUBBLE VIEW

struct MessageBubbleView: View {
    let message: ChatMessage
    let onSave: (UUID) -> Void
    let onShare: (UUID) -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
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
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(isFromUser ? .white : DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            ChatBubbleShape(isFromUser: isFromUser)
                                .fill(bubbleColor)
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
                                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
                            )
                        
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
    }
    
    private var bubbleColor: Color {
        switch message.type {
        case .user:
            return DesignTokens.Brand.primary(.light)
        case .assistant:
            return DesignTokens.Surface.messageBubbleIncoming(themeManager.resolvedColorScheme)
        case .error:
            return DesignTokens.Semantic.error.opacity(0.15)
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - 🎨 CHAT BUBBLE SHAPE (WhatsApp-style)

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

// MARK: - 🎬 MESSAGE ACTION BUTTONS

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
                    Text(isSaving ? "Saved" : "Save")
                        .font(DesignTokens.Typography.caption1)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isSaving ? DesignTokens.Brand.secondary : DesignTokens.Brand.primary(.light))
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
                    Text("Share")
                        .font(DesignTokens.Typography.caption1)
                        .fontWeight(.medium)
                }
                .foregroundColor(DesignTokens.Brand.primary(.light))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .stroke(DesignTokens.Brand.primary(.light), lineWidth: 1.5)
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
                        .progressViewStyle(CircularProgressViewStyle(tint: DesignTokens.Brand.primary(.light)))
                        .scaleEffect(0.9)
                    
                    Text("Processing your image...")
                        .font(DesignTokens.Typography.callout)
                        .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                }
                
                if progress > 0 {
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: DesignTokens.Brand.primary(.light)))
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                ChatBubbleShape(isFromUser: false)
                    .fill(DesignTokens.Surface.messageBubbleIncoming(themeManager.resolvedColorScheme))
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
                                .stroke(Color.black.opacity(0.1), lineWidth: 1)
                        )
                        .opacity(isProcessing ? 0.6 : 1.0)
                } else {
                    // Upload prompt
                    VStack(spacing: DesignTokens.Spacing.md) {
                        ZStack {
                            Circle()
                                .fill(DesignTokens.Brand.primary(.light).opacity(0.1))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 36, weight: .medium))
                                .foregroundColor(DesignTokens.Brand.primary(.light))
                        }
                        
                        VStack(spacing: 8) {
                            Text("Start by uploading a photo")
                                .font(DesignTokens.Typography.title3)
                                .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                            
                            Text("Tap here to select an image from your library")
                                .font(DesignTokens.Typography.callout)
                                .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                
                if isProcessing {
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: DesignTokens.Brand.primary(.light)))
                            .scaleEffect(1.2)
                        
                        Text("Uploading...")
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

// MARK: - 🎨 CHAT DESIGN SYSTEM

// ChatDesignSystem has been consolidated into DesignTokens.swift for app-wide consistency

// MARK: - 🎯 TOAST VIEW

enum ToastType {
    case success, error, info
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .success: return DesignTokens.Brand.secondary
        case .error: return DesignTokens.Semantic.error
        case .info: return DesignTokens.Brand.primary(.light)
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
                .foregroundColor(type.color)
            
            Text(message)
                .font(DesignTokens.Typography.callout)
                .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(DesignTokens.Surface.primary(themeManager.resolvedColorScheme))
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, DesignTokens.Spacing.md)
    }
}

// Color(hex:) extension is already defined in Color+DesignSystem.swift

// MARK: - 🎨 PREVIEW

#Preview {
    ChatView(initialPrompt: nil)
}
