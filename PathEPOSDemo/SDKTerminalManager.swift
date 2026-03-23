//
//  SDKTerminalManager.swift
//  PathEPOSDemo
//
//  Terminal connection manager backed by PathTerminalSDK.
//  Requires PathTerminalSDK package dependency.
//

import Foundation
import OSLog
import SwiftUI
import PathTerminalSDK
import PathCoreModels
import PathEmulatorAdapter

private let terminalConsoleLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PathEPOS", category: "Terminal")

@MainActor
final class SDKTerminalManager: ObservableObject, TerminalConnectionManager {
    private let terminal: PathTerminal
    private let adapter: BLEPathTerminalAdapter
    private var eventTask: Task<Void, Never>?
    private var currentSaleTask: Task<Void, Never>?
    private var currentRefundTask: Task<Void, Never>?
    
    @Published var state: TerminalConnectionState = .idle
    @Published var isReady: Bool = false
    @Published var isBluetoothPoweredOn: Bool = true
    @Published private(set) var logEntries: [(date: Date, text: String)] = []
    var logs: [String] { logEntries.map(\.text) }
    @Published var lastAckDate: Date?
    @Published var lastResult: [String: Any]?
    @Published var showTimeoutPrompt: Bool = false
    @Published var devices: [TerminalDeviceItem] = []
    @Published var connectingDeviceId: UUID?
    @Published var connectedDeviceId: UUID?
    @Published var transactionLog: [TerminalTransactionLogEntry] = []
    /// Wire `req_id` of the last started Sale/Refund (for GetTransactionStatus in diagnostics).
    @Published private(set) var lastWireRequestId: String? = nil

    var lastError: String?
    var sdkVersion: String? { "0.1.1" }
    var protocolVersion: String? { "0.1" }
    
    private var pendingRefundOriginalEntryId: UUID?
    private let transactionLogKey = "TerminalTransactionLog"
    private static let lastTerminalDeviceIdKey = "PathLastConnectedTerminalDeviceId"
    private static let logMaxAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days

