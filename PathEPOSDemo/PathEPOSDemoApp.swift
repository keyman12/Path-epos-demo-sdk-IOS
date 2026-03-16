//
//  PathEPOSDemoApp.swift
//  PathEPOSDemo
//
//  Created by David Key on 29/08/2025.
//
//  Dual path: default = direct BLE (standalone, for customers with other providers).
//  Scheme with USE_SDK_TERMINAL = SDK path (for testing SDK integration).
//

import SwiftUI

@main
struct PathEPOSDemoApp: App {
    init() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .background(Color(.systemBackground).ignoresSafeArea())
        }
    }
}

/// Injects terminal manager: direct BLE (default) or SDK via compile flag.
private struct RootView: View {
    #if USE_SDK_TERMINAL
    @StateObject private var terminal = AppTerminalManager(sdk: SDKTerminalManager())
    #else
    @StateObject private var terminal = AppTerminalManager(ble: BLEUARTManager.shared)
    #endif
    
    var body: some View {
        SplashView()
            .environmentObject(terminal)
    }
}
