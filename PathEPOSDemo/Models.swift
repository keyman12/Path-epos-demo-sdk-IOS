import Foundation
import PathCoreModels

// MARK: - Demo card block for standalone when terminal GetReceipt is unavailable
extension CardReceiptFields {
    /// Placeholder card receipt for demo/standalone when terminal does not return GetReceipt data.
    /// SDK-integrated flows should use terminal receipt data instead.
    static func demoPlaceholder(amountMinor: Int, currency: String) -> CardReceiptFields {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let ts = formatter.string(from: Date())
        return CardReceiptFields(
            copyLabel: "CUSTOMER COPY",
            txnType: "SALE",
            amount: amountMinor,
            currency: currency,
            cardScheme: "VISA",
            maskedPan: "****1234",
            entryMode: "CONTACTLESS",
            aid: "A0000000031010",
            verification: "PIN NOT REQUIRED",
            authCode: "DEMO01",
            merchantId: "000000000001",
            terminalId: "TILL03",
            txnRef: "DEMO-\(abs(Int(Date().timeIntervalSince1970) % 100_000))",
            timestamp: ts,
            status: "APPROVED",
            retainMessage: nil
        )
    }
}

/// One line item for receipt display.
struct ReceiptLineItem {
    let name: String
    let quantity: Int
    let unitPrice: Double
    var lineTotal: Double { Double(quantity) * unitPrice }
}

/// Combined receipt: merchant header + order + line items + totals + optional card payment block (EMV).
struct FullReceipt {
    let merchantName: String
    let merchantAddress: String
    let orderNumber: String
    let tillNumber: String
    let cashierName: String
    let orderDate: Date
    let lineItems: [ReceiptLineItem]
    let subtotal: Double
    let vatAmount: Double
    let total: Double
    let currency: String
    let cardReceiptBlock: CardReceiptFields?
    let footerLines: [String]

    static func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: date)
    }
}

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
    let transactionId: String?     // txn_id from terminal (for GetReceipt)
    let isCash: Bool               // true = cash transaction (no card); display "Cash"
    let refundedAt: Date?          // when this sale was refunded (nil = not refunded)

    init(id: UUID = UUID(), urn: String, date: Date = Date(), cardLastFour: String, amountMinor: Int, currency: String, type: TerminalTransactionType, status: TerminalTransactionStatus, reqId: String?, transactionId: String? = nil, isCash: Bool = false, refundedAt: Date? = nil) {
        self.id = id
        self.urn = urn
        self.date = date
        self.cardLastFour = cardLastFour
        self.amountMinor = amountMinor
        self.currency = currency
        self.type = type
        self.status = status
        self.reqId = reqId
        self.transactionId = transactionId
        self.isCash = isCash
        self.refundedAt = refundedAt
    }
    
    /// Display in log: "Cash" for cash transactions, else "**** **** **** 1234"
    var cardMasked: String { isCash ? "Cash" : "**** **** **** \(cardLastFour)" }
    var amountPounds: Double { Double(amountMinor) / 100.0 }
    var formattedAmount: String { "£\(String(format: "%.2f", amountPounds))" }

    /// Returns a copy of this entry with `refundedAt` set (for updating the log when a sale is refunded).
    func withRefundedAt(_ date: Date) -> TerminalTransactionLogEntry {
        TerminalTransactionLogEntry(id: id, urn: urn, date: self.date, cardLastFour: cardLastFour, amountMinor: amountMinor, currency: currency, type: type, status: status, reqId: reqId, transactionId: transactionId, isCash: isCash, refundedAt: date)
    }

    enum CodingKeys: String, CodingKey {
        case id, urn, date, cardLastFour, amountMinor, currency, type, status, reqId, transactionId, isCash, refundedAt
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
        transactionId = try c.decodeIfPresent(String.self, forKey: .transactionId)
        isCash = try c.decodeIfPresent(Bool.self, forKey: .isCash) ?? false
        refundedAt = try c.decodeIfPresent(Date.self, forKey: .refundedAt)
    }
}

enum TerminalTransactionType: String, Codable, CaseIterable {
    case sale = "Sale"
    case refund = "Refund"
}

enum TerminalTransactionStatus: String, Codable, CaseIterable {
    case success = "Success"
    case decline = "Decline"
    case timedOut = "Timed Out"
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



