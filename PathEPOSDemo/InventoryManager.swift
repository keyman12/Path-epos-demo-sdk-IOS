import Foundation
import SwiftUI

class InventoryManager: ObservableObject {
    @Published var inventoryItems: [InventoryItem] = []
    @Published var categories: [String] = []
    
    init() {
        loadSampleInventory()
    }
    
    private func loadSampleInventory() {
        inventoryItems = [
            // Beverages
            InventoryItem(name: "Espresso", description: "Single shot of premium espresso", price: 3.50, imageName: "Coffee", category: "Beverages"),
            InventoryItem(name: "Cappuccino", description: "Espresso with steamed milk foam", price: 4.99, imageName: "Coffee", category: "Beverages"),
            InventoryItem(name: "Latte", description: "Espresso with steamed milk", price: 4.50, imageName: "Coffee", category: "Beverages"),
            InventoryItem(name: "Americano", description: "Espresso with hot water", price: 3.99, imageName: "Coffee", category: "Beverages"),
            InventoryItem(name: "Tea", description: "Premium loose leaf tea", price: 2.99, imageName: "Tea", category: "Beverages"),
            InventoryItem(name: "Hot Chocolate", description: "Rich hot chocolate with cream", price: 4.25, imageName: "Coffee", category: "Beverages"),
            InventoryItem(name: "Iced Coffee", description: "Cold brewed coffee over ice", price: 4.75, imageName: "Coffee", category: "Beverages"),
            InventoryItem(name: "Lemonade", description: "Fresh squeezed lemonade", price: 3.25, imageName: "SoftDrink", category: "Beverages"),
            
            // Food
            InventoryItem(name: "Croissant", description: "Buttery French croissant", price: 3.99, imageName: "Muffin", category: "Food"),
            InventoryItem(name: "Sandwich", description: "Ham and cheese on artisan bread", price: 8.99, imageName: "Sandwhich", category: "Food"),
            InventoryItem(name: "Muffin", description: "Blueberry muffin", price: 2.99, imageName: "Muffin", category: "Food"),
            InventoryItem(name: "Cookie", description: "Chocolate chip cookie", price: 1.99, imageName: "Cookie", category: "Food"),
            InventoryItem(name: "Cake Slice", description: "Chocolate cake slice", price: 5.99, imageName: "Cake", category: "Food"),
            InventoryItem(name: "Bagel", description: "Fresh baked bagel with cream cheese", price: 3.50, imageName: "Bagel", category: "Food"),
            InventoryItem(name: "Salad", description: "Fresh garden salad", price: 7.99, imageName: "Salad", category: "Food"),
            InventoryItem(name: "Soup", description: "Homemade soup of the day", price: 6.50, imageName: "Soup", category: "Food"),
            
            // Snacks
            InventoryItem(name: "Chips", description: "Potato chips", price: 2.50, imageName: "Chips", category: "Snacks"),
            InventoryItem(name: "Nuts", description: "Mixed nuts", price: 4.99, imageName: "Nuts", category: "Snacks"),
            InventoryItem(name: "Chocolate Bar", description: "Premium dark chocolate", price: 3.75, imageName: "ChocBar", category: "Snacks"),
            InventoryItem(name: "Granola Bar", description: "Healthy granola bar", price: 2.25, imageName: "ChocBar", category: "Snacks")
        ]
        
        categories = Array(Set(inventoryItems.map { $0.category })).sorted()
    }
    
    func getItemsByCategory(_ category: String) -> [InventoryItem] {
        return inventoryItems.filter { $0.category == category }
    }
    
    func searchItems(query: String) -> [InventoryItem] {
        if query.isEmpty {
            return inventoryItems
        }
        return inventoryItems.filter { item in
            item.name.localizedCaseInsensitiveContains(query) ||
            item.description.localizedCaseInsensitiveContains(query) ||
            item.category.localizedCaseInsensitiveContains(query)
        }
    }
    
    func addItem(_ item: InventoryItem) {
        inventoryItems.append(item)
        if !categories.contains(item.category) {
            categories.append(item.category)
            categories.sort()
        }
    }
    
    func removeItem(_ item: InventoryItem) {
        inventoryItems.removeAll { $0.id == item.id }
        // Check if category is still used
        if !inventoryItems.contains(where: { $0.category == item.category }) {
            categories.removeAll { $0 == item.category }
        }
    }
}

// Extension to provide better SF Symbol names for different categories
extension InventoryItem {
    var displayImageName: String {
        switch category {
        case "Beverages":
            return imageName
        case "Food":
            return imageName
        case "Snacks":
            return imageName
        default:
            return imageName
        }
    }
}
