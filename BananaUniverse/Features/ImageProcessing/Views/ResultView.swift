//
//  ResultView.swift
//  BananaUniverse
//
//  Created by AI Assistant on 2025-11-20.
//  Purpose: Display generated image with share/download options
//

import SwiftUI

struct ResultView: View {
    let resultImage: UIImage
    let creditCost: Int
    let modelType: ModelType
    let onDismiss: () -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingShareSheet = false
    @State private var isSaving = false
    @State private var showSavedAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            ZStack(alignment: .leading) {
                UnifiedHeaderBar(
                    title: "Result",
                    leftContent: .empty,
                    rightContent: .none
                )

                // Back button overlay
                Button(action: { onDismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                }
                .padding(.leading, DesignTokens.Spacing.md)
            }

            ScrollView {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    // Result Image
                    ResultImageCard(image: resultImage)

                    // Processing Info
                    ProcessingInfoCard(
                        creditCost: creditCost,
                        modelType: modelType
                    )

                    // Action Buttons
                    VStack(spacing: DesignTokens.Spacing.md) {
                        // Share Button
                        ShareButton(
                            image: resultImage,
                            isPresented: $showingShareSheet
                        )

                        // Download Button
                        DownloadButton(
                            image: resultImage,
                            isSaving: $isSaving,
                            showSavedAlert: $showSavedAlert
                        )

                        // Create Another Button
                        CreateAnotherButton(onDismiss: onDismiss)
                    }
                }
                .padding(DesignTokens.Spacing.md)
            }
            .background(
                DesignTokens.Background.primary(themeManager.resolvedColorScheme)
                    .ignoresSafeArea()
            )
        }
        .navigationBarBackButtonHidden(true)
        .alert("Saved!", isPresented: $showSavedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Image saved to your photo library")
        }
    }
}

// MARK: - Result Image Card

struct ResultImageCard: View {
    let image: UIImage
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(
                    color: Color.black.opacity(0.1),
                    radius: 20,
                    x: 0,
                    y: 10
                )
        }
    }
}

// MARK: - Processing Info Card

struct ProcessingInfoCard: View {
    let creditCost: Int
    let modelType: ModelType
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.lg) {
            // Model Info
            VStack(alignment: .leading, spacing: 4) {
                Text("Model")
                    .font(.caption)
                    .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))

                HStack(spacing: 4) {
                    Image(systemName: modelType.iconName)
                    Text(modelType.displayName)
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
            }

            Spacer()

            // Credit Cost
            VStack(alignment: .trailing, spacing: 4) {
                Text("Cost")
                    .font(.caption)
                    .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))

                HStack(spacing: 4) {
                    Text("\(creditCost)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Text("credits")
                        .font(.caption)
                }
                .foregroundColor(DesignTokens.Brand.accent(themeManager.resolvedColorScheme))
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(DesignTokens.Background.secondary(themeManager.resolvedColorScheme))
        )
    }
}

// MARK: - Share Button

struct ShareButton: View {
    let image: UIImage
    @Binding var isPresented: Bool
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "square.and.arrow.up")
                Text("Share")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(DesignTokens.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(DesignTokens.Brand.accent(themeManager.resolvedColorScheme))
            )
        }
        .sheet(isPresented: $isPresented) {
            ActivityViewController(activityItems: [image])
        }
    }
}

// MARK: - Download Button

struct DownloadButton: View {
    let image: UIImage
    @Binding var isSaving: Bool
    @Binding var showSavedAlert: Bool
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        Button {
            saveToPhotoLibrary()
        } label: {
            HStack(spacing: DesignTokens.Spacing.sm) {
                if isSaving {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: DesignTokens.Brand.accent(themeManager.resolvedColorScheme)))
                    Text("Saving...")
                } else {
                    Image(systemName: "arrow.down.circle")
                    Text("Download")
                }
            }
            .font(.headline)
            .foregroundColor(DesignTokens.Brand.accent(themeManager.resolvedColorScheme))
            .frame(maxWidth: .infinity)
            .padding(DesignTokens.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(DesignTokens.Brand.accent(themeManager.resolvedColorScheme), lineWidth: 2)
            )
        }
        .disabled(isSaving)
    }

    private func saveToPhotoLibrary() {
        isSaving = true

        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSaving = false
            showSavedAlert = true
        }
    }
}

// MARK: - Create Another Button

struct CreateAnotherButton: View {
    let onDismiss: () -> Void
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        Button {
            onDismiss()
        } label: {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "plus.circle")
                Text("Create Another")
            }
            .font(.headline)
            .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
            .frame(maxWidth: .infinity)
            .padding(DesignTokens.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(DesignTokens.Background.secondary(themeManager.resolvedColorScheme))
            )
        }
    }
}

// MARK: - Activity View Controller (Share Sheet)

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ResultView(
            resultImage: UIImage(systemName: "photo")!,
            creditCost: 4,
            modelType: .nanoBananaPro,
            onDismiss: {}
        )
        .environmentObject(ThemeManager())
    }
}
