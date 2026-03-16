import SwiftUI

/// Refund screen: refund method is fixed by original transaction (cash sale → cash refund only; card sale → card refund only).
struct RefundView: View {
    let entry: TerminalTransactionLogEntry
    let onDismiss: () -> Void
    
    @EnvironmentObject private var terminal: AppTerminalManager
    @State private var showingRefundCard = false
    @Environment(\.dismiss) private var dismiss
    
    private let primaryColor = Color(hex: "#3B9F40")
    /// Refund method is fixed: cash sale → cash only, card sale → card only.
    private var refundMethod: PaymentMethod { entry.isCash ? .cash : .card }
    
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
                            Text("Refund method")
                                .font(.title2)
                                .fontWeight(.semibold)
                            // Only show the method that matches the original transaction
                            PaymentMethodButton(
                                method: refundMethod,
                                isSelected: true,
                                onTap: {}
                            )
                            .disabled(true)
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
                        if refundMethod == .cash {
                            terminal.recordCashRefund(originalEntry: entry)
                            dismiss()
                            onDismiss()
                        } else {
                            terminal.clearForNewTransaction()
                            showingRefundCard = true
                        }
                    }) {
                        Text("Continue")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(hex: "#FF5252"))
                            .cornerRadius(12)
                    }
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
    
    @EnvironmentObject private var terminal: AppTerminalManager
    @State private var showTimeoutAlert = false
    
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

            Spacer()
        }
        .padding()
        .onAppear {
            terminal.startRefund(amountMinor: entry.amountMinor, currency: entry.currency, originalReqId: entry.reqId, originalEntryId: entry.id)
            showTimeoutAlert = terminal.showTimeoutPrompt
        }
        .onChange(of: terminal.showTimeoutPrompt) { _, new in showTimeoutAlert = new }
        .alert("Transaction timed out", isPresented: $showTimeoutAlert) {
            Button("Continue", role: .none) { terminal.continueWaiting() }
            Button("Cancel", role: .cancel) { terminal.cancelCurrentOperation(); onDone() }
        } message: {
            Text("No response from the terminal in 30 seconds.")
        }
        .safeAreaInset(edge: .bottom) {
            if terminal.lastResult != nil {
                Button(action: onDone) {
                    Text("Done")
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
                if terminal.lastResult != nil {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(Color(hex: "#3B9F40"))
                        Text("Refund Approved")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    .padding(.vertical, 8)
                } else {
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
                }
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
    .environmentObject(AppTerminalManager(sdk: SDKTerminalManager()))
}
