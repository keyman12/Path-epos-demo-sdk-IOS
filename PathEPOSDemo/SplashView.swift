import SwiftUI

struct SplashView: View {
    @EnvironmentObject private var terminal: AppTerminalManager
    @State private var isActive = false
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0.0
    
    private let primaryColor = Color(hex: "#3B9F40")
    
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Path Logo - using uploaded image
                Image("PathLogo") // Make sure to add your logo to Assets.xcassets
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300, height: 150)
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                
                Spacer()
                
                Text("Loading...")
                    .font(.title3)
                    .foregroundColor(.white)
                    .opacity(logoOpacity)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    isActive = true
                }
            }
        }
        .fullScreenCover(isPresented: $isActive) {
            ContentView()
                .environmentObject(terminal)
        }
    }
}



#Preview {
    SplashView()
        .environmentObject(AppTerminalManager(ble: BLEUARTManager.shared))
}
