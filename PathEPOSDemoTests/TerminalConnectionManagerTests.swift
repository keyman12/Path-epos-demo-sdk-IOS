//
//  TerminalConnectionManagerTests.swift
//  PathEPOSDemoTests
//
//  PathEPOSwithPathSDK: tests for TerminalConnectionManager and SDKTerminalManager only.
//

import Testing
import SwiftUI
import PathCoreModels
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
        _ = sdk.lastWireRequestId
        _ = sdk.getLogsForCopy()
        sdk.clearForNewTransaction()
        sdk.clearTransactionLog()
        sdk.clearLogs()
        sdk.pruneLogs()
        #expect(sdk.sdkVersion == "0.1.1")
        #expect(sdk.protocolVersion == "0.1")
        #expect(sdk.integrationKind == "path_sdk")
        let bundle = sdk.buildSupportBundleSnapshot()
        #expect(bundle.integration == "path_sdk")
        #expect(bundle.bundleVersion == "1")
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
