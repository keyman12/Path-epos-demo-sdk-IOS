//
//  DeveloperDiagnosticsView.swift
//  PathEPOSDemo
//
//  Developer diagnostics: SDK version, protocol version, connection state, last error, logs.
//

import SwiftUI
import UIKit

struct DeveloperDiagnosticsView: View {
    @EnvironmentObject private var terminal: AppTerminalManager
    @State private var showClearFirstConfirm = false
    @State private var showClearSecondConfirm = false
    @State private var showCopiedFeedback = false

    private var stateDescription: String {
        switch terminal.state {
        case .idle: return "Idle"
        case .bluetoothUnavailable: return "Bluetooth unavailable"
        case .scanning: return "Scanning"
        case .connecting: return "Connecting"
        case .ready: return "Ready"
        case .disconnected: return "Disconnected"
        case .error(let msg): return "Error: \(msg)"
        }
    }
    
    var body: some View {
        Form {
            Section(header: Text("Versions")) {
                LabeledContent("SDK", value: terminal.sdkVersion ?? "—")
                LabeledContent("Protocol", value: terminal.protocolVersion ?? "—")
            }
            
            Section(header: Text("Connection")) {
                LabeledContent("State", value: stateDescription)
                LabeledContent("Ready", value: terminal.isReady ? "Yes" : "No")
                LabeledContent("Bluetooth", value: terminal.isBluetoothPoweredOn ? "On" : "Off")
            }
            
            if let err = terminal.lastError {
                Section(header: Text("Last Error")) {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            Section {
                SelectableLogView(text: terminal.getLogsForCopy(), isEmpty: terminal.logs.isEmpty)
                    .frame(minHeight: 200, maxHeight: 500)
            } header: {
                Text("Logs")
            } footer: {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tap and hold to select text; use the system menu to copy.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 16) {
                        Button {
                            let text = terminal.getLogsForCopy()
                            UIPasteboard.general.string = text
                            showCopiedFeedback = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { showCopiedFeedback = false }
                        } label: {
                            Label("Copy all", systemImage: "doc.on.doc")
                        }
                        .disabled(terminal.logs.isEmpty)
                        Button(role: .destructive) {
                            showClearFirstConfirm = true
                        } label: {
                            Label("Clear logs", systemImage: "trash")
                        }
                        .disabled(terminal.logs.isEmpty)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Developer Diagnostics")
        .onAppear {
            terminal.pruneLogs()
        }
        .alert("Clear all logs?", isPresented: $showClearFirstConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                showClearSecondConfirm = true
            }
        } message: {
            Text("This cannot be undone. You will need to confirm again.")
        }
        .alert("Are you sure?", isPresented: $showClearSecondConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clear all logs", role: .destructive) {
                terminal.clearLogs()
            }
        } message: {
            Text("All log history will be removed.")
        }
        .overlay {
            if showCopiedFeedback {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial.opacity(0.5))
                    .overlay {
                        Text("Copied to clipboard")
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                    }
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showCopiedFeedback)
    }
}

// MARK: - Selectable log text (UIKit for reliable tap-to-select and system Copy menu)

struct SelectableLogView: UIViewRepresentable {
    let text: String
    let isEmpty: Bool

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.isScrollEnabled = true
        tv.font = .preferredFont(forTextStyle: .caption1)
        tv.textColor = .secondaryLabel
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        tv.textContainer.lineFragmentPadding = 0
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.text = isEmpty ? "No logs yet." : text
    }
}

#Preview {
    NavigationStack {
        DeveloperDiagnosticsView()
            .environmentObject(AppTerminalManager(sdk: SDKTerminalManager()))
    }
}
