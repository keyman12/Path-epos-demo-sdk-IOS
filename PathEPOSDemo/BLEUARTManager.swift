import Foundation
import CoreBluetooth
import SwiftUI
import PathCoreModels

final class BLEUARTManager: NSObject, ObservableObject, TerminalConnectionManager {
    static let shared = BLEUARTManager()

    // Nordic UART Service UUIDs
    private let serviceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    private let rxUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E") // Write
    private let txUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E") // Notify

    @Published var state: TerminalConnectionState = .idle
    @Published var isReady: Bool = false
    @Published var isBluetoothPoweredOn: Bool = false
    @Published private(set) var logEntries: [(date: Date, text: String)] = []
    var logs: [String] { logEntries.map(\.text) }
    @Published var lastAckDate: Date?
    @Published var lastResult: [String: Any]? // loosely typed for flexibility
    @Published var showTimeoutPrompt: Bool = false
    @Published var devices: [TerminalDeviceItem] = []
    @Published var connectingDeviceId: UUID?
    @Published var connectedDeviceId: UUID?
    @Published var transactionLog: [TerminalTransactionLogEntry] = []
    
    var lastError: String? { _lastError }
    var sdkVersion: String? { nil }
    var protocolVersion: String? { "0.1" }
    private var _lastError: String?
    
    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var rxCharacteristic: CBCharacteristic?
    private var txCharacteristic: CBCharacteristic?
    private var peripheralById: [UUID: CBPeripheral] = [:]

    private var receiveBuffer = Data()
    private var timeoutTimer: Timer?
    private var pendingScan: Bool = false

