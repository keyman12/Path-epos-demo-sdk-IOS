import SwiftUI

struct CardProcessingView: View {
    let amountMinor: Int
    let currency: String
    let onDone: (Bool, String?) -> Void
    
    @StateObject private var ble = BLEUARTManager.shared
    
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
            ble.startSale(amountMinor: amountMinor, currency: currency)
        }
        // Hold on this screen; when result arrives we'll enable a Complete button below
        .alert("Timeout waiting for terminal", isPresented: $ble.showTimeoutPrompt) {
            Button("Continue", role: .none) { ble.continueWaiting() }
            Button("Cancel", role: .cancel) { ble.cancelCurrentOperation(); onDone(false, nil) }
        } message: {
            Text("No updates received in 30 seconds.")
        }
        .safeAreaInset(edge: .bottom) {
            if ble.lastResult != nil {
                Button(action: {
                    let status = ble.lastResult?["status"] as? String ?? ""
                    let success = status == "approved" || status == "success"
                    let txn = ble.lastResult?["txn_id"] as? String ?? ble.lastResult?["req_id"] as? String
                    onDone(success, txn)
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
                    Text("ACK received. Insert or tap card…")
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

#Preview {
    CardProcessingView(amountMinor: 1234, currency: "GBP", onDone: { _, _ in })
}


