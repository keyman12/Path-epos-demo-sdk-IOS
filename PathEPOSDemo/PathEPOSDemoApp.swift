//
//  PathEPOSDemoApp.swift
//  PathEPOSDemo
//
//  PathEPOSwithPathSDK: uses only PathTerminalSDK (no direct BLE).
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

/// Injects SDK terminal manager only.
private struct RootView: View {
    @StateObject private var terminal = AppTerminalManager(sdk: SDKTerminalManager())
    
    var body: some View {
        SplashView()
            .environmentObject(terminal)
    }
}
