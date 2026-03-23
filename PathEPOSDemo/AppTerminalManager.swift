//
//  AppTerminalManager.swift
//  PathEPOSDemo
//
//  PathEPOSwithPathSDK: wraps SDKTerminalManager for EnvironmentObject injection.
//

import Combine
import Foundation
import PathCoreModels
import SwiftUI

/// Concrete type for @EnvironmentObject; forwards to SDK terminal manager.
@MainActor
final class AppTerminalManager: ObservableObject, TerminalConnectionManager {
    private let wrapped: SDKTerminalManager
    private var cancellables = Set<AnyCancellable>()
    
    init(sdk: SDKTerminalManager) {
        self.wrapped = sdk
        subscribeToChanges(sdk)
    }
    
    private func subscribeToChanges(_ obj: some ObservableObject) {
        obj.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }
    
    var state: TerminalConnectionState { wrapped.state }
    var isReady: Bool { wrapped.isReady }
    var isBluetoothPoweredOn: Bool { wrapped.isBluetoothPoweredOn }
    var logs: [String] { wrapped.logs }
    var lastAckDate: Date? { wrapped.lastAckDate }
    var lastResult: [String: Any]? { wrapped.lastResult }
    var showTimeoutPrompt: Bool { wrapped.showTimeoutPrompt }
    var devices: [TerminalDeviceItem] { wrapped.devices }
    var connectingDeviceId: UUID? { wrapped.connectingDeviceId }
    var connectedDeviceId: UUID? { wrapped.connectedDeviceId }
    var transactionLog: [TerminalTransactionLogEntry] { wrapped.transactionLog }
    var lastError: String? { wrapped.lastError }
    var sdkVersion: String? { wrapped.sdkVersion }
    var protocolVersion: String? { wrapped.protocolVersion }
    var integrationKind: String { wrapped.integrationKind }
    var lastWireRequestId: String? { wrapped.lastWireRequestId }

    func start() { wrapped.start() }
    func startScan() { wrapped.startScan() }
    func stopScan() { wrapped.stopScan() }
    func stop() { wrapped.stop() }
    func connect(to device: TerminalDeviceItem) { wrapped.connect(to: device) }
    func disconnect() { wrapped.disconnect() }
    
    func startSale(amountMinor: Int, currency: String, tipMinor: Int?) {
        wrapped.startSale(amountMinor: amountMinor, currency: currency, tipMinor: tipMinor)
    }
    func startRefund(amountMinor: Int, currency: String, originalTransactionId: String?, originalReqId: String?, originalEntryId: UUID?) {
        wrapped.startRefund(amountMinor: amountMinor, currency: currency, originalTransactionId: originalTransactionId, originalReqId: originalReqId, originalEntryId: originalEntryId)
    }
    
    func continueWaiting() { wrapped.continueWaiting() }
    func cancelCurrentOperation() { wrapped.cancelCurrentOperation() }
    func clearForNewTransaction() { wrapped.clearForNewTransaction() }
    
    func addCashTransaction(amountMinor: Int, currency: String) {
        wrapped.addCashTransaction(amountMinor: amountMinor, currency: currency)
    }
    func recordCashRefund(originalEntry: TerminalTransactionLogEntry) {
        wrapped.recordCashRefund(originalEntry: originalEntry)
    }
    func clearTransactionLog() { wrapped.clearTransactionLog() }

    func getReceiptData(transactionId: String) async -> ReceiptData? {
        await wrapped.getReceiptData(transactionId: transactionId)
    }

    func getLogsForCopy() -> String { wrapped.getLogsForCopy() }
    func clearLogs() { wrapped.clearLogs() }
    func pruneLogs() { wrapped.pruneLogs() }

    func buildSupportBundleSnapshot() -> SupportBundleSnapshotV1 {
        wrapped.buildSupportBundleSnapshot()
    }

    func queryTransactionStatus(requestId: String?) async {
        await wrapped.queryTransactionStatus(requestId: requestId)
    }
}