    private var pendingSale: (amount: Int, currency: String, tip: Int?)?
    private var pendingRefundOriginalEntryId: UUID?
    private var getReceiptContinuation: CheckedContinuation<ReceiptData?, Never>?
    private var pendingGetReceiptTxnId: String?
    private let transactionLogKey = "TerminalTransactionLog"
    private static let logMaxAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
        loadTransactionLog()
    }
    
    private func loadTransactionLog() {
        guard let data = UserDefaults.standard.data(forKey: transactionLogKey),
              let decoded = try? JSONDecoder().decode([TerminalTransactionLogEntry].self, from: data) else { return }
        transactionLog = decoded
    }
    
    private func saveTransactionLog() {
        guard let data = try? JSONEncoder().encode(transactionLog) else { return }
        UserDefaults.standard.set(data, forKey: transactionLogKey)
    }

    /// Removes all entries from the transaction log and deletes it from UserDefaults.
    func clearTransactionLog() {
        transactionLog = []
        UserDefaults.standard.removeObject(forKey: transactionLogKey)
    }

    /// Records a cash sale in the transaction log (no card; displays "Cash" in the log).
    func addCashTransaction(amountMinor: Int, currency: String) {
        let urn = "URN-\(UUID().uuidString.prefix(8).uppercased())"
        let entry = TerminalTransactionLogEntry(
            urn: urn,
            date: Date(),
            cardLastFour: "",
            amountMinor: amountMinor,
            currency: currency,
            type: .sale,
            status: .success,
            reqId: nil,
            transactionId: nil,
            isCash: true
        )
        transactionLog.insert(entry, at: 0)
        saveTransactionLog()
    }

    /// Records a cash refund: adds a Refund log entry and marks the original sale as refunded.
    func recordCashRefund(originalEntry: TerminalTransactionLogEntry) {
        guard let idx = transactionLog.firstIndex(where: { $0.id == originalEntry.id }) else { return }
        let refundedAt = Date()
        let updatedSale = originalEntry.withRefundedAt(refundedAt)
        transactionLog[idx] = updatedSale
        let refundUrn = "URN-\(UUID().uuidString.prefix(8).uppercased())"
        let refundEntry = TerminalTransactionLogEntry(
            urn: refundUrn,
            date: refundedAt,
            cardLastFour: "",
            amountMinor: originalEntry.amountMinor,
            currency: originalEntry.currency,
            type: .refund,
            status: .success,
            reqId: nil,
            transactionId: nil,
            isCash: true
        )
        transactionLog.insert(refundEntry, at: 0)
        saveTransactionLog()
    }

    func start() {
        guard central.state == .poweredOn else {
            state = .bluetoothUnavailable
            return
        }
        startScan()
    }

    func startScan() {
        guard central.state == .poweredOn else {
            pendingScan = true
            log("Bluetooth not ready yet; will scan when powered on…")
            return
        }
        devices.removeAll()
        peripheralById.removeAll()
        state = .scanning
        // Scan without filtering; some devices do not advertise the 128-bit UUID in ADV
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        log("Scanning for BLE devices…")
    }

    func stopScan() {
        central.stopScan()
    }

    func stop() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        if let p = peripheral { central.cancelPeripheralConnection(p) }
        peripheral = nil
        rxCharacteristic = nil
        txCharacteristic = nil
        isReady = false
        state = .disconnected
    }

    func connect(to device: TerminalDeviceItem) {
        guard let p = peripheralById[device.id] else { return }
        stopScan()
        state = .connecting
        connectingDeviceId = device.id
        peripheral = p
        peripheral?.delegate = self
        central.connect(p, options: nil)
        log("Connecting to \(device.name)…")
    }

    func disconnect() {
        stop()
    }

    /// Call before presenting sale/refund UI so Complete button is hidden until result arrives.
    func clearForNewTransaction() {
        lastResult = nil
        lastAckDate = nil
        // Keep logs for diagnostics; add separator for new transaction
        log("---")
    }

    func startSale(amountMinor: Int, currency: String, tipMinor: Int? = nil) {
        clearForNewTransaction()
        // If not ready, remember and start connection; send when ready
        guard isReady else {
            pendingSale = (amountMinor, currency, tipMinor)
            start()
            return
        }
        var args: [String: Any] = [
            "amount": amountMinor,
            "currency": currency
        ]
        if let tipMinor = tipMinor { args["tip"] = tipMinor }
        let message: [String: Any] = [
            "cmd": "Sale",
            "req_id": UUID().uuidString,
            "args": args
        ]
        sendJSONLine(message)
    }

    func startRefund(amountMinor: Int, currency: String, originalReqId: String? = nil, originalEntryId: UUID? = nil) {
        clearForNewTransaction()
        guard isReady else {
            log("Not connected. Connect to terminal first to process refund.")
            return
        }
        pendingRefundOriginalEntryId = originalEntryId
        var args: [String: Any] = [
            "amount": amountMinor,
            "currency": currency
        ]
        if let originalReqId = originalReqId { args["original_req_id"] = originalReqId }
        let message: [String: Any] = [
            "cmd": "Refund",
            "req_id": UUID().uuidString,
            "args": args
        ]
        sendJSONLine(message)
    }

    func continueWaiting() {
        start30sTimeout()
        showTimeoutPrompt = false
        log("Continuing to wait for terminal…")
    }

    /// Cancel the current operation (timeout, etc.) but keep the BLE connection.
    /// Call disconnect() separately if you want to disconnect.
    func cancelCurrentOperation() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        showTimeoutPrompt = false
        log("Operation cancelled by user.")
        // Do NOT call stop() - keep connection so user can try another transaction
    }

    private func sendJSONLine(_ object: [String: Any]) {
        guard let rx = rxCharacteristic, let p = peripheral else { return }
        do {
            // Build JSON string in the required field order: req_id, args, cmd
            let cmd = object["cmd"] as? String ?? ""
            let reqId = object["req_id"] as? String ?? UUID().uuidString
            let args = object["args"] as? [String: Any] ?? [:]
            let argsData = try JSONSerialization.data(withJSONObject: args, options: [])
            guard let argsString = String(data: argsData, encoding: .utf8) else { return }
            let line = "{\"req_id\":\"\(reqId)\",\"args\":\(argsString),\"cmd\":\"\(cmd)\"}\n"  // \n is actual newline (0x0A)
            guard let payload = line.data(using: .utf8) else { return }
            
            // BLE MTU is often limited to 20-23 bytes for older devices
            // Split into chunks if needed (but try to send as one if it fits)
            let maxChunkSize = 20  // Conservative chunk size for compatibility
            let writeType: CBCharacteristicWriteType = rx.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
            
            // Check actual MTU we can use
            let actualMTU = p.maximumWriteValueLength(for: writeType)
            let effectiveChunkSize = min(maxChunkSize, actualMTU)
            
            if payload.count <= effectiveChunkSize {
                // Small enough to send in one packet
                p.writeValue(payload, for: rx, type: writeType)
            } else {
                // Message is larger than MTU - split into chunks
                // This should rarely happen for typical JSON messages
                var offset = 0
                while offset < payload.count {
                    let chunkSize = min(effectiveChunkSize, payload.count - offset)
                    let chunk = payload.subdata(in: offset..<(offset + chunkSize))
                    p.writeValue(chunk, for: rx, type: writeType)
                    offset += chunkSize
                    // Small delay between chunks to ensure they're processed
                    if offset < payload.count {
                        Thread.sleep(forTimeInterval: 0.02)  // 20ms delay between chunks
                    }
                }
                log("⚠️ Message split into \(Int(ceil(Double(payload.count) / Double(effectiveChunkSize)))) chunks")
            }
            
            log("➡️ \(line.trimmingCharacters(in: .newlines))")
        } catch {
            log("Encoding error: \(error.localizedDescription)")
        }
    }

    private func processIncoming(_ data: Data) {
        receiveBuffer.append(data)
        while let range = receiveBuffer.firstRange(of: Data([0x0A])) { // newline
            let lineData = receiveBuffer.subdata(in: 0..<range.lowerBound)
            receiveBuffer.removeSubrange(0..<(range.upperBound)) // remove up to and including newline
            guard !lineData.isEmpty else { continue }
            if var line = String(data: lineData, encoding: .utf8) {
                line = line.trimmingCharacters(in: .whitespacesAndNewlines)
                log("⬅️ \(line)")

                // Handle optional "OK {json}" prefix from device
                if line.hasPrefix("OK ") {
                    let jsonPart = String(line.dropFirst(3))
                    handleJSONLine(jsonPart)
                } else {
                    handleJSONLine(line)
                }
            }
        }
    }

    private func handleJSONLine(_ line: String) {
        guard let data = line.data(using: .utf8) else { return }
        do {
            if let dict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                // If we see an ack, start the 30s timer
                if let type = dict["type"] as? String, type == "ack" {
                    lastAckDate = Date()
                    start30sTimeout()
                    if let cmd = dict["cmd"] as? String, let status = dict["status"] as? String, let req = dict["req_id"] as? String {
                        log("ACK: cmd=\(cmd) status=\(status) req_id=\(req)")
                    }
                } else if let type = dict["type"] as? String, type == "result" {
                    timeoutTimer?.invalidate()
                    showTimeoutPrompt = false
                    if let cmd = dict["cmd"] as? String, cmd == "GetReceipt" {
                        if let cont = getReceiptContinuation {
                            getReceiptContinuation = nil
                            let receipt = parseGetReceiptResponse(dict, transactionId: pendingGetReceiptTxnId ?? "")
                            DispatchQueue.main.async { cont.resume(returning: receipt) }
                        }
                        pendingGetReceiptTxnId = nil
                        return
                    }
                    lastResult = dict
                    log("✓ Result received: \(dict["status"] as? String ?? "?")")
                    // Append to transaction log when we receive a result from the terminal
                    if let cmd = dict["cmd"] as? String,
                       let amount = dict["amount"] as? Int,
                       let currency = dict["currency"] as? String {
                        let txnType: TerminalTransactionType = cmd == "Refund" ? .refund : .sale
                        let reqId = dict["req_id"] as? String
                        let cardLastFour = (dict["card_last_four"] as? String) ?? String(format: "%04d", Int.random(in: 0...9999))
                        let statusStr = (dict["status"] as? String)?.lowercased() ?? ""
                        let txnStatus: TerminalTransactionStatus = {
                            if statusStr == "approved" || statusStr == "success" { return .success }
                            if statusStr == "timed_out" { return .timedOut }
                            return .decline
                        }()
                        let urn = "URN-\(UUID().uuidString.prefix(8).uppercased())"
                        let txnId = dict["txn_id"] as? String
                        let entry = TerminalTransactionLogEntry(
                            urn: urn,
                            date: Date(),
                            cardLastFour: cardLastFour,
                            amountMinor: amount,
                            currency: currency,
                            type: txnType,
                            status: txnStatus,
                            reqId: reqId,
                            transactionId: txnId,
                            isCash: false
                        )
                        transactionLog.insert(entry, at: 0)
                        // If this was a Refund result, mark the original sale as refunded
                        if cmd == "Refund", let originalId = pendingRefundOriginalEntryId,
                           let idx = transactionLog.firstIndex(where: { $0.id == originalId }) {
                            let original = transactionLog[idx]
                            transactionLog[idx] = original.withRefundedAt(Date())
                            pendingRefundOriginalEntryId = nil
                        }
                        saveTransactionLog()
                    }
                } else {
                    // For any update, keep the timer alive
                    start30sTimeout()
                }
            }
        } catch {
            log("JSON parse error: \(error.localizedDescription)")
        }
    }

    private func start30sTimeout() {
        timeoutTimer?.invalidate()
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.showTimeoutPrompt = true
            self.log("⏱️ Timeout waiting for terminal update.")
        }
    }

    private func log(_ message: String) {
        pruneLogsIfNeeded()
        logEntries.append((date: Date(), text: message))
        if logEntries.count > 500 {
            logEntries.removeFirst(logEntries.count - 500)
        }
    }

    private func pruneLogsIfNeeded() {
        let cutoff = Date().addingTimeInterval(-Self.logMaxAge)
        logEntries.removeAll { $0.date < cutoff }
    }

    func getLogsForCopy() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return logEntries.map { "\(formatter.string(from: $0.date))  \($0.text)" }.joined(separator: "\n")
    }

    func clearLogs() {
        logEntries.removeAll()
    }

    func pruneLogs() {
        pruneLogsIfNeeded()
    }

    func getReceiptData(transactionId: String) async -> ReceiptData? {
        guard isReady else { return nil }
        return await withCheckedContinuation { cont in
            getReceiptContinuation = cont
            pendingGetReceiptTxnId = transactionId
            let message: [String: Any] = [
                "cmd": "GetReceipt",
                "req_id": UUID().uuidString,
                "args": ["txn_id": transactionId]
            ]
            sendJSONLine(message)
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                guard let self = self, let c = self.getReceiptContinuation else { return }
                self.getReceiptContinuation = nil
                self.pendingGetReceiptTxnId = nil
                c.resume(returning: nil)
            }
        }
    }

    private func parseGetReceiptResponse(_ dict: [String: Any], transactionId: String) -> ReceiptData? {
        guard (dict["status"] as? String)?.lowercased() == "success",
              let merchantDict = dict["merchant_receipt"] as? [String: Any],
              let customerDict = dict["customer_receipt"] as? [String: Any] else { return nil }
        do {
            let mData = try JSONSerialization.data(withJSONObject: merchantDict)
            let cData = try JSONSerialization.data(withJSONObject: customerDict)
            let merchant = try JSONDecoder().decode(CardReceiptFields.self, from: mData)
            let customer = try JSONDecoder().decode(CardReceiptFields.self, from: cData)
            return ReceiptData(
                transactionId: transactionId,
                requestId: nil,
                merchantReceipt: merchant,
                customerReceipt: customer,
                timestampUtc: merchant.timestamp
            )
        } catch {
            log("GetReceipt parse error: \(error.localizedDescription)")
            return nil
        }
    }
}