    init() {
        let ad = BLEPathTerminalAdapter(sdkVersion: "0.1.1", adapterVersion: "0.1.1")
        self.adapter = ad
        self.terminal = PathTerminal(adapter: ad)
        ad.onLog = { [weak self] msg in
            Task { @MainActor in self?.log(msg) }
        }
        ad.onBluetoothStateChange = { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.isBluetoothPoweredOn = ad.isBluetoothPoweredOn
                if !self.isBluetoothPoweredOn {
                    self.state = .bluetoothUnavailable
                    self.isReady = false
                } else if case .bluetoothUnavailable = self.state {
                    self.state = self.terminal.isConnected ? .ready : .idle
                }
            }
        }
        isBluetoothPoweredOn = ad.isBluetoothPoweredOn
        loadTransactionLog()
        startEventTask()
        if let saved = UserDefaults.standard.string(forKey: Self.lastTerminalDeviceIdKey) {
            log("Hint: last terminal id \(saved). BLE does not auto-reconnect after app restart — open Settings → Manage Devices.")
        }
        #if DEBUG
        NSLog("[PathTerminal] DEBUG build — SDKTerminalManager ready (see Diagnostics for Xcode console tips).")
        #endif
    }

    var integrationKind: String { "path_sdk" }

    func buildSupportBundleSnapshot() -> SupportBundleSnapshotV1 {
        let formatter = ISO8601DateFormatter()
        let recent = logEntries.suffix(120).map { "\(formatter.string(from: $0.date))  \($0.text)" }
        return SupportBundleSnapshotV1(
            generatedAtUtc: formatter.string(from: Date()),
            integration: integrationKind,
            sdkVersion: sdkVersion,
            protocolVersion: protocolVersion,
            connectionState: state.diagnosticsLabel,
            isReady: isReady,
            isBluetoothPoweredOn: isBluetoothPoweredOn,
            lastError: lastError,
            logLineCount: logEntries.count,
            recentLogLines: Array(recent),
            transactionLogCount: transactionLog.count
        )
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
    
    private func log(_ message: String) {
        pruneLogsIfNeeded()
        logEntries.append((date: Date(), text: message))
        if logEntries.count > 500 {
            logEntries.removeFirst(logEntries.count - 500)
        }
        terminalConsoleLogger.notice("\(message, privacy: .public)")
        #if DEBUG
        print("[PathTerminal] \(message)")
        NSLog("[PathTerminal] %@", message)
        #endif
    }

    private func logConnectionEvent(_ conn: ConnectionState) {
        let line: String
        switch conn {
        case .idle:
            line = "event connection: idle (adapter.isConnected=\(terminal.isConnected))"
        case .scanning:
            line = "event connection: scanning"
        case .connecting:
            line = "event connection: connecting"
        case .connected:
            line = "event connection: connected"
        case .disconnected:
            line = "event connection: disconnected"
        case .error(let msg):
            line = "event connection: error \(msg)"
        }
        log(line)
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
    
    private func startEventTask() {
        eventTask = Task { @MainActor in
            for await event in terminal.events {
                switch event {
                case .connectionStateChanged(let conn):
                    logConnectionEvent(conn)
                    switch conn {
                    case .idle:
                        if terminal.isConnected {
                            state = .ready
                            isReady = true
                        } else {
                            state = .idle
                            isReady = false
                        }
                    case .scanning:
                        state = .scanning
                        if terminal.isConnected { isReady = true }
                    case .connecting: state = .connecting
                    case .connected: state = .ready; isReady = true; lastAckDate = Date()
                    case .disconnected: state = .disconnected; isReady = false; connectedDeviceId = nil
                    case .error(let msg): state = .error(msg); lastError = msg
                    }
                case .deviceDiscovered(let d):
                    let item = TerminalDeviceItem(id: d.id, name: d.name, rssi: d.rssi)
                    if let idx = devices.firstIndex(where: { $0.id == d.id }) {
                        devices[idx] = item
                    } else {
                        devices.append(item)
                    }
                case .transactionStateChanged(let txnState):
                    if txnState == .pendingDevice || txnState == .cardRead {
                        lastAckDate = Date()
                    }
                case .error(let err):
                    lastError = err.message
                    log("Error: \(err.message)")
                default:
                    break
                }
            }
        }
    }
    
    func start() {
        startScan()
    }
    
    func startScan() {
        devices.removeAll()
        state = .scanning
        log("Scanning for BLE devices…")
        Task {
            do {
                let devicesFound = try await terminal.discoverDevices()
                await MainActor.run {
                    devices = devicesFound.map { TerminalDeviceItem(id: $0.id, name: $0.name, rssi: $0.rssi) }
                    if terminal.isConnected {
                        state = .ready
                        isReady = true
                    } else {
                        state = .idle
                    }
                }
            } catch {
                await MainActor.run {
                    lastError = error.localizedDescription
                    state = .error(error.localizedDescription)
                    log("Scan failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func stopScan() {
        if terminal.isConnected {
            state = .ready
            isReady = true
        } else {
            state = .idle
        }
    }
    
    func stop() {
        currentSaleTask?.cancel()
        currentRefundTask?.cancel()
        currentSaleTask = nil
        currentRefundTask = nil
        showTimeoutPrompt = false
        lastWireRequestId = nil
        Task {
            try? await terminal.disconnect()
            await MainActor.run {
                isReady = false
                state = .disconnected
                connectedDeviceId = nil
            }
        }
    }
    
    func connect(to device: TerminalDeviceItem) {
        let discovered = DiscoveredDevice(id: device.id, name: device.name, rssi: device.rssi)
        connectingDeviceId = device.id
        state = .connecting
        log("Connecting to \(device.name)…")
        Task {
            do {
                try await terminal.connect(to: discovered)
                await MainActor.run {
                    connectingDeviceId = nil
                    connectedDeviceId = device.id
                    state = .ready
                    isReady = true
                    lastAckDate = Date()
                    log("Connected.")
                    UserDefaults.standard.set(device.id.uuidString, forKey: Self.lastTerminalDeviceIdKey)
                }
            } catch {
                await MainActor.run {
                    connectingDeviceId = nil
                    lastError = error.localizedDescription
                    state = .error(error.localizedDescription)
                    log("Connect failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func disconnect() {
        stop()
    }
    
    func clearForNewTransaction() {
        lastResult = nil
        lastAckDate = nil
        log("---")
    }
    
    func startSale(amountMinor: Int, currency: String, tipMinor: Int? = nil) {
        clearForNewTransaction()
        guard isReady else {
            log("Not connected. Connect to terminal first.")
            return
        }
        let envelope = RequestEnvelope.create(sdkVersion: "0.1.1", adapterVersion: "0.1.1")
        lastWireRequestId = envelope.requestId
        let request = TransactionRequest.sale(amountMinor: amountMinor, currency: currency, tipMinor: tipMinor, envelope: envelope)
        log("Sending Sale request…")
        lastAckDate = Date()
        currentSaleTask = Task {
            do {
                let result = try await terminal.sale(request: request)
                await MainActor.run {
                    applyResult(result, cmd: "Sale")
                }
            } catch let pathError as PathError {
                await MainActor.run {
                    lastError = pathError.message
                    lastResult = resultDict(error: pathError.message, cmd: "Sale", amountMinor: amountMinor, currency: currency)
                    let recov = pathError.recoverable ? " [recoverable]" : ""
                    log("Sale error\(recov) [\(pathError.code)]: \(pathError.message)")
                }
            } catch {
                await MainActor.run {
                    lastError = error.localizedDescription
                    lastResult = resultDict(error: error.localizedDescription, cmd: "Sale", amountMinor: amountMinor, currency: currency)
                    log("Sale failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func startRefund(amountMinor: Int, currency: String, originalTransactionId: String? = nil, originalReqId: String? = nil, originalEntryId: UUID? = nil) {
        clearForNewTransaction()
        guard isReady else {
            log("Not connected. Connect to terminal first.")
            return
        }
        pendingRefundOriginalEntryId = originalEntryId
        let envelope = RequestEnvelope.create(sdkVersion: "0.1.1", adapterVersion: "0.1.1")
        lastWireRequestId = envelope.requestId
        let request = TransactionRequest.refund(
            amountMinor: amountMinor,
            currency: currency,
            originalTransactionId: originalTransactionId,
            originalRequestId: originalReqId,
            envelope: envelope
        )
        log("Sending Refund request…")
        lastAckDate = Date()
        currentRefundTask = Task {
            do {
                let result = try await terminal.refund(request: request)
                await MainActor.run {
                    applyResult(result, cmd: "Refund")
                }
            } catch let pathError as PathError {
                await MainActor.run {
                    lastError = pathError.message
                    lastResult = resultDict(error: pathError.message, cmd: "Refund", amountMinor: amountMinor, currency: currency)
                    let recov = pathError.recoverable ? " [recoverable]" : ""
                    log("Refund error\(recov) [\(pathError.code)]: \(pathError.message)")
                }
            } catch {
                await MainActor.run {
                    lastError = error.localizedDescription
                    lastResult = resultDict(error: error.localizedDescription, cmd: "Refund", amountMinor: amountMinor, currency: currency)
                    log("Refund failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func applyResult(_ result: TransactionResult, cmd: String) {
        let statusStr: String
        switch result.state {
        case .approved, .refunded: statusStr = "approved"
        case .declined: statusStr = "declined"
        case .timedOut: statusStr = "timed_out"
        case .failed: statusStr = "failed"
        default: statusStr = "declined"
        }
        lastResult = [
            "txn_id": result.transactionId ?? result.requestId,
            "req_id": result.requestId,
            "status": statusStr,
            "amount": result.amountMinor,
            "currency": result.currency,
            "card_last_four": result.cardLastFour ?? "0000"
        ]
        if let err = result.error {
            log("✓ Result: \(statusStr) — \(err.message)")
        } else {
            log("✓ Result: \(statusStr)")
        }
        
        let txnStatus: TerminalTransactionStatus = {
            if result.state == .approved || result.state == .refunded { return .success }
            if result.state == .timedOut { return .timedOut }
            return .decline
        }()
        let entry = TerminalTransactionLogEntry(
            urn: "URN-\(UUID().uuidString.prefix(8).uppercased())",
            date: Date(),
            cardLastFour: result.cardLastFour ?? "0000",
            amountMinor: result.amountMinor,
            currency: result.currency,
            type: cmd == "Refund" ? .refund : .sale,
            status: txnStatus,
            reqId: result.requestId,
            transactionId: result.transactionId,
            isCash: false
        )
        transactionLog.insert(entry, at: 0)
        if cmd == "Refund", let originalId = pendingRefundOriginalEntryId,
           let idx = transactionLog.firstIndex(where: { $0.id == originalId }) {
            let original = transactionLog[idx]
            transactionLog[idx] = original.withRefundedAt(Date())
            pendingRefundOriginalEntryId = nil
        }
        saveTransactionLog()
    }
    
    private func resultDict(error: String, cmd: String, amountMinor: Int, currency: String) -> [String: Any] {
        [
            "txn_id": UUID().uuidString,
            "req_id": UUID().uuidString,
            "status": "declined",
            "amount": amountMinor,
            "currency": currency,
            "card_last_four": "0000",
            "error": error
        ]
    }
    
    func continueWaiting() {
        showTimeoutPrompt = false
        log("Continuing to wait for terminal…")
    }
    
    func cancelCurrentOperation() {
        currentSaleTask?.cancel()
        currentRefundTask?.cancel()
        currentSaleTask = nil
        currentRefundTask = nil
        showTimeoutPrompt = false
        log("Cancelling in-flight operation…")
        Task {
            do {
                try await terminal.cancelActiveTransaction()
                await MainActor.run { log("Cancel sent to terminal.") }
            } catch let pathError as PathError {
                await MainActor.run {
                    log("Cancel: [\(pathError.code.rawValue)] \(pathError.message)")
                }
            } catch {
                await MainActor.run { log("Cancel: \(error.localizedDescription)") }
            }
        }
    }
    
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
    
    func recordCashRefund(originalEntry: TerminalTransactionLogEntry) {
        guard let idx = transactionLog.firstIndex(where: { $0.id == originalEntry.id }) else { return }
        let refundedAt = Date()
        let updatedSale = originalEntry.withRefundedAt(refundedAt)
        transactionLog[idx] = updatedSale
        let refundEntry = TerminalTransactionLogEntry(
            urn: "URN-\(UUID().uuidString.prefix(8).uppercased())",
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
    
    func clearTransactionLog() {
        transactionLog = []
        UserDefaults.standard.removeObject(forKey: transactionLogKey)
    }

    func getReceiptData(transactionId: String) async -> ReceiptData? {
        do {
            return try await terminal.getReceiptData(transactionId: transactionId)
        } catch {
            log("Receipt fetch failed: \(error.localizedDescription)")
            return nil
        }
    }

    func queryTransactionStatus(requestId: String?) async {
        let rid = requestId ?? lastWireRequestId
        guard let rid else {
            log("GetTransactionStatus: no request id — run a Sale or Refund first.")
            return
        }
        guard isReady else {
            log("GetTransactionStatus: not connected.")
            return
        }
        log("GetTransactionStatus… req_id=\(rid)")
        do {
            let result = try await terminal.getTransactionStatus(requestId: rid)
            let stateLabel = String(describing: result.state)
            log("GetTransactionStatus: state=\(stateLabel) txn_id=\(result.transactionId ?? "—")")
        } catch let pathError as PathError {
            log("GetTransactionStatus: [\(pathError.code.rawValue)] \(pathError.message)")
        } catch {
            log("GetTransactionStatus: \(error.localizedDescription)")
        }
    }
}
