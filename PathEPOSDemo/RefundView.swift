import SwiftUI

/// Refund screen: identical layout to Payment but titled "Refund". Selecting Card sends a Refund transaction to the Pico (same format as Sale, cmd: Refund).
struct RefundView: View {
    let entry: TerminalTransactionLogEntry
    let onDismiss: () -> Void
    
    @State private var selectedPaymentMethod: PaymentMethod?
    @State private var showingRefundCard = false
    @Environment(\.dismiss) private var dismiss
    
    private let primaryColor = Color(hex: "#3B9F40")
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    HStack {
                        Text("Refund")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(primaryColor)
                        Spacer()
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Refund amount (single line, like transaction summary)
                        VStack(spacing: 16) {
                            Text("Amount to refund")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text(entry.formattedAmount)
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(primaryColor)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        VStack(spacing: 16) {
                            Text("Select Refund Method")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            HStack(spacing: 20) {
                                PaymentMethodButton(
                                    method: .cash,
                                    isSelected: selectedPaymentMethod == .cash,
                                    onTap: { selectedPaymentMethod = .cash }
                                )
                                
                                PaymentMethodButton(
                                    method: .card,
                                    isSelected: selectedPaymentMethod == .card,
                                    onTap: { selectedPaymentMethod = .card }
                                )
                            }
                        }
                        
                        Spacer(minLength: 12)
                    }
                    .padding()
                    .padding(.bottom, 140)
                }
            }
            .background(Color(.systemBackground))
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    Button(action: {
                        if selectedPaymentMethod == .cash {
                            dismiss()
                            onDismiss()
                        } else if selectedPaymentMethod == .card {
                            showingRefundCard = true
                        }
                    }) {
                        Text("Continue")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedPaymentMethod != nil ? Color(hex: "#FF5252") : Color.gray)
                            .cornerRadius(12)
                    }
                    .disabled(selectedPaymentMethod == nil)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(Color(.systemBackground))
                .overlay(
                    VStack(spacing: 0) {
                        Divider()
                        Spacer(minLength: 0)
                    }
                )
            }
        }
        .sheet(isPresented: $showingRefundCard) {
            RefundCardView(entry: entry) {
                showingRefundCard = false
                dismiss()
                onDismiss()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                    onDismiss()
                }
            }
        }
    }
}

/// Card refund flow: sends Refund command to Pico (same message format as Sale but cmd: Refund). Same UI as CardProcessingView.
struct RefundCardView: View {
    let entry: TerminalTransactionLogEntry
    let onDone: () -> Void
    
    @StateObject private var ble = BLEUARTManager.shared
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Refund")
                    .font(.title)
                    .fontWeight(.bold)
                Spacer()
            }
            .foregroundColor(Color(hex: "#3B9F40"))
            
            Text(entry.formattedAmount)
                .font(.title2)
                .fontWeight(.semibold)
            
            statusView
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(ble.logs.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            ble.startRefund(amountMinor: entry.amountMinor, currency: entry.currency, originalReqId: entry.reqId)
        }
        .alert("Timeout waiting for terminal", isPresented: $ble.showTimeoutPrompt) {
            Button("Continue", role: .none) { ble.continueWaiting() }
            Button("Cancel", role: .cancel) { ble.cancelCurrentOperation(); onDone() }
        } message: {
            Text("No updates received in 30 seconds.")
        }
        .safeAreaInset(edge: .bottom) {
            if ble.lastResult != nil {
                Button(action: {
                    onDone()
                }) {
                    Text("Complete")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "#3B9F40"))
                        .cornerRadius(12)
                }
                .padding()
                .background(Color(.systemBackground))
            }
        }
    }
    
    @ViewBuilder
    private var statusView: some View {
        VStack(spacing: 8) {
            switch ble.state {
            case .idle: Text("Idle…")
            case .bluetoothUnavailable: Text("Bluetooth unavailable. Enable Bluetooth.")
            case .scanning: HStack { ProgressView(); Text("Scanning for terminal…") }
            case .connecting: HStack { ProgressView(); Text("Connecting…") }
            case .discovering: HStack { ProgressView(); Text("Preparing…") }
            case .ready:
                if ble.lastAckDate != nil {
                    Text("ACK received. Refund in progress…")
                        .fontWeight(.semibold)
                } else {
                    Text("Connected. Waiting for ACK…")
                }
            case .disconnected: Text("Disconnected.")
            case .error(let msg): Text("Error: \(msg)")
            }
        }
    }
}

#Preview("Refund") {
    RefundView(
        entry: TerminalTransactionLogEntry(
            urn: "URN-ABC12345",
            date: Date(),
            cardLastFour: "1234",
            amountMinor: 1946,
            currency: "GBP",
            type: .sale,
            status: .success,
            reqId: nil,
            isCash: false
        ),
        onDismiss: {}
    )
}
