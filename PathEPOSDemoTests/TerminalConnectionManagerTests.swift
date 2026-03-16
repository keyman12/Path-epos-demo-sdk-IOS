//
//  TerminalConnectionManagerTests.swift
//  PathEPOSDemoTests
//
//  Phase 2: Tests for TerminalConnectionManager protocol and implementations.
//

import Testing
import SwiftUI
@testable import PathEPOSDemo

@Suite("TerminalConnectionManager")
struct TerminalConnectionManagerTests {

    @Test("TerminalDeviceItem has required properties")
    func terminalDeviceItemProperties() {
        let id = UUID()
        let item = TerminalDeviceItem(id: id, name: "Test Device", rssi: -50)
        #expect(item.id == id)
        #expect(item.name == "Test Device")
        #expect(item.rssi == -50)
    }

    @Test("TerminalConnectionState cases exist")
    func terminalConnectionStateCases() {
        let idle: TerminalConnectionState = .idle
        let scanning: TerminalConnectionState = .scanning
        let ready: TerminalConnectionState = .ready
        let error: TerminalConnectionState = .error("test")
        #expect(idle == .idle)
        #expect(scanning == .scanning)
        #expect(ready == .ready)
        #expect(error == .error("test"))
    }

    @Test("BLEUARTManager conforms to TerminalConnectionManager")
    @MainActor
    func bleUARTManagerConforms() {
        let ble = BLEUARTManager.shared
        let _: any TerminalConnectionManager = ble
        #expect(ble.devices is [TerminalDeviceItem])
        #expect(ble.logs is [String])
        #expect(ble.transactionLog is [TerminalTransactionLogEntry])
    }

    @Test("BLEUARTManager has protocol surface")
    @MainActor
    func bleUARTManagerSurface() {
        let ble = BLEUARTManager.shared
        _ = ble.state
        _ = ble.isReady
        _ = ble.isBluetoothPoweredOn
        _ = ble.logs
        _ = ble.lastAckDate
        _ = ble.lastResult
        _ = ble.showTimeoutPrompt
        _ = ble.devices
        _ = ble.connectingDeviceId
        _ = ble.connectedDeviceId
        _ = ble.transactionLog
        _ = ble.lastError
        _ = ble.sdkVersion
        _ = ble.protocolVersion
        _ = ble.getLogsForCopy()
        ble.clearForNewTransaction()
        ble.clearTransactionLog()
        ble.clearLogs()
        ble.pruneLogs()
        #expect(true)
    }

    @Test("SDKTerminalManager conforms to TerminalConnectionManager")
    @MainActor
    func sdkTerminalManagerConforms() {
        let sdk = SDKTerminalManager()
        let _: any TerminalConnectionManager = sdk
        #expect(sdk.state == .idle)
        #expect(sdk.isReady == false)
        #expect(sdk.devices.isEmpty)
        #expect(sdk.logs.isEmpty)
    }

    @Test("SDKTerminalManager has protocol surface")
    @MainActor
    func sdkTerminalManagerSurface() {
        let sdk = SDKTerminalManager()
        _ = sdk.state
        _ = sdk.isReady
        _ = sdk.logs
        _ = sdk.devices
        _ = sdk.transactionLog
        _ = sdk.lastError
        _ = sdk.sdkVersion
        _ = sdk.protocolVersion
        _ = sdk.getLogsForCopy()
        sdk.clearForNewTransaction()
        sdk.clearTransactionLog()
        sdk.clearLogs()
        sdk.pruneLogs()
        #expect(sdk.sdkVersion == "0.1.0")
        #expect(sdk.protocolVersion == "0.1")
    }

    @Test("SDKTerminalManager addCashTransaction adds to log")
    @MainActor
    func sdkCashTransaction() {
        let sdk = SDKTerminalManager()
        let initialCount = sdk.transactionLog.count
        sdk.addCashTransaction(amountMinor: 100, currency: "GBP")
        #expect(sdk.transactionLog.count == initialCount + 1)
        #expect(sdk.transactionLog.first?.amountMinor == 100)
        #expect(sdk.transactionLog.first?.currency == "GBP")
        #expect(sdk.transactionLog.first?.isCash == true)
        sdk.clearTransactionLog()
    }
}
