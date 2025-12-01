//
//  UIComponents.swift
//  noname_banana
//
//  Created by AI Assistant on 14.10.2025.
//  Reusable UI Components - Steve Jobs Level Quality
//

import SwiftUI

// MARK: - 🎯 PRIMARY BUTTON COMPONENT

/// **Steve Jobs Philosophy**: "Every button should feel like it wants to be pressed"
struct PrimaryButton: View {
    let title: String
    let icon: String?
    let isLoading: Bool
    let isEnabled: Bool
    let accentColor: ((ColorScheme) -> Color)?
    let action: () -> Void
    
    @State private var isPressed = false
    @Environment(\.colorScheme) var colorScheme
    
    init(
        title: String,
        icon: String? = nil,
        isLoading: Bool = false,
        isEnabled: Bool = true,
        accentColor: ((ColorScheme) -> Color)? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.accentColor = accentColor
        self.action = action
    }
    
    private var buttonColor: Color {
        accentColor?(colorScheme) ?? DesignTokens.Brand.primary(colorScheme)
    }
    
    var body: some View {
        Button(action: {
            if isEnabled && !isLoading {
                // Haptic feedback for premium feel
                DesignTokens.Haptics.impact(.medium)
                action()
            }
        }) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                }
                
                Text(title)
                    .font(DesignTokens.Typography.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(isEnabled ? DesignTokens.Text.onBrand(colorScheme) : DesignTokens.Text.quaternary(colorScheme))
            .frame(maxWidth: .infinity)
            .frame(height: DesignTokens.Layout.buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                    .fill(isEnabled ? buttonColor : DesignTokens.Background.tertiary(colorScheme))
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled || isLoading)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if isEnabled {
                        withAnimation(DesignTokens.Animation.quick) {
                            isPressed = true
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(DesignTokens.Animation.quick) {
                        isPressed = false
                    }
                }
        )
    }
}

// MARK: - 🎯 SECONDARY BUTTON COMPONENT

struct SecondaryButton: View {
    let title: String
    let icon: String?
    let isLoading: Bool
    let isEnabled: Bool
    let accentColor: ((ColorScheme) -> Color)?
    let action: () -> Void
    
    @State private var isPressed = false
    @Environment(\.colorScheme) var colorScheme
    
    init(
        title: String,
        icon: String? = nil,
        isLoading: Bool = false,
        isEnabled: Bool = true,
        accentColor: ((ColorScheme) -> Color)? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.accentColor = accentColor
        self.action = action
    }
    
    private var buttonColor: Color {
        accentColor?(colorScheme) ?? DesignTokens.Brand.primary(colorScheme)
    }
    
    var body: some View {
        Button(action: {
            if isEnabled && !isLoading {
                DesignTokens.Haptics.impact(.light)
                action()
            }
        }) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: buttonColor))
                        .scaleEffect(0.8)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                }
                
                Text(title)
                    .font(DesignTokens.Typography.headline)
                    .fontWeight(.medium)
            }
            .foregroundColor(isEnabled ? buttonColor : DesignTokens.Text.quaternary(colorScheme))
            .frame(maxWidth: .infinity)
            .frame(height: DesignTokens.Layout.buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                    .stroke(
                        isEnabled ? buttonColor : DesignTokens.Text.quaternary(colorScheme),
                        lineWidth: 1.5
                    )
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                            .fill(DesignTokens.Background.secondary(colorScheme))
                    )
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled || isLoading)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if isEnabled {
                        withAnimation(DesignTokens.Animation.quick) {
                            isPressed = true
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(DesignTokens.Animation.quick) {
                        isPressed = false
                    }
                }
        )
    }
}

// MARK: - 🎯 CARD COMPONENT

/// **Steve Jobs Rule**: "Cards should feel like they're floating"
struct AppCard<Content: View>: View {
    let content: Content
    let onTap: (() -> Void)?
    
    @State private var isPressed = false
    @Environment(\.colorScheme) var colorScheme
    
    init(
        onTap: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.onTap = onTap
        self.content = content()
    }
    
    var body: some View {
        Group {
            if let onTap = onTap {
                Button(action: {
                    DesignTokens.Haptics.impact(.light)
                    onTap()
                }) {
                    cardContent
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                cardContent
            }
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .simultaneousGesture(
            onTap != nil ? DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(DesignTokens.Animation.quick) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(DesignTokens.Animation.quick) {
                        isPressed = false
                    }
                } : nil
        )
    }
    
    private var cardContent: some View {
        content
            .padding(DesignTokens.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                    .fill(DesignTokens.Surface.primary(colorScheme))
                    .designShadow(DesignTokens.Shadow.md)
            )
    }
}

// MARK: - 🎯 INPUT FIELD COMPONENT

/// **Steve Jobs Philosophy**: "Input should feel natural and responsive"
struct AppTextField: View {
    @Binding var text: String
    let placeholder: String
    let icon: String?
    let isSecure: Bool
    let keyboardType: UIKeyboardType
    let onSubmit: (() -> Void)?
    
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) var colorScheme
    
