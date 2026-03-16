import SwiftUI
import PathCoreModels

struct CardProcessingView: View {
    let amountMinor: Int
    let currency: String
    var cartItems: [CartItem]? = nil
    var totalAmount: Double? = nil
    let onDone: (Bool, String?) -> Void

    @EnvironmentObject private var terminal: AppTerminalManager
    @Environment(\.dismiss) private var dismiss
    @State private var showTimeoutAlert = false
    @State private var showDeclinedAlert = false
    @State private var declinedMessage: String = ""
    @State private var showReceiptSheet = false
    @State private var receiptToShow: FullReceipt?
    @State private var pendingTxnIdForReceipt: String?
    @State private var hasHandledLastResult = false

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Card Processing")
                    .font(.title)
                    .fontWeight(.bold)
                Spacer()
            }
            .foregroundColor(Color(hex: "#3B9F40"))
            
            statusView
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

            Spacer()
        }
        .padding()
        .onAppear {
            terminal.startSale(amountMinor: amountMinor, currency: currency, tipMinor: nil)
            showTimeoutAlert = terminal.showTimeoutPrompt
            hasHandledLastResult = false
        }
        .onChange(of: terminal.showTimeoutPrompt) { _, new in showTimeoutAlert = new }
        .onChange(of: terminal.lastResult?["req_id"] as? String ?? "") { _, reqId in
            guard !reqId.isEmpty, let result = terminal.lastResult, !hasHandledLastResult else { return }
            handleResult(result)
        }
        .alert("Transaction timed out", isPresented: $showTimeoutAlert) {
            Button("OK") {
                terminal.cancelCurrentOperation()
                hasHandledLastResult = true
                onDone(false, nil)
                dismiss()
            }
        } message: {
            Text("No response from the terminal in 30 seconds. Your cart has been kept so you can try again.")
        }
        .alert("Payment declined", isPresented: $showDeclinedAlert) {
            Button("OK") {
                hasHandledLastResult = true
                onDone(false, nil)
                dismiss()
            }
        } message: {
            Text(declinedMessage)
        }
        .sheet(isPresented: $showReceiptSheet) {
            if let receipt = receiptToShow {
                ReceiptView(
                    receipt: receipt,
                    showAuthorisedBanner: true,
                    onNoReceipt: {
                        showReceiptSheet = false
                        receiptToShow = nil
                        onDone(true, pendingTxnIdForReceipt)
                        dismiss()
                    },
                    onEmailSent: {
                        showReceiptSheet = false
                        receiptToShow = nil
                        onDone(true, pendingTxnIdForReceipt)
                        dismiss()
                    }
                )
            }
        }
    }

    private func handleResult(_ result: [String: Any]) {
        let status = (result["status"] as? String)?.lowercased() ?? ""
        let txnId = result["txn_id"] as? String ?? result["req_id"] as? String

        if status == "approved" || status == "success" {
            hasHandledLastResult = true
            guard let txnId = txnId else {
                onDone(true, nil)
                dismiss()
                return
            }
            pendingTxnIdForReceipt = txnId
            Task { @MainActor in
                if let receiptData = await terminal.getReceiptData(transactionId: txnId) {
                    receiptToShow = buildFullReceipt(receiptData: receiptData)
                } else {
                    receiptToShow = buildFullReceiptWithoutTerminalReceipt()
                }
                showReceiptSheet = true
            }
            return
        }

        if status == "timed_out" {
            showTimeoutAlert = true
            return
        }

        // Declined
        let reason = result["error"] as? String ?? result["decline_reason"] as? String ?? "Unknown reason"
        declinedMessage = "\(reason)\n\nPlease try another card or payment method."
        showDeclinedAlert = true
    }

    private func buildFullReceipt(receiptData: ReceiptData) -> FullReceipt {
        let total = totalAmount ?? (Double(receiptData.merchantReceipt.amount) / 100.0)
        let lineItems: [ReceiptLineItem] = (cartItems ?? []).map {
            ReceiptLineItem(name: $0.item.name, quantity: $0.quantity, unitPrice: $0.item.price)
        }
        let subtotal = lineItems.isEmpty ? total : lineItems.map(\.lineTotal).reduce(0, +)
        let vatRate = 0.20
        let subtotalExVat = subtotal / (1 + vatRate)
        let vat = subtotal - subtotalExVat
        return FullReceipt(
            merchantName: "PATH COFFEE LONDON",
            merchantAddress: "12 Sample Street, London W1A 1AA",
            orderNumber: "\(abs(Int(Date().timeIntervalSince1970) % 100000))",
            tillNumber: "03",
            cashierName: "Sam",
            orderDate: Date(),
            lineItems: lineItems.isEmpty ? [ReceiptLineItem(name: "Card payment", quantity: 1, unitPrice: total)] : lineItems,
            subtotal: subtotalExVat,
            vatAmount: vat,
            total: total,
            currency: receiptData.merchantReceipt.currency,
            cardReceiptBlock: receiptData.customerReceipt,
            footerLines: ["Thank you for your visit", "Returns accepted within 14 days"]
        )
    }

    /// Receipt when terminal GetReceipt is unavailable. Uses hardcoded demo card block for standalone/demo.
    /// SDK layer will supply real receipt data when integrated.
    private func buildFullReceiptWithoutTerminalReceipt() -> FullReceipt {
        let amountMinor = terminal.lastResult?["amount"] as? Int ?? Int((totalAmount ?? 0) * 100)
        let total = totalAmount ?? Double(amountMinor) / 100.0
        let lineItems: [ReceiptLineItem] = (cartItems ?? []).map {
            ReceiptLineItem(name: $0.item.name, quantity: $0.quantity, unitPrice: $0.item.price)
        }
        let subtotal = lineItems.isEmpty ? total : lineItems.map(\.lineTotal).reduce(0, +)
        let vatRate = 0.20
        let subtotalExVat = subtotal / (1 + vatRate)
        let vat = subtotal - subtotalExVat
        return FullReceipt(
            merchantName: "PATH COFFEE LONDON",
            merchantAddress: "12 Sample Street, London W1A 1AA",
            orderNumber: "\(abs(Int(Date().timeIntervalSince1970) % 100000))",
            tillNumber: "03",
            cashierName: "Sam",
            orderDate: Date(),
            lineItems: lineItems.isEmpty ? [ReceiptLineItem(name: "Card payment", quantity: 1, unitPrice: total)] : lineItems,
            subtotal: subtotalExVat,
            vatAmount: vat,
            total: total,
            currency: currency,
            cardReceiptBlock: CardReceiptFields.demoPlaceholder(amountMinor: amountMinor, currency: currency),
            footerLines: ["Returns accepted within 14 days", "Thank you for your visit"]
        )
    }
    
    @ViewBuilder
    private var statusView: some View {
        VStack(spacing: 12) {
            switch terminal.state {
            case .idle:
                HStack { ProgressView(); Text("Initialising…") }
            case .bluetoothUnavailable:
                Label("Bluetooth is unavailable. Please enable Bluetooth and try again.", systemImage: "bluetooth.slash")
                    .foregroundColor(.orange)
            case .scanning:
                HStack(spacing: 12) { ProgressView(); Text("Looking for payment terminal…") }
            case .connecting:
                HStack(spacing: 12) { ProgressView(); Text("Connecting to payment terminal…") }
            case .ready:
                VStack(spacing: 12) {
                    Image(systemName: "creditcard.and.123")
                        .font(.system(size: 48))
                        .foregroundColor(Color(hex: "#3B9F40"))
                    Text("Waiting for customer to present their card.")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                    Text("Please tap, insert or swipe.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            case .disconnected:
                Label("Payment terminal disconnected.", systemImage: "wifi.slash")
                    .foregroundColor(.secondary)
            case .error(let msg):
                Label("Error: \(msg)", systemImage: "exclamationmark.triangle")
                    .foregroundColor(.red)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    CardProcessingView(amountMinor: 1234, currency: "GBP", onDone: { _, _ in })
        .environmentObject(AppTerminalManager(ble: BLEUARTManager.shared))
}


