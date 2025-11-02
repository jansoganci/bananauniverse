//
//  LibraryPreview.swift
//  BananaUniverse
//
//  PREVIEW ONLY - Modern Apple HIG-compliant History screen design
//  Does not affect the actual app. Safe to preview in Xcode.
//
//  Design Philosophy:
//  - Clean, chronological layout with date-grouped sections
//  - Clear visual hierarchy for user's generated results
//  - SF Symbols for visual clarity
//  - 8pt grid spacing system
//  - Theme-aware (light/dark mode)
//

import SwiftUI

// MARK: - Preview: Modern History Screen Structure
struct LibraryPreview: View {
    @Environment(\.colorScheme) var systemColorScheme
    @StateObject private var themeManager = ThemeManager()
    
    private var colorScheme: ColorScheme {
        themeManager.resolvedColorScheme
    }
    
    // Mock data - Recent Activity (3-4 items)
    private let recentActivity = [
        PreviewHistoryItem(title: "Edited Image", icon: "photo.fill", timeAgo: "2 hours ago"),
        PreviewHistoryItem(title: "Generated Description", icon: "sparkles", timeAgo: "5 hours ago"),
        PreviewHistoryItem(title: "Enhanced Photo", icon: "wand.and.stars", timeAgo: "1 day ago"),
        PreviewHistoryItem(title: "Created Text", icon: "doc.text.fill", timeAgo: "2 days ago")
    ]
    
    // Mock data - All History grouped by date
    private let todayItems = [
        PreviewHistoryItem(title: "Enhanced Image", icon: "photo.artframe", timeAgo: "Today, 10:30 AM"),
        PreviewHistoryItem(title: "Generated Response", icon: "sparkles.rectangle.stack.fill", timeAgo: "Today, 9:15 AM")
    ]
    
    private let thisWeekItems = [
        PreviewHistoryItem(title: "Edited Photo", icon: "paintbrush.fill", timeAgo: "2 days ago"),
        PreviewHistoryItem(title: "AI Description", icon: "text.bubble.fill", timeAgo: "3 days ago"),
        PreviewHistoryItem(title: "Processed Image", icon: "photo.on.rectangle", timeAgo: "5 days ago")
    ]
    
    private let earlierItems = [
        PreviewHistoryItem(title: "Generated Content", icon: "doc.text", timeAgo: "1 week ago"),
        PreviewHistoryItem(title: "Enhanced Photo", icon: "wand.and.stars", timeAgo: "2 weeks ago")
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Fixed Header
                UnifiedHeaderBar(
                    title: "History",
                    leftContent: nil,
                    rightContent: nil
                )
                
                // Scrollable Content
                contentView
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
    
    // MARK: - Content View
    
    private var contentView: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.lg) {
                // Recent Activity Section
                recentActivitySection
                    .padding(.top, DesignTokens.Spacing.md)
                
                // All History Section
                allHistorySection
                
                // Clear History Button (Optional)
                clearHistoryButton
                    .padding(.top, DesignTokens.Spacing.sm)
                
                // Bottom padding
                Spacer()
                    .frame(height: DesignTokens.Spacing.xl)
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
        }
    }
    
    // MARK: - Recent Activity Section
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // Section Header
            Text("Recent Activity")
                .font(DesignTokens.Typography.title3)
                .foregroundColor(DesignTokens.Text.primary(colorScheme))
            
            // Horizontal Scroll of Preview Cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignTokens.Spacing.md) {
                    ForEach(recentActivity) { item in
                        PreviewRecentActivityCard(item: item, colorScheme: colorScheme)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
            }
            .padding(.horizontal, -DesignTokens.Spacing.md)
        }
    }
    
    // MARK: - All History Section
    
    private var allHistorySection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // Section Header
            Text("All History")
                .font(DesignTokens.Typography.title3)
                .foregroundColor(DesignTokens.Text.primary(colorScheme))
            
            // Date-grouped History Items
            VStack(spacing: DesignTokens.Spacing.lg) {
                // Today Section
                if !todayItems.isEmpty {
                    historyDateGroup(
                        header: "Today",
                        items: todayItems,
                        colorScheme: colorScheme
                    )
                }
                
                // This Week Section
                if !thisWeekItems.isEmpty {
                    historyDateGroup(
                        header: "This Week",
                        items: thisWeekItems,
                        colorScheme: colorScheme
                    )
                }
                
                // Earlier Section
                if !earlierItems.isEmpty {
                    historyDateGroup(
                        header: "Earlier",
                        items: earlierItems,
                        colorScheme: colorScheme
                    )
                }
            }
        }
    }
    
    // MARK: - History Date Group
    
    @ViewBuilder
    private func historyDateGroup(
        header: String,
        items: [PreviewHistoryItem],
        colorScheme: ColorScheme
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            // Date Header
            Text(header)
                .font(DesignTokens.Typography.subheadline)
                .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.top, DesignTokens.Spacing.xs)
            
            // History Items Card
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    ProfileRow(
                        icon: item.icon,
                        title: item.title,
                        subtitle: item.timeAgo,
                        showChevron: true
                    )
                    
                    if index < items.count - 1 {
                        Divider()
                            .background(DesignTokens.Surface.secondary(colorScheme))
                            .padding(.leading, 56)
                    }
                }
            }
            .background(DesignTokens.Surface.secondary(colorScheme))
            .cornerRadius(DesignTokens.CornerRadius.md)
            .designShadow(DesignTokens.Shadow.sm)
        }
    }
    
    // MARK: - Clear History Button
    
    private var clearHistoryButton: some View {
        Button(action: {
            // Mock action - no functionality
        }) {
            Text("Clear History")
                .font(DesignTokens.Typography.body)
                .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                        .stroke(DesignTokens.Surface.dividerSubtle(colorScheme), lineWidth: 1)
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                                .fill(DesignTokens.Surface.secondary(colorScheme).opacity(0.5))
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Recent Activity Card Component (Preview Only)

struct PreviewRecentActivityCard: View {
    let item: PreviewHistoryItem
    let colorScheme: ColorScheme
    
    // Typography.bodyMedium equivalent
    private var bodyMedium: Font {
        Font.system(size: 17, weight: .medium, design: .default)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            // Thumbnail with icon
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                .fill(
                    LinearGradient(
                        colors: [
                            DesignTokens.Brand.primary(colorScheme).opacity(0.6),
                            DesignTokens.Brand.secondary(colorScheme).opacity(0.4)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .overlay(
                    Image(systemName: item.icon)
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                )
                .designShadow(DesignTokens.Shadow.md)
            
            // Title using Typography.bodyMedium
            Text(item.title)
                .font(bodyMedium)
                .foregroundColor(DesignTokens.Text.primary(colorScheme))
                .lineLimit(2)
                .frame(width: 120, alignment: .leading)
            
            // Time ago
            Text(item.timeAgo)
                .font(DesignTokens.Typography.caption1)
                .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                .frame(width: 120, alignment: .leading)
        }
    }
}

// MARK: - Mock Data Models

struct PreviewHistoryItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let timeAgo: String
}

// MARK: - Xcode Preview

#Preview("LibraryPreview_Light") {
    LibraryPreview()
        .preferredColorScheme(.light)
}

#Preview("LibraryPreview_Dark") {
    LibraryPreview()
        .preferredColorScheme(.dark)
}
