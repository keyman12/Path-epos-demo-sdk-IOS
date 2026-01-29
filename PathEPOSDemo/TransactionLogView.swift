import SwiftUI

private let columnSpacing: CGFloat = 12
private let cardToValueSpacing: CGFloat = 24  // Extra spacing between Card Number and Value

struct TransactionLogView: View {
    @StateObject private var ble = BLEUARTManager.shared
    @State private var showClearConfirmation = false
    @State private var selectedEntryForRefund: TerminalTransactionLogEntry?

    var body: some View {
        Group {
            if ble.transactionLog.isEmpty {
                ContentUnavailableView(
                    "No transactions",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Terminal transactions will appear here after you complete a sale or refund.")
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        TransactionLogHeaderRow()
                            .background(Color(.tertiarySystemGroupedBackground))
                        Divider()
                        ForEach(Array(ble.transactionLog.enumerated()), id: \.element.id) { index, entry in
                            TransactionLogRowView(entry: entry, index: index) {
                                selectedEntryForRefund = entry
                            }
                            Divider()
                        }
                    }
                }
                .background(Color(.systemGroupedBackground))
            }
        }
        .navigationTitle("Transaction Log")
        .toolbar {
            if !ble.transactionLog.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .destructive, action: { showClearConfirmation = true }) {
                        Label("Clear log", systemImage: "trash")
                    }
                }
            }
        }
        .confirmationDialog("Clear transaction log?", isPresented: $showClearConfirmation, titleVisibility: .visible) {
            Button("Clear log", role: .destructive) {
                ble.clearTransactionLog()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All logged transactions will be removed. This cannot be undone.")
        }
        .sheet(item: $selectedEntryForRefund) { entry in
            RefundView(entry: entry) {
                selectedEntryForRefund = nil
            }
        }
    }
}

struct TransactionLogHeaderRow: View {
    var body: some View {
        HStack(alignment: .center, spacing: columnSpacing) {
            Text("URN")
                .frame(minWidth: 90, maxWidth: .infinity, alignment: .leading)
            Text("Card Number")
                .frame(minWidth: 100, maxWidth: .infinity, alignment: .leading)
            Spacer().frame(width: cardToValueSpacing)
            Text("Value")
                .frame(minWidth: 64, maxWidth: .infinity, alignment: .leading)
            Text("Date")
                .frame(minWidth: 80, maxWidth: .infinity, alignment: .leading)
            Text("Time")
                .frame(minWidth: 64, maxWidth: .infinity, alignment: .leading)
            Text("Status")
                .frame(minWidth: 72, maxWidth: .infinity, alignment: .leading)
            Text("Refund")
                .frame(minWidth: 80, maxWidth: .infinity, alignment: .center)
        }
        .font(.subheadline)
        .fontWeight(.semibold)
        .foregroundColor(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct TransactionLogRowView: View {
    let entry: TerminalTransactionLogEntry
    let index: Int
    let onRefund: () -> Void
    
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        return f
    }()
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
    
    private var rowBackground: Color {
        index.isMultiple(of: 2) ? Color(.secondarySystemGroupedBackground) : Color(.systemBackground)
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: columnSpacing) {
            Text(entry.urn)
                .frame(minWidth: 90, maxWidth: .infinity, alignment: .leading)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
            
            Text(entry.cardMasked)
                .frame(minWidth: 100, maxWidth: .infinity, alignment: .leading)
                .font(.subheadline)
                .lineLimit(1)
            
            Spacer().frame(width: cardToValueSpacing)
            
            Text(entry.formattedAmount)
                .frame(minWidth: 64, maxWidth: .infinity, alignment: .leading)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text(dateFormatter.string(from: entry.date))
                .frame(minWidth: 80, maxWidth: .infinity, alignment: .leading)
                .font(.subheadline)
            
            Text(timeFormatter.string(from: entry.date))
                .frame(minWidth: 64, maxWidth: .infinity, alignment: .leading)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(entry.status.rawValue)
                .frame(minWidth: 72, maxWidth: .infinity, alignment: .leading)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(entry.status == .success ? Color(hex: "#3B9F40") : Color(hex: "#FF5252"))
            
            Group {
                if entry.type == .sale {
                    Button(action: onRefund) {
                        Text("Refund")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(hex: "#FF5252"))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("—")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .frame(minWidth: 80, maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground)
    }
}

#Preview {
    NavigationStack {
        TransactionLogView()
    }
}