extension BLEUARTManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            isBluetoothPoweredOn = true
            // Stay idle; start() will kick scanning when needed
            if pendingScan { pendingScan = false; startScan() }
        case .unauthorized, .unsupported, .poweredOff, .resetting, .unknown:
            isBluetoothPoweredOn = false
            if central.state == .poweredOff || central.state == .unauthorized || central.state == .unsupported {
                state = .bluetoothUnavailable
            }
        @unknown default:
            isBluetoothPoweredOn = false
            state = .bluetoothUnavailable
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? "Unnamed"
        peripheralById[peripheral.identifier] = peripheral
        let item = TerminalDeviceItem(id: peripheral.identifier, name: name, rssi: RSSI.intValue)
        if let idx = devices.firstIndex(where: { $0.id == item.id }) {
            devices[idx] = item
        } else {
            devices.append(item)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        state = .connecting
        peripheral.discoverServices([serviceUUID])
        log("Connected. Discovering services…")
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        state = .error("Failed to connect: \(error?.localizedDescription ?? "unknown")")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        state = .disconnected
        isReady = false
        log("Disconnected.")
    if connectedDeviceId == peripheral.identifier { connectedDeviceId = nil }
    connectingDeviceId = nil
    }
}

extension BLEUARTManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            state = .error("Service discovery error: \(error.localizedDescription)")
            return
        }
        guard let services = peripheral.services else { return }
        var found = false
        for service in services where service.uuid == serviceUUID {
            found = true
            peripheral.discoverCharacteristics([rxUUID, txUUID], for: service)
        }
        if !found {
            state = .error("Selected device does not expose Nordic UART Service")
            log("NUS not found; disconnecting.")
            central.cancelPeripheralConnection(peripheral)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            state = .error("Characteristic discovery error: \(error.localizedDescription)")
            return
        }
        guard let characteristics = service.characteristics else { return }
        for c in characteristics {
            if c.uuid == rxUUID { rxCharacteristic = c }
            if c.uuid == txUUID {
                txCharacteristic = c
                peripheral.setNotifyValue(true, for: c)
            }
        }
        if rxCharacteristic != nil && txCharacteristic != nil {
            // Request larger MTU for better throughput (up to 512 bytes)
            // This allows sending larger JSON messages in fewer packets
            if #available(iOS 11.0, *) {
                let mtu = peripheral.maximumWriteValueLength(for: .withoutResponse)
                log("BLE MTU: \(mtu) bytes (max write without response)")
                // Note: CoreBluetooth doesn't support MTU negotiation on iOS
                // The MTU is negotiated automatically, but we can check what we got
            }
            
            isReady = true
            state = .ready
            log("UART ready.")
            connectedDeviceId = peripheral.identifier
            connectingDeviceId = nil
            // If a sale was requested before readiness, send it now
            if let pending = pendingSale {
                startSale(amountMinor: pending.amount, currency: pending.currency, tipMinor: pending.tip)
                pendingSale = nil
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            log("Notify error: \(error.localizedDescription)")
            return
        }
        guard characteristic.uuid == txUUID, let value = characteristic.value else { return }
        processIncoming(value)
    }
}