    init(
        text: Binding<String>,
        placeholder: String,
        icon: String? = nil,
        isSecure: Bool = false,
        keyboardType: UIKeyboardType = .default,
        onSubmit: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.icon = icon
        self.isSecure = isSecure
        self.keyboardType = keyboardType
        self.onSubmit = onSubmit
    }
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isFocused ? DesignTokens.Brand.primary(colorScheme) : DesignTokens.Text.tertiary(colorScheme))
            }
            
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(DesignTokens.Typography.body)
            .foregroundColor(DesignTokens.Text.primary(colorScheme))
            .keyboardType(keyboardType)
            .focused($isFocused)
            .onSubmit {
                onSubmit?()
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .frame(height: DesignTokens.Layout.inputHeight)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                .stroke(
                    isFocused ? DesignTokens.Brand.primary(colorScheme) : DesignTokens.Background.tertiary(colorScheme),
                    lineWidth: isFocused ? 2 : 1
                )
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                        .fill(DesignTokens.Background.secondary(colorScheme))
                )
        )
        .animation(DesignTokens.Animation.quick, value: isFocused)
    }
}

// MARK: - 🎯 LOADING INDICATOR COMPONENT

struct AppLoadingIndicator: View {
    let message: String
    let progress: Double?
    @Environment(\.colorScheme) var colorScheme
    
    init(message: String, progress: Double? = nil) {
        self.message = message
        self.progress = progress
    }
    
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: DesignTokens.Brand.primary(colorScheme)))
                .scaleEffect(1.2)
            
            Text(message)
                .font(DesignTokens.Typography.callout)
                .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                .multilineTextAlignment(.center)
            
            if let progress = progress {
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: DesignTokens.Brand.primary(colorScheme)))
                    .frame(height: 4)
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                .fill(DesignTokens.Surface.primary(colorScheme))
                .designShadow(DesignTokens.Shadow.lg)
        )
    }
}

// MARK: - 🎯 QUOTA BADGE COMPONENT

struct QuotaBadge: View {
    let remaining: Int
    let isPro: Bool
    let onTap: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                if isPro {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 12, weight: .semibold))
                }
                
                Text(isPro ? "PRO" : "\(remaining) Free")
                    .font(DesignTokens.Typography.caption1)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(
                Capsule()
                    .fill(isPro ? DesignTokens.Brand.accent(.light) : DesignTokens.Brand.secondary(colorScheme))
            )
            .overlay(
                Capsule()
                    .stroke(
                        colorScheme == .dark
                            ? Color.white.opacity(0.15)
                            : Color.clear,
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 🎯 TOAST NOTIFICATION COMPONENT

struct ToastNotification: View {
    let message: String
    let type: ToastType
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) var colorScheme
    
    enum ToastType {
        case success
        case error
        case info
        
        func color(_ colorScheme: ColorScheme) -> Color {
            switch self {
            case .success: return DesignTokens.Semantic.success(colorScheme)
            case .error: return DesignTokens.Semantic.error(colorScheme)
            case .info: return DesignTokens.Semantic.info(colorScheme)
            }
        }
        
        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "xmark.circle.fill"
            case .info: return "info.circle.fill"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: type.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(type.color(colorScheme))
            
            Text(message)
                .font(DesignTokens.Typography.callout)
                .foregroundColor(DesignTokens.Text.primary(colorScheme))
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                .fill(DesignTokens.Surface.primary(colorScheme))
                .designShadow(DesignTokens.Shadow.lg)
        )
        .padding(.horizontal, DesignTokens.Spacing.md)
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        ))
        .onAppear {
            // Auto-dismiss after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(DesignTokens.Animation.smooth) {
                    isPresented = false
                }
            }
        }
    }
}

// MARK: - 🎯 PREVIEW HELPERS

#Preview("Buttons") {
    VStack(spacing: DesignTokens.Spacing.lg) {
        PrimaryButton(title: "Generate Image", icon: "sparkles", action: {})
        SecondaryButton(title: "Save to Photos", icon: "square.and.arrow.down", action: {})
        PrimaryButton(title: "Processing...", icon: nil, isLoading: true, action: {})
    }
    .padding()
    .background(DesignTokens.Background.primary(.light))
}

#Preview("Cards") {
    VStack(spacing: DesignTokens.Spacing.md) {
        AppCard(onTap: {}) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("Tool Card")
                    .font(DesignTokens.Typography.headline)
                Text("This is a sample card content")
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(DesignTokens.Text.secondary(.light))
            }
        }
        
        AppCard {
            Text("Static Card")
                .font(DesignTokens.Typography.headline)
        }
    }
    .padding()
    .background(DesignTokens.Background.primary(.light))
}
