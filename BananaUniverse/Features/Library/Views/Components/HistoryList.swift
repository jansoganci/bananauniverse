//
//  HistoryList.swift
//  noname_banana
//
//  Created by AI Assistant on 16.10.2025.
//  History list component for Library screen
//

import SwiftUI

// MARK: - History List
struct HistoryList: View {
    let items: [HistoryItem]
    let groupedItems: [HistoryDateGroup]
    let isRefreshing: Bool
    let onRefresh: () async -> Void
    let onItemTap: (HistoryItem) -> Void
    let onSelect: (HistoryItem) -> Void
    let onRerun: (HistoryItem) async -> Void
    let onShare: (HistoryItem) -> Void
    let onDownload: (HistoryItem) async -> Void
    let onDelete: (HistoryItem) async -> Void
    
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        // MARK: - Phase 1 Navigation & Visual Foundation
        ScrollView {
            historyContent
        }
        .refreshable {
            await onRefresh()
        }
        .accessibilityLabel("History list")
        .accessibilityHint("Swipe down to refresh")
    }
    
    // MARK: - Content View (Extracted for Phase 3)
    
    var historyContent: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // All History Section
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                // Section Header
                Text("All History")
                    .font(DesignTokens.Typography.title3)
                    .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                
                // MARK: - Phase 2 Date Grouping
                // Date-grouped sections
                VStack(spacing: DesignTokens.Spacing.lg) {
                    ForEach(groupedItems, id: \.header) { group in
                        historyDateGroup(
                            header: group.header,
                            items: group.items
                        )
                    }
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.top, DesignTokens.Spacing.md)
        .padding(.bottom, DesignTokens.Spacing.xl)
    }
    
    // MARK: - Phase 2 Date Grouping
    
    @ViewBuilder
    private func historyDateGroup(
        header: String,
        items: [HistoryItem]
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            // Date Header
            Text(header)
                .font(DesignTokens.Typography.subheadline)
                .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.top, DesignTokens.Spacing.xs)
            
            // History Items Card
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    HistoryItemRow(
                        item: item,
                        onTap: { onItemTap(item) },
                        onSelect: { onSelect(item) },
                        onRerun: { Task { await onRerun(item) } },
                        onShare: { onShare(item) },
                        onDownload: { Task { await onDownload(item) } },
                        onDelete: { Task { await onDelete(item) } }
                    )
                    
                    if index < items.count - 1 {
                        Divider()
                            .background(DesignTokens.Surface.secondary(themeManager.resolvedColorScheme))
                            .padding(.leading, 80) // Match thumbnail width + padding
                    }
                }
            }
            .background(DesignTokens.Surface.secondary(themeManager.resolvedColorScheme))
            .cornerRadius(DesignTokens.CornerRadius.md)
            .designShadow(DesignTokens.Shadow.sm)
        }
    }
}

// MARK: - History List Content View (Extracted for Phase 3)

struct HistoryListContentView: View {
    let items: [HistoryItem]
    let groupedItems: [HistoryDateGroup]
    @EnvironmentObject var themeManager: ThemeManager
    let onItemTap: (HistoryItem) -> Void
    let onSelect: (HistoryItem) -> Void
    let onRerun: (HistoryItem) async -> Void
    let onShare: (HistoryItem) -> Void
    let onDownload: (HistoryItem) async -> Void
    let onDelete: (HistoryItem) async -> Void
    
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // All History Section
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                // Section Header
                Text("All History")
                    .font(DesignTokens.Typography.title3)
                    .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                
                // MARK: - Phase 2 Date Grouping
                // Date-grouped sections
                VStack(spacing: DesignTokens.Spacing.lg) {
                    ForEach(groupedItems, id: \.header) { group in
                        historyDateGroup(
                            header: group.header,
                            items: group.items
                        )
                    }
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.top, DesignTokens.Spacing.md)
        .padding(.bottom, DesignTokens.Spacing.xl)
    }
    
    // MARK: - Phase 2 Date Grouping
    
    @ViewBuilder
    private func historyDateGroup(
        header: String,
        items: [HistoryItem]
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            // Date Header
            Text(header)
                .font(DesignTokens.Typography.subheadline)
                .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.top, DesignTokens.Spacing.xs)
            
            // History Items Card
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    HistoryItemRow(
                        item: item,
                        onTap: { onItemTap(item) },
                        onSelect: { onSelect(item) },
                        onRerun: { Task { await onRerun(item) } },
                        onShare: { onShare(item) },
                        onDownload: { Task { await onDownload(item) } },
                        onDelete: { Task { await onDelete(item) } }
                    )
                    
                    if index < items.count - 1 {
                        Divider()
                            .background(DesignTokens.Surface.secondary(themeManager.resolvedColorScheme))
                            .padding(.leading, 80) // Match thumbnail width + padding
                    }
                }
            }
            .background(DesignTokens.Surface.secondary(themeManager.resolvedColorScheme))
            .cornerRadius(DesignTokens.CornerRadius.md)
            .designShadow(DesignTokens.Shadow.sm)
        }
    }
}
