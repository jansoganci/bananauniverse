//
//  LibraryView.swift
//  noname_banana
//
//  Created by AI Assistant on 13.10.2025.
//

import SwiftUI

struct LibraryView: View {
    @StateObject private var viewModel = LibraryViewModel()
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedImageURL: URL? = nil
    
    var body: some View {
        // MARK: - Phase 1 Navigation & Visual Foundation
        NavigationStack {
            VStack(spacing: 0) {
                // Header Bar
                UnifiedHeaderBar(
                    title: "library_title".localized
                )
                .accessibilityAddTraits(.isHeader)
                
                // Main Content
                if viewModel.isLoading && viewModel.historyItems.isEmpty {
                    // Loading State
                    LoadingView()
                } else if viewModel.showingError && viewModel.historyItems.isEmpty {
                    // Error State
                    ErrorView(
                        message: viewModel.errorMessage ?? "library_error_generic".localized,
                        onRetry: {
                            Task {
                                await viewModel.loadHistory()
                            }
                        }
                    )
                } else if viewModel.historyItems.isEmpty {
                    // Empty State
                    EmptyHistoryView()
                } else {
                    // MARK: - Phase 3 Recent Activity Section
                    ScrollView {
                        VStack(spacing: DesignTokens.Spacing.lg) {
                            // Recent Activity Section
                            if !viewModel.recentActivityItems.isEmpty {
                                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                                    // Section Header
                                    Text("library_recent_activity".localized)
                                        .font(DesignTokens.Typography.title3)
                                        .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                                    
                                    // Horizontal Scroll of Preview Cards
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: DesignTokens.Spacing.md) {
                                            ForEach(viewModel.recentActivityItems.prefix(4)) { item in
                                                RecentActivityCard(item: item) {
                                                    if let resultURL = item.resultURL {
                                                        selectedImageURL = resultURL
                                                    }
                                                    viewModel.navigateToResult(item)
                                                }
                                            }
                                        }
                                        .padding(.horizontal, DesignTokens.Spacing.md)
                                    }
                                    .padding(.horizontal, -DesignTokens.Spacing.md)
                                }
                                .padding(.top, DesignTokens.Spacing.md)
                                .padding(.horizontal, DesignTokens.Spacing.md)
                            }
                            
                            // History List Content
                            HistoryListContentView(
                                items: viewModel.historyItems,
                                groupedItems: viewModel.groupedHistoryItems,
                                onItemTap: { item in viewModel.navigateToResult(item) },
                                onSelect: { item in
                                    if let resultURL = item.resultURL {
                                        selectedImageURL = resultURL
                                    }
                                },
                                onRerun: { item in await viewModel.rerunJob(item) },
                                onShare: { item in viewModel.shareResult(item) },
                                onDownload: { item in await viewModel.downloadImage(item) },
                                onDelete: { item in 
                                    viewModel.itemToDelete = item
                                    viewModel.showingDeleteConfirmation = true
                                }
                            )
                            .environmentObject(themeManager)
                        }
                    }
                    .refreshable {
                        await viewModel.refreshHistory()
                    }
                }
            }
            .background(DesignTokens.Background.primary(themeManager.resolvedColorScheme))
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear {
            Task {
                await viewModel.loadHistory()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Refresh data when app comes to foreground
            Task {
                await viewModel.refreshHistory()
            }
        }
        .alert("chat_error_title".localized, isPresented: $viewModel.showingError) {
            Button("chat_ok".localized) { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "library_error_generic".localized)
        }
        .alert("library_delete_title".localized, isPresented: $viewModel.showingDeleteConfirmation) {
            Button("chat_cancel".localized, role: .cancel) { viewModel.cancelDelete() }
            Button("library_action_delete".localized, role: .destructive) { viewModel.confirmDelete() }
        } message: {
            Text("library_delete_confirm".localized)
        }
        .sheet(isPresented: $viewModel.showingShareSheet) {
            if let item = viewModel.selectedItem {
                ShareSheet(activityItems: [item.resultURL?.absoluteString ?? ""])
            }
        }
        .sheet(isPresented: Binding<Bool>(
            get: { selectedImageURL != nil },
            set: { if !$0 { selectedImageURL = nil } }
        )) {
            if let url = selectedImageURL {
                ImageDetailView(imageURL: url)
            }
        }
    }
}


#Preview {
    LibraryView()
        .environmentObject(ThemeManager())
}
