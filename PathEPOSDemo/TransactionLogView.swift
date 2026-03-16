import SwiftUI
import PathCoreModels

struct TransactionLogView: View {
    @EnvironmentObject private var terminal: AppTerminalManager
    @State private var showClearConfirmation = false
    @State private var selectedEntryForRefund: TerminalTransactionLogEntry?
    @State private var showReceiptSheet = false
    @State private var receiptToShow: FullReceipt?
    @State private var loadingReceiptId: UUID?

    private let pathGreen = Color(hex: "#3B9F40")

    var body: some View {
        Group {
            if terminal.transactionLog.isEmpty {
                ContentUnavailableView(
                    "No transactions",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Terminal transactions will appear here after you complete a sale or refund.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(terminal.transactionLog) { entry in
                            TransactionCard(
                                entry: entry,
                                isLoadingReceipt: loadingReceiptId == entry.id,
                                onReceipt: { showReceipt(for: entry) },
                                onRefund: { selectedEntryForRefund = entry }
                            )
                        }
                    }
                    .padding()
                }
                .background(Color(.systemGroupedBackground))
            }
        }
        .navigationTitle("Transaction Log")
        .toolbar {
            if !terminal.transactionLog.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .destructive, action: { showClearConfirmation = true }) {
                        Label("Clear log", systemImage: "trash")
                    }
                }
            }
        }
        .confirmationDialog("Clear transaction log?", isPresented: $showClearConfirmation, titleVisibility: .visible) {
            Button("Clear log", role: .destructive) { terminal.clearTransactionLog() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All logged transactions will be removed. This cannot be undone.")
        }
        .sheet(item: $selectedEntryForRefund) { entry in
            RefundView(entry: entry) { selectedEntryForRefund = nil }
                .environmentObject(terminal)
        }
        .sheet(isPresented: $showReceiptSheet) {
            if let receipt = receiptToShow {
                ReceiptView(receipt: receipt, onDismiss: {
                    showReceiptSheet = false
                    receiptToShow = nil
                })
            }
        }
    }

    private func showReceipt(for entry: TerminalTransactionLogEntry) {
        loadingReceiptId = entry.id
        Task { @MainActor in
            defer { loadingReceiptId = nil }
            if let txnId = entry.transactionId,
               let data = await terminal.getReceiptData(transactionId: txnId) {
                receiptToShow = buildReceiptFromData(data, entry: entry)
            } else {
                receiptToShow = buildReceiptFromEntry(entry)
            }
            showReceiptSheet = true
        }
    }

    private func buildReceiptFromData(_ data: ReceiptData, entry: TerminalTransactionLogEntry) -> FullReceipt {
        let total = Double(entry.amountMinor) / 100.0
        return FullReceipt(
            merchantName: "PATH COFFEE LONDON",
            merchantAddress: "12 Sample Street, London W1A 1AA",
            orderNumber: entry.urn,
            tillNumber: "03",
            cashierName: "—",
            orderDate: entry.date,
            lineItems: [ReceiptLineItem(name: entry.type == .refund ? "Card refund" : "Card payment", quantity: 1, unitPrice: total)],
            subtotal: total / 1.2,
            vatAmount: total - total / 1.2,
            total: total,
            currency: entry.currency,
            cardReceiptBlock: data.customerReceipt,
            footerLines: ["Thank you for your visit", "Returns accepted within 14 days"]
        )
    }

    private func buildReceiptFromEntry(_ entry: TerminalTransactionLogEntry) -> FullReceipt {
        let total = Double(entry.amountMinor) / 100.0
        return FullReceipt(
            merchantName: "PATH COFFEE LONDON",
            merchantAddress: "12 Sample Street, London W1A 1AA",
            orderNumber: entry.urn,
            tillNumber: "03",
            cashierName: "—",
            orderDate: entry.date,
            lineItems: [ReceiptLineItem(name: entry.type == .refund ? "Card refund" : "Card payment", quantity: 1, unitPrice: total)],
            subtotal: total / 1.2,
            vatAmount: total - total / 1.2,
            total: total,
            currency: entry.currency,
            cardReceiptBlock: nil,
            footerLines: ["Thank you for your visit", "Returns accepted within 14 days"]
        )
    }
}

// MARK: - Transaction card

struct TransactionCard: View {
    let entry: TerminalTransactionLogEntry
    let isLoadingReceipt: Bool
    let onReceipt: () -> Void
    let onRefund: () -> Void

    private let pathGreen = Color(hex: "#3B9F40")
    private let redColor   = Color(hex: "#FF5252")

    private var typeColor: Color { entry.type == .sale ? pathGreen : redColor }
    private var typeLabel: String { entry.type == .sale ? "SALE" : "REFUND" }

    private var statusColor: Color {
        switch entry.status {
        case .success:  return pathGreen
        case .timedOut: return .orange
        default:        return redColor
        }
    }
    private var statusLabel: String {
        switch entry.status {
        case .success:  return "Approved"
        case .timedOut: return "Timed out"
        default:        return "Declined"
        }
    }

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; return f
    }()
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.timeStyle = .short; return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(typeLabel)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(typeColor)
                        .cornerRadius(6)

                    Text(entry.formattedAmount)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .frame(width: 100, alignment: .leading)

                Divider().frame(height: 50)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(dateFormatter.string(from: entry.date))
                            .font(.subheadline)
                        Text("·")
                            .foregroundColor(.secondary)
                        Text(timeFormatter.string(from: entry.date))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: entry.isCash ? "banknote" : "creditcard")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(entry.isCash ? "Cash" : entry.cardMasked)
                            .font(.subheadline)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "number")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(entry.urn)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        Text(statusLabel)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(statusColor)
                    }
                    if let refundedAt = entry.refundedAt {
                        Text("Refunded \(dateFormatter.string(from: refundedAt))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if entry.status == .success && !entry.isCash {
                Divider()
                HStack(spacing: 12) {
                    Button(action: onReceipt) {
                        if isLoadingReceipt {
                            HStack(spacing: 6) {
                                ProgressView().scaleEffect(0.8)
                                Text("Loading…")
                            }
                        } else {
                            Label("Receipt", systemImage: "doc.text")
                        }
                    }
                    .buttonStyle(LogActionButtonStyle(color: pathGreen))
                    .disabled(isLoadingReceipt)

                    if entry.type == .sale && entry.refundedAt == nil {
                        Button(action: onRefund) {
                            Label("Refund", systemImage: "arrow.uturn.backward")
                        }
                        .buttonStyle(LogActionButtonStyle(color: redColor))
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 1)
    }
}

// MARK: - Button style

struct LogActionButtonStyle: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(color.opacity(0.12))
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

#Preview {
    NavigationStack {
        TransactionLogView()
            .environmentObject(AppTerminalManager(sdk: SDKTerminalManager()))
    }
}
