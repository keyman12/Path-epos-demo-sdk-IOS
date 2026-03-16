import SwiftUI

struct PathLogoView: View {
    let size: CGFloat
    let showTagline: Bool
    
    private let primaryColor = Color(hex: "#3B9F40")
    private let iconColor = Color(red: 1.0, green: 0.4, blue: 0.3) // Light red/coral
    
    init(size: CGFloat = 200, showTagline: Bool = true) {
        self.size = size
        self.showTagline = showTagline
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // Icon (shopping bag/padlock)
                ZStack {
                    // Bag body
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.clear)
                        .stroke(iconColor, lineWidth: 3)
                        .frame(width: size * 0.3, height: size * 0.4)
                    
                    // Bag handle
                    RoundedRectangle(cornerRadius: 4)
                        .fill(iconColor)
                        .frame(width: size * 0.15, height: size * 0.08)
                        .offset(y: -size * 0.25)
                }
                
                // Text "Path"
                VStack(alignment: .leading, spacing: 0) {
                    Text("P")
                        .font(.system(size: size * 0.4, weight: .bold, design: .default))
                        .foregroundColor(primaryColor)
                    
                    Text("ath")
                        .font(.system(size: size * 0.3, weight: .bold, design: .default))
                        .foregroundColor(primaryColor)
                }
            }
            
            if showTagline {
                Text("COMMERCE FOR PLATFORMS")
                    .font(.system(size: size * 0.08, weight: .medium, design: .default))
                    .foregroundColor(Color(.systemGray))
                    .tracking(1.0)
            }
        }
    }
}

struct PathLogoCompactView: View {
    let size: CGFloat
    
    private let primaryColor = Color(hex: "#3B9F40")
    private let iconColor = Color(red: 1.0, green: 0.4, blue: 0.3)
    
    var body: some View {
        HStack(spacing: 8) {
            // Compact icon - updated to match uploaded logo
            ZStack {
                // Bag body with rounded corners
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.clear)
                    .stroke(Color.black, lineWidth: 2)
                    .frame(width: size * 0.25, height: size * 0.35)
                
                // Arrow inside bag
                Image(systemName: "arrow.up.left")
                    .font(.system(size: size * 0.15))
                    .foregroundColor(.black)
                    .offset(y: size * 0.05)
                
                // Bag handle/padlock
                RoundedRectangle(cornerRadius: 4)
                    .fill(iconColor)
                    .frame(width: size * 0.12, height: size * 0.06)
                    .offset(y: -size * 0.2)
            }
            
            Text("Path")
                .font(.system(size: size * 0.35, weight: .bold, design: .default))
                .foregroundColor(primaryColor)
        }
    }
}



#Preview {
    VStack(spacing: 40) {
        PathLogoView(size: 200)
        PathLogoView(size: 150, showTagline: false)
        PathLogoCompactView(size: 100)
    }
    .padding()
    .background(Color.black)
}
