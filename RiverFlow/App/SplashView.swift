import SwiftUI

struct SplashOverlay: View {
    @Binding var isPresented: Bool
    @State private var opacity: Double = 1.0
    @State private var scale: CGFloat = 1.0
    
    static var hasShownSplashInThisSession = false

    var body: some View {
        if isPresented {
            ZStack {
                Color(NSColor.windowBackgroundColor)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    Image("AppLogo")
                        .font(.system(size: 72))
                        .foregroundColor(.blue)
                        .scaleEffect(scale)
                    
                    Text("RiverFlow")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    
                    Text("by ToriYukari")
                        .font(.system(size: 18, design: .rounded))
                    
                    ProgressView()
                        .controlSize(.small)
                        .padding(.top, 8)
                }
            }
            .opacity(opacity)
            .onAppear {
                Self.hasShownSplashInThisSession = true
                SoundEffects.playSoundEffect(name: "riverflow")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeOut(duration: 0.4)) {
                        opacity = 0.0
                        scale = 0.1
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        isPresented = false
                    }
                }
            }
        }
    }
}
