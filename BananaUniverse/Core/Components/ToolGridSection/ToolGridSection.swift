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
                    onTap: { onToolTap(tool) }
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
        // Force 2 columns for all iPhone categories
        return 2
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
            tools: Array(Theme.mockThemes.prefix(6)),
            onToolTap: { _ in },
            category: "main_tools"
        )
        .frame(width: 375)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        
        // iPhone 14 (393px) - Main Tools: 2 columns, Others: 3 columns
        ToolGridSection(
            tools: Array(Theme.mockThemes.prefix(6)),
            onToolTap: { _ in },
            category: "main_tools"
        )
        .frame(width: 393)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        
        // iPhone 14 Plus (428px) - Main Tools: 2 columns, Others: 4 columns
        ToolGridSection(
            tools: Array(Theme.mockThemes.prefix(8)),
            onToolTap: { _ in },
            category: "main_tools"
        )
        .frame(width: 428)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        
        // iPad (768px) - Main Tools: 2 columns, Others: 5+ columns
        ToolGridSection(
            tools: Array(Theme.mockThemes.prefix(10)),
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
