import SwiftUI

// This is a reference view for the app icon design
// To create the actual app icon:
// 1. Take a screenshot of this view
// 2. Resize to 1024x1024 pixels
// 3. Save as PNG
// 4. Replace the AppIcon.appiconset/AppIcon.png file

struct AppIconView: View {
    var body: some View {
        ZStack {
            // Background - use the Path brand color
            Color(hex: "#3B9F40")
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Path Logo
                HStack(spacing: 16) {
                    // Icon (shopping bag)
                    ZStack {
                        // Bag body
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.clear)
                            .stroke(Color.white, lineWidth: 4)
                            .frame(width: 80, height: 100)
                        
                        // Bag handle
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white)
                            .frame(width: 40, height: 16)
                            .offset(y: -50)
                    }
                    
                    // Text "Path"
                    VStack(alignment: .leading, spacing: 0) {
                        Text("P")
                            .font(.system(size: 80, weight: .bold, design: .default))
                            .foregroundColor(.white)
                        
                        Text("ath")
                            .font(.system(size: 60, weight: .bold, design: .default))
                            .foregroundColor(.white)
                    }
                }
                
                // Tagline
                Text("COMMERCE FOR PLATFORMS")
                    .font(.system(size: 16, weight: .medium, design: .default))
                    .foregroundColor(.white.opacity(0.8))
                    .tracking(2.0)
            }
        }
        .frame(width: 1024, height: 1024)
        .scaleEffect(0.1) // Scale down for preview
    }
}

#Preview {
    AppIconView()
        .frame(width: 200, height: 200)
        .scaleEffect(1.0)
}



