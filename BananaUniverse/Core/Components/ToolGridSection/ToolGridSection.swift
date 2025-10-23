//
//  ToolGridSection.swift
//  BananaUniverse
//
//  Created by AI Assistant on 22.10.2025.
//  Responsive grid wrapper for tool cards
//

import SwiftUI

// MARK: - Tool Grid Section Component
struct ToolGridSection: View {
    // MARK: - Properties
    let tools: [Tool]
    let showPremiumBadge: Bool
    let onToolTap: (Tool) -> Void
    let category: String // New parameter to determine grid layout
    
    // MARK: - State
    @State private var screenWidth: CGFloat = 0
    @State private var lastColumnCount: Int = 0
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        LazyVGrid(
            columns: columns,
            spacing: gridSpacing
        ) {
            ForEach(tools) { tool in
                ToolCard(
                    tool: tool,
                    onTap: { onToolTap(tool) },
                    showPremiumBadge: showPremiumBadge
                )
            }
        }
        .padding(.horizontal, horizontalPadding)
        .onAppear {
            updateScreenWidth()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            // Optimize orientation change handling with debouncing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                updateScreenWidth()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Responsive column calculation based on screen width
    private var columns: [GridItem] {
        let columnCount = calculateColumns(for: screenWidth)
        
        // Only update if column count actually changed
        if columnCount != lastColumnCount {
            DispatchQueue.main.async {
                lastColumnCount = columnCount
            }
        }
        
        return Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: columnCount)
    }
    
    /// Grid spacing based on screen size
    private var gridSpacing: CGFloat {
        switch screenWidth {
        case 0..<390: return DesignTokens.Spacing.xs  // 4pt for compact phones
        case 390..<768: return DesignTokens.Spacing.sm // 8pt for standard phones
        default: return DesignTokens.Spacing.md        // 16pt for iPad
        }
    }
    
    /// Horizontal padding based on screen size
    private var horizontalPadding: CGFloat {
        switch screenWidth {
        case 0..<390: return DesignTokens.Spacing.md  // 16pt for phones
        case 390..<768: return DesignTokens.Spacing.md // 16pt for phones
        default: return DesignTokens.Spacing.lg        // 24pt for iPad
        }
    }
    
    // MARK: - Helper Methods
    
    /// Calculate number of columns based on screen width and category
    private func calculateColumns(for width: CGFloat) -> Int {
        // All sections use 2 columns for consistent layout with new card design
        if category == "main_tools" || category == "pro_looks" || category == "restoration" {
            return 2
        }
        
        // Default responsive behavior for other categories
        switch width {
        case 0..<375: return 2        // iPhone SE (3rd gen) - 375px
        case 375..<390: return 2      // iPhone 13 mini - 390px
        case 390..<428: return 3      // iPhone 14/15/16 - 393px
        case 428..<430: return 4      // iPhone 14/15/16 Plus - 428px
        case 430..<768: return 4      // iPhone 14/15/16 Pro Max - 430px
        default: return 5             // iPad+ - 768px+
        }
    }
    
    /// Update screen width for responsive calculations
    private func updateScreenWidth() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            screenWidth = windowScene.screen.bounds.width
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: DesignTokens.Spacing.lg) {
        // iPhone SE (375px) - Main Tools: 2 columns, Others: 2 columns
        ToolGridSection(
            tools: Array(Tool.mainTools.prefix(6)),
            showPremiumBadge: true,
            onToolTap: { _ in },
            category: "main_tools"
        )
        .frame(width: 375)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        
        // iPhone 14 (393px) - Main Tools: 2 columns, Others: 3 columns
        ToolGridSection(
            tools: Array(Tool.mainTools.prefix(6)),
            showPremiumBadge: true,
            onToolTap: { _ in },
            category: "main_tools"
        )
        .frame(width: 393)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        
        // iPhone 14 Plus (428px) - Main Tools: 2 columns, Others: 4 columns
        ToolGridSection(
            tools: Array(Tool.mainTools.prefix(8)),
            showPremiumBadge: true,
            onToolTap: { _ in },
            category: "main_tools"
        )
        .frame(width: 428)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        
        // iPad (768px) - Main Tools: 2 columns, Others: 5+ columns
        ToolGridSection(
            tools: Array(Tool.mainTools.prefix(10)),
            showPremiumBadge: true,
            onToolTap: { _ in },
            category: "main_tools"
        )
        .frame(width: 768)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    .padding()
    .background(DesignTokens.Background.primary(.light))
    .environmentObject(ThemeManager())
}
