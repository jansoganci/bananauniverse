import SwiftUI

struct SplashScreen: View {
    @State private var opacity = 0.0
    @State private var scale = 0.8
    
    var body: some View {
        ZStack {
            Color(hex: "121417")
                .ignoresSafeArea()
            
            VStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 120 * (180/1024))
                        .fill(Color(hex: "121417"))
                    
                    FlarioIconShape()
                        .fill(Color(hex: "A4FC3C"))
                }
                .frame(width: 120, height: 120)
                .scaleEffect(scale)
                .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                self.opacity = 1.0
                self.scale = 1.0
            }
        }
    }
}

struct SplashScreen_Previews: PreviewProvider {
    static var previews: some View {
        SplashScreen()
    }
}
