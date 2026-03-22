import SwiftUI

struct EPOSView: View {
    @StateObject private var inventoryManager = InventoryManager()
    @State private var cartItems: [CartItem] = []
    @State private var showingPaymentScreen = false
    @State private var selectedPaymentMethod: PaymentMethod?
    @State private var selectedCategory: String = "All"
    
    private let primaryColor = Color(hex: "#3B9F40")
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    // System background that extends into safe area (Apple best practice)
                    Color(.systemGray6)
                        .ignoresSafeArea()
                    
                    HStack(spacing: 0) {
                        // Inventory Grid (Left side - 3/4 of screen)
                        VStack(spacing: 0) {
                            // Top Bar with Path Logo and Category Filter
                            HStack {
                                // New ISV Logo on the left
                                Image("ISVLogo")
                                    .renderingMode(.original)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 40)
                                
                                Spacer()
                                
                                // Category Filter aligned to the right
                                HStack(spacing: 12) {
                                    CategoryButton(title: "All", isSelected: selectedCategory == "All") {
                                        selectedCategory = "All"
                                    }
                                    
                                    ForEach(inventoryManager.categories, id: \.self) { category in
                                        CategoryButton(title: category, isSelected: selectedCategory == category) {
                                            selectedCategory = category
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                            
                            // Inventory Grid
                            ScrollView {
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 16) {
                                    ForEach(filteredItems) { item in
                                        InventoryItemCard(item: item) {
                                            addToCart(item)
                                        }
                                    }
                                }
                                .padding()
                            }
                        }
                        .frame(width: geometry.size.width * 0.75)
                        .frame(maxHeight: .infinity)
                        .background(Color(.systemGray6))
                        .padding(.top, geometry.safeAreaInsets.top)
                        
                        // Cart Summary (Right side - 1/4 of screen)
                        VStack(spacing: 0) {
                            // Top inset bars matching system color (nudge down by 1pt)
                            Color(.systemGray6).frame(height: 1)
                            Color(.systemGray6).frame(height: 2)
                            // Cart title sits above the rounded cart box
                            HStack {
                                Text("Cart")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(primaryColor)
                                Spacer()
                                // Settings button pinned at top-right of the cart column
                                NavigationLink(destination: SettingsView()) {
                                    Image(systemName: "gearshape")
                                        .font(.title2)
                                        .foregroundColor(.primary)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            // Gap between title and rounded cart box
                            Color(.systemGray6).frame(height: 10)
                            // Rounded cart box
                            VStack(spacing: 0) {
                            
                            // Cart Items
                            if cartItems.isEmpty {
                                VStack {
                                    Spacer()
                                    Text("Cart is empty")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                ScrollView {
                                    VStack(spacing: 12) {
                                        ForEach(cartItems) { cartItem in
                                            CartItemRow(cartItem: cartItem) {
                                                removeFromCart(cartItem)
                                            }
                                        }
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                }
                                
                                Spacer()
                                
                                // Total and Checkout
                                VStack(spacing: 16) {
                                    Divider()
                                    
                                    VStack(spacing: 8) {
                                        HStack {
                                            Text("Total:")
                                                .font(.title2)
                                                .fontWeight(.semibold)
                                            Spacer()
                                            Text("£\(String(format: "%.2f", cartTotal))")
                                                .font(.title2)
                                                .fontWeight(.bold)
                                                .foregroundColor(Color(hex: "#FF5252"))
                                        }
                                        
                                        Button(action: {
                                            if !cartItems.isEmpty {
                                                showingPaymentScreen = true
                                            }
                                        }) {
                                            Text("Complete Transaction")
                                                .font(.headline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding()
                                                .background(Color(hex: "#3B9F40"))
                                                .cornerRadius(12)
                                        }
                                    }
                                    .padding()
                                }
                                .background(Color.white)
                            }
                            }
                            .background(Color.white)
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
                            // Bottom inset padding in system color
                            Color(.systemGray6).frame(height: 82)
                        }
                        .frame(width: geometry.size.width * 0.25)
                        .frame(maxHeight: .infinity)
                        .padding(.top, geometry.safeAreaInsets.top)
                        .padding(.trailing, 0)
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .navigationBarHidden(true)
        .sheet(isPresented: $showingPaymentScreen) {
            PaymentView(cartItems: cartItems, totalAmount: cartTotal) {
                cartItems.removeAll()
                showingPaymentScreen = false
            }
        }
    }
    
    private var cartTotal: Double {
        cartItems.reduce(0) { $0 + $1.totalPrice }
    }
    
    private var filteredItems: [InventoryItem] {
        var items = inventoryManager.inventoryItems
        
        // Filter by category
        if selectedCategory != "All" {
            items = items.filter { $0.category == selectedCategory }
        }
        
        return items
    }
    
    private func addToCart(_ item: InventoryItem) {
        if let existingIndex = cartItems.firstIndex(where: { $0.item.id == item.id }) {
            cartItems[existingIndex].quantity += 1
        } else {
            cartItems.append(CartItem(item: item, quantity: 1))
        }
    }
    
    private func removeFromCart(_ cartItem: CartItem) {
        if let index = cartItems.firstIndex(where: { $0.id == cartItem.id }) {
            if cartItems[index].quantity > 1 {
                cartItems[index].quantity -= 1
            } else {
                cartItems.remove(at: index)
            }
        }
    }
}

struct InventoryItemCard: View {
    let item: InventoryItem
    let onTap: () -> Void
    
    private let primaryColor = Color(hex: "#3B9F40")
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Display custom images for items with custom assets, SF Symbol for others
                if ["Coffee", "Tea", "SoftDrink", "Muffin", "Sandwhich", "Cookie", "Cake", "Bagel", "Salad", "Soup", "Chips", "Nuts", "ChocBar"].contains(item.imageName) {
                    Image(item.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .foregroundColor(primaryColor)
                } else {
                    Image(systemName: item.displayImageName)
                        .font(.system(size: 40))
                        .foregroundColor(primaryColor)
                }
                
                VStack(spacing: 4) {
                    Text(item.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text(item.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    Text("£\(String(format: "%.2f", item.price))")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CartItemRow: View {
    let cartItem: CartItem
    let onRemove: () -> Void
    
    private let primaryColor = Color(hex: "#3B9F40")
    
    var body: some View {
        HStack(spacing: 12) {
            // Display custom images for items with custom assets, SF Symbol for others
            if ["Coffee", "Tea", "SoftDrink", "Muffin", "Sandwhich", "Cookie", "Cake", "Bagel", "Salad", "Soup", "Chips", "Nuts", "ChocBar"].contains(cartItem.item.imageName) {
                Image(cartItem.item.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .foregroundColor(primaryColor)
            } else {
                Image(systemName: cartItem.item.displayImageName)
                    .font(.title2)
                    .foregroundColor(primaryColor)
                    .frame(width: 30)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(cartItem.item.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Qty: \(cartItem.quantity)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("£\(String(format: "%.2f", cartItem.totalPrice))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                
                Button(action: onRemove) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// Color extension for hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    private let primaryColor = Color(hex: "#3B9F40")
    
    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : primaryColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? primaryColor : Color(.systemGray6))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.clear : primaryColor, lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    EPOSView()
        .environmentObject(AppTerminalManager(ble: BLEUARTManager.shared))
}

