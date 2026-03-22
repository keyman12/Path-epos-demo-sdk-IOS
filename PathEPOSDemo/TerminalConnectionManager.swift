//
//  TerminalConnectionManager.swift
//  PathEPOSDemo
//
//  Protocol for terminal connection - implemented by BLEUARTManager (direct BLE)
//  and SDKTerminalManager (Path SDK). Allows switching between implementations.
//

import Foundation
import SwiftUI
import PathCoreModels

/// Device item for display in device list (matches BLEUARTManager.DeviceItem and DiscoveredDevice shape).
struct TerminalDeviceItem: Identifiable, Hashable {
    let id: UUID
    let name: String
    let rssi: Int
}

/// Connection state exposed to UI.
enum TerminalConnectionState: Equatable {
    case idle
    case bluetoothUnavailable
    case scanning
    case connecting
    case ready
    case disconnected
    case error(String)
}

/// Protocol matching BLEUARTManager surface for drop-in SDK replacement.
protocol TerminalConnectionManager: ObservableObject {
    var state: TerminalConnectionState { get }
    var isReady: Bool { get }
    var isBluetoothPoweredOn: Bool { get }
    var logs: [String] { get }
    var lastAckDate: Date? { get }
    var lastResult: [String: Any]? { get }
    var showTimeoutPrompt: Bool { get }
    var devices: [TerminalDeviceItem] { get }
    var connectingDeviceId: UUID? { get }
    var connectedDeviceId: UUID? { get }
    var transactionLog: [TerminalTransactionLogEntry] { get }
    
    func start()
    func startScan()
    func stopScan()
    func stop()
    func connect(to device: TerminalDeviceItem)
    func disconnect()
    
    func startSale(amountMinor: Int, currency: String, tipMinor: Int?)
    func startRefund(amountMinor: Int, currency: String, originalTransactionId: String?, originalReqId: String?, originalEntryId: UUID?)
    
    func continueWaiting()
    func cancelCurrentOperation()
    
    func clearForNewTransaction()
    
    func addCashTransaction(amountMinor: Int, currency: String)
    func recordCashRefund(originalEntry: TerminalTransactionLogEntry)
    
    func clearTransactionLog()

    /// Fetch receipt data for a transaction (from terminal GetReceipt). Returns nil if unsupported or error.
    func getReceiptData(transactionId: String) async -> ReceiptData?

    /// For developer diagnostics
    var lastError: String? { get }
    var sdkVersion: String? { get }
    var protocolVersion: String? { get }
    
    /// Copy-friendly string (with timestamps) for email etc. Clears diagnostic logs with double-confirm in UI.
    func getLogsForCopy() -> String
    func clearLogs()
    /// Remove log entries older than 7 days (e.g. call when opening diagnostics).
    func pruneLogs()

    /// `path_sdk` (PathTerminalSDK) or `native_ble` (direct BLE stack).
    var integrationKind: String { get }

    /// Redacted JSON snapshot for support (no full card numbers).
    func buildSupportBundleSnapshot() -> SupportBundleSnapshotV1

    /// Last Sale/Refund wire `req_id` (for GetTransactionStatus). Nil until a payment is started.
    var lastWireRequestId: String? { get }

    /// Calls GetTransactionStatus for `requestId`, or the last wire `req_id` if nil. Logs outcome to developer log.
    func queryTransactionStatus(requestId: String?) async
}

extension TerminalConnectionManager {
    func exportSupportBundlePrettyJSON() throws -> String {
        try SupportBundleSnapshotV1.encodePrettyString(buildSupportBundleSnapshot())
    }
}

extension TerminalConnectionState {
    var diagnosticsLabel: String {
        switch self {
        case .idle: return "idle"
        case .bluetoothUnavailable: return "bluetooth_unavailable"
        case .scanning: return "scanning"
        case .connecting: return "connecting"
        case .ready: return "ready"
        case .disconnected: return "disconnected"
        case .error(let msg): return "error: \(msg)"
        }
    }
}
