//
//  ContentView.swift
//  PathEPOSDemo
//
//  Created by David Key on 29/08/2025.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        EPOSView()
    }
}

#Preview {
    ContentView()
        .environmentObject(AppTerminalManager(sdk: SDKTerminalManager()))
}
