import Foundation

struct InventoryItem: Identifiable, Codable {
    let id = UUID()
    let name: String
    let description: String
    let price: Double
    let imageName: String
    let category: String
}

struct CartItem: Identifiable {
    let id = UUID()
    let item: InventoryItem
    var quantity: Int
    var totalPrice: Double {
        return item.price * Double(quantity)
    }
}

struct Transaction: Identifiable {
    let id = UUID()
    let items: [CartItem]
    let totalAmount: Double
    let paymentMethod: PaymentMethod
    let timestamp: Date
    let cashReceived: Double?
    let changeGiven: Double?
}

enum PaymentMethod: String, CaseIterable {
    case cash = "Cash"
    case card = "Card"
}

// Terminal (Pico) transaction log entry – for Transaction Log screen and refunds
struct TerminalTransactionLogEntry: Identifiable, Codable {
    let id: UUID
    let urn: String                // unique reference number, system-generated at start of log
    let date: Date
    let cardLastFour: String       // e.g. "1234" for card; empty for cash
    let amountMinor: Int           // amount in minor units (pence)
    let currency: String
    let type: TerminalTransactionType
    let status: TerminalTransactionStatus  // Success or Decline
    let reqId: String?             // original request id from Pico (for reference/refund)
    let isCash: Bool               // true = cash transaction (no card); display "Cash"
    
    init(id: UUID = UUID(), urn: String, date: Date = Date(), cardLastFour: String, amountMinor: Int, currency: String, type: TerminalTransactionType, status: TerminalTransactionStatus, reqId: String?, isCash: Bool = false) {
        self.id = id
        self.urn = urn
        self.date = date
        self.cardLastFour = cardLastFour
        self.amountMinor = amountMinor
        self.currency = currency
        self.type = type
        self.status = status
        self.reqId = reqId
        self.isCash = isCash
    }
    
    /// Display in log: "Cash" for cash transactions, else "**** **** **** 1234"
    var cardMasked: String { isCash ? "Cash" : "**** **** **** \(cardLastFour)" }
    var amountPounds: Double { Double(amountMinor) / 100.0 }
    var formattedAmount: String { "£\(String(format: "%.2f", amountPounds))" }
    
    enum CodingKeys: String, CodingKey {
        case id, urn, date, cardLastFour, amountMinor, currency, type, status, reqId, isCash
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        urn = try c.decode(String.self, forKey: .urn)
        date = try c.decode(Date.self, forKey: .date)
        cardLastFour = try c.decode(String.self, forKey: .cardLastFour)
        amountMinor = try c.decode(Int.self, forKey: .amountMinor)
        currency = try c.decode(String.self, forKey: .currency)
        type = try c.decode(TerminalTransactionType.self, forKey: .type)
        status = try c.decode(TerminalTransactionStatus.self, forKey: .status)
        reqId = try c.decodeIfPresent(String.self, forKey: .reqId)
        isCash = try c.decodeIfPresent(Bool.self, forKey: .isCash) ?? false
    }
}

enum TerminalTransactionType: String, Codable, CaseIterable {
    case sale = "Sale"
    case refund = "Refund"
}

enum TerminalTransactionStatus: String, Codable, CaseIterable {
    case success = "Success"
    case decline = "Decline"
}

// Sample inventory data
extension InventoryItem {
    static let sampleItems = [
        InventoryItem(name: "Coffee", description: "Fresh brewed coffee", price: 3.50, imageName: "cup.and.saucer.fill", category: "Beverages"),
        InventoryItem(name: "Sandwich", description: "Ham and cheese sandwich", price: 8.99, imageName: "birthday.cake.fill", category: "Food"),
        InventoryItem(name: "Water", description: "Bottled water", price: 2.50, imageName: "drop.fill", category: "Beverages"),
        InventoryItem(name: "Cake", description: "Chocolate cake slice", price: 5.99, imageName: "birthday.cake.fill", category: "Food"),
        InventoryItem(name: "Tea", description: "Hot tea", price: 2.99, imageName: "cup.and.saucer.fill", category: "Beverages"),
        InventoryItem(name: "Cookie", description: "Chocolate chip cookie", price: 1.99, imageName: "birthday.cake.fill", category: "Food")
    ]
}



