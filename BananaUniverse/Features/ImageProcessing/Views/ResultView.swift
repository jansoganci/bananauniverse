//
//  ResultView.swift
//  BananaUniverse
//
//  Created by AI Assistant on 2025-11-20.
//  Purpose: Display generated image with share/download options
//

import SwiftUI
import UIKit

struct ResultView: View {
    let resultImage: UIImage
    let creditCost: Int
    let modelType: ModelType
    let onDismiss: () -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewModel: ImageProcessingViewModel
    
    @State private var showingShareSheet = false
    @State private var isSaving = false
    @State private var showSavedAlert = false
    @State private var showWarningBanner = true

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
                    // ✅ Compact Warning Banner
                    if !viewModel.isImageSaved {
                        WarningBanner(isVisible: $showWarningBanner)
                    }
                    
                    // Result Image
                    ResultImageCard(image: resultImage)

                    // Processing Info
                    ProcessingInfoCard(
                        creditCost: creditCost,
                        modelType: modelType
                    )

                    // Create Another Button (in scrollable area)
                    CreateAnotherButton(onDismiss: onDismiss)
                        .padding(.bottom, 100) // Space for sticky buttons
                }
                .padding(DesignTokens.Spacing.md)
            }
            .background(
                DesignTokens.Background.primary(themeManager.resolvedColorScheme)
                    .ignoresSafeArea()
            )
            
            // Sticky Action Buttons at Bottom
            VStack(spacing: 0) {
                Divider()
                    .background(DesignTokens.Surface.dividerSubtle(themeManager.resolvedColorScheme))
                
                VStack(spacing: DesignTokens.Spacing.sm) {
                    // Share and Download buttons in horizontal row
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        // Share Button
                        ShareButton(
                            image: resultImage,
                            isPresented: $showingShareSheet
                        )
                        
                        // Download Button
                        DownloadButton(
                            isSaving: $isSaving,
                            showSavedAlert: $showSavedAlert
                        )
                    }
                }
                .padding(DesignTokens.Spacing.md)
                .background(
                    DesignTokens.Background.primary(themeManager.resolvedColorScheme)
                        .ignoresSafeArea(edges: .bottom)
                )
            }
        }
        .navigationBarBackButtonHidden(true)
        .onDisappear {
            handlePageClose()
        }
        .alert("Saved!", isPresented: $showSavedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Image saved to your photo library")
        }
    }
    
    private func handlePageClose() {
        // If closed without saving, delete from server immediately
        if !viewModel.isImageSaved, let jobId = viewModel.resultJobId {
            Task {
                do {
                    try await SupabaseService.shared.deleteProcessedImage(jobId: jobId)
                    #if DEBUG
                    print("🗑️ [ResultView] Image deleted from server on close")
                    #endif
                } catch {
                    print("⚠️ [ResultView] Failed to delete image: \(error)")
                }
            }
        }
    }
}

// MARK: - Download Button

struct DownloadButton: View {
    @Binding var isSaving: Bool
    @Binding var showSavedAlert: Bool
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewModel: ImageProcessingViewModel

    var body: some View {
        Button {
            saveImage()
        } label: {
            HStack(spacing: DesignTokens.Spacing.sm) {
                if isSaving {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: DesignTokens.Brand.accent(themeManager.resolvedColorScheme)))
                    Text("Saving...")
                } else {
                    if viewModel.isImageSaved {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Saved")
                    } else {
                        Image(systemName: "arrow.down.circle")
                        Text("Download")
                    }
                }
            }
            .font(.headline)
            .foregroundColor(viewModel.isImageSaved ? .green : DesignTokens.Brand.accent(themeManager.resolvedColorScheme))
            .frame(maxWidth: .infinity)
            .padding(DesignTokens.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(viewModel.isImageSaved ? Color.green : DesignTokens.Brand.accent(themeManager.resolvedColorScheme), lineWidth: 2)
            )
        }
        .disabled(isSaving || viewModel.isImageSaved)
    }

    private func saveImage() {
        isSaving = true
        
        Task {
            await viewModel.saveImageToDevice()
            
            await MainActor.run {
                isSaving = false
                if viewModel.isImageSaved {
                    showSavedAlert = true
                }
            }
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

// MARK: - Result Image Card

struct ResultImageCard: View {
    let image: UIImage
    
    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .cornerRadius(12)
            .shadow(radius: 4)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Processing Info Card

struct ProcessingInfoCard: View {
    let creditCost: Int
    let modelType: ModelType
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Model used")
                    .font(.caption)
                    .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                Text(modelType.displayName)
                    .font(.headline)
                    .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("Cost")
                    .font(.caption)
                    .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(DesignTokens.Brand.accent(themeManager.resolvedColorScheme))
                    Text("\(creditCost)")
                        .font(.headline)
                        .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                }
            }
        }
        .padding()
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
            .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
            .frame(maxWidth: .infinity)
            .padding(DesignTokens.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(DesignTokens.Background.secondary(themeManager.resolvedColorScheme))
            )
        }
        .sheet(isPresented: $isPresented) {
            ActivityViewController(activityItems: [image])
        }
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
