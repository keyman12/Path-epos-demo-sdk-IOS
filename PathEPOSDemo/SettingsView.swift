import SwiftUI

struct SettingsView: View {
    @StateObject private var ble = BLEUARTManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Bluetooth Terminal")) {
                    if !ble.isBluetoothPoweredOn {
                        Label("Bluetooth not powered on", systemImage: "exclamationmark.triangle")
                            .foregroundColor(.secondary)
                    }
                    
                    if ble.isReady {
                        HStack {
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .foregroundColor(.green)
                            Text("Connected")
                            Spacer()
                            Button("Disconnect") { ble.disconnect() }
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
                Section(header: Text("Transactions")) {
                    NavigationLink("Transaction Log") {
                        TransactionLogView()
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
    @StateObject private var ble = BLEUARTManager.shared
    
    var body: some View {
        List {
            if case .bluetoothUnavailable = ble.state {
                Text("Bluetooth unavailable. Enable Bluetooth.")
                    .foregroundColor(.secondary)
            }
            ForEach(ble.devices) { device in
                Button(action: { ble.connect(to: device) }) {
                    HStack {
                        Text(device.name)
                        Spacer()
                        if ble.connectingDeviceId == device.id {
                            ProgressView()
                        } else if ble.connectedDeviceId == device.id {
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
                Button("Scan") { ble.startScan() }
            }
        }
        .onAppear { ble.startScan() }
        .overlay(
            Group {
                if ble.devices.isEmpty && ble.state == .scanning {
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
}


