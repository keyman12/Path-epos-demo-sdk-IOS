import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var terminal: AppTerminalManager
    @Environment(\.dismiss) private var dismiss
    @AppStorage("receipt_include_card_details") private var receiptIncludeCardDetails: Bool = true
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Bluetooth Terminal")) {
                    if !terminal.isBluetoothPoweredOn {
                        Label("Bluetooth not powered on", systemImage: "exclamationmark.triangle")
                            .foregroundColor(.secondary)
                    }
                    
                    if terminal.isReady {
                        HStack {
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .foregroundColor(.green)
                            Text("Connected")
                            Spacer()
                            Button("Disconnect") { terminal.disconnect() }
                        }
                    } else {
                        HStack {
                            Image(systemName: "bolt.horizontal.circle")
                            Text("Not connected")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    NavigationLink("Manage Devices") {
                        DeviceListView()
                    }
                }
                Section(header: Text("Receipts")) {
                    Toggle("Include card payment details", isOn: $receiptIncludeCardDetails)
                    NavigationLink("Email (SMTP)") {
                        SMTPConfigView()
                    }
                }
                Section(header: Text("Transactions")) {
                    NavigationLink("Transaction Log") {
                        TransactionLogView()
                    }
                }
                Section(header: Text("Developer")) {
                    NavigationLink("Diagnostics") {
                        DeveloperDiagnosticsView()
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

fileprivate struct DeviceListView: View {
    @EnvironmentObject private var terminal: AppTerminalManager
    
    var body: some View {
        List {
            if case .bluetoothUnavailable = terminal.state {
                Text("Bluetooth unavailable. Enable Bluetooth.")
                    .foregroundColor(.secondary)
            }
            ForEach(terminal.devices) { device in
                Button(action: { terminal.connect(to: device) }) {
                    HStack {
                        Text(device.name)
                        Spacer()
                        if terminal.connectingDeviceId == device.id {
                            ProgressView()
                        } else if terminal.connectedDeviceId == device.id {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        }
                        Text("RSSI \(device.rssi)")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .navigationTitle("Devices")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Scan") { terminal.startScan() }
            }
        }
        .onAppear { terminal.startScan() }
        .overlay(
            Group {
                if terminal.devices.isEmpty && terminal.state == .scanning {
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("Scanning… Hold near the terminal and ensure it is advertising.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        )
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppTerminalManager(ble: BLEUARTManager.shared))
}


