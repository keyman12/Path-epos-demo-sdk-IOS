//
//  TerminalConnectionManager.swift
//  PathEPOSDemo
//
//  Protocol for terminal connection - implemented by SDKTerminalManager (Path SDK).
//  PathEPOSwithPathSDK uses only the SDK; no direct BLE.
//

import Foundation
import SwiftUI
import PathCoreModels

/// Device item for display in device list (matches DiscoveredDevice shape from SDK).
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

/// Protocol for terminal connection (SDK surface).
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
    func startRefund(amountMinor: Int, currency: String, originalReqId: String?, originalEntryId: UUID?)
    
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
}
