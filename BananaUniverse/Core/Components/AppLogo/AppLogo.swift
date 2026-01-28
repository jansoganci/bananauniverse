import SwiftUI

struct FlarioIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scaleX = rect.width / 1024
        let scaleY = rect.height / 1024
        
        var path = Path()
        
        path.move(to: CGPoint(x: 362 * scaleX, y: 256 * scaleY))
        
        // Top bar
        path.addLine(to: CGPoint(x: 682 * scaleX, y: 256 * scaleY))
        path.addQuadCurve(to: CGPoint(x: 702 * scaleX, y: 276 * scaleY), control: CGPoint(x: 702 * scaleX, y: 256 * scaleY))
        path.addLine(to: CGPoint(x: 702 * scaleX, y: 344 * scaleY))
        path.addQuadCurve(to: CGPoint(x: 682 * scaleX, y: 364 * scaleY), control: CGPoint(x: 702 * scaleX, y: 364 * scaleY))
        
        // Back to stem
        path.addLine(to: CGPoint(x: 462 * scaleX, y: 364 * scaleY))
        
        // Down to middle bar
        path.addLine(to: CGPoint(x: 462 * scaleX, y: 448 * scaleY))
        path.addLine(to: CGPoint(x: 642 * scaleX, y: 448 * scaleY))
        path.addQuadCurve(to: CGPoint(x: 662 * scaleX, y: 468 * scaleY), control: CGPoint(x: 662 * scaleX, y: 448 * scaleY))
        path.addLine(to: CGPoint(x: 662 * scaleX, y: 536 * scaleY))
        path.addQuadCurve(to: CGPoint(x: 642 * scaleX, y: 556 * scaleY), control: CGPoint(x: 662 * scaleX, y: 556 * scaleY))
        
        // Back to stem
        path.addLine(to: CGPoint(x: 462 * scaleX, y: 556 * scaleY))
        
        // Down to bottom
        path.addLine(to: CGPoint(x: 462 * scaleX, y: 748 * scaleY))
        path.addQuadCurve(to: CGPoint(x: 442 * scaleX, y: 768 * scaleY), control: CGPoint(x: 462 * scaleX, y: 768 * scaleY))
        path.addLine(to: CGPoint(x: 362 * scaleX, y: 768 * scaleY))
        path.addQuadCurve(to: CGPoint(x: 342 * scaleX, y: 748 * scaleY), control: CGPoint(x: 342 * scaleX, y: 768 * scaleY))
        
        // Back up to top
        path.addLine(to: CGPoint(x: 342 * scaleX, y: 276 * scaleY))
        path.addQuadCurve(to: CGPoint(x: 362 * scaleX, y: 256 * scaleY), control: CGPoint(x: 342 * scaleX, y: 256 * scaleY))
        
        path.closeSubpath()
        
        return path
    }
}

struct AppLogo: View {
    let size: CGFloat
    let showText: Bool
    @Environment(\.colorScheme) var colorScheme
    
    init(size: CGFloat = 40, showText: Bool = false) {
        self.size = size
        self.showText = showText
    }
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: size * (180/1024))
                    .fill(Color(hex: "121417"))
                
                FlarioIconShape()
                    .fill(Color(hex: "A4FC3C"))
            }
            .frame(width: size, height: size)
            .shadow(color: Color.black.opacity(0.2), radius: size * 0.1, x: 0, y: size * 0.05)
            
            if showText {
                Text("core_app_name".localized)
                    .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                    .foregroundColor(DesignTokens.Brand.primary(colorScheme))
            }
        }
    }
}

struct AppLogo_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            AppLogo(size: 30)
            AppLogo(size: 50, showText: true)
            AppLogo(size: 80, showText: true)
        }
        .padding()
    }
}
