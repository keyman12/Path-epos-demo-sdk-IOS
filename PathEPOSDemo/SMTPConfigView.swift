//
//  SMTPConfigView.swift
//  PathEPOSDemo
//

import SwiftUI

struct SMTPConfigView: View {
    @AppStorage("smtp_host") private var host: String = ""
    @AppStorage("smtp_port") private var port: Int = 587
    @AppStorage("smtp_use_tls") private var useTLS: Bool = true
    @AppStorage("smtp_username") private var username: String = ""
    @AppStorage("smtp_password") private var password: String = ""
    @AppStorage("smtp_from_email") private var fromEmail: String = "noreply@path2ai.tech"
    @AppStorage("smtp_from_name") private var fromName: String = "Path Dashboard"

    var body: some View {
        Form {
            Section {
                TextField("Host", text: $host)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                HStack {
                    Text("Port")
                    TextField("587", value: $port, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
                Toggle("Use TLS", isOn: $useTLS)
            } header: {
                Text("Server")
            } footer: {
                Text("Same as Path Dashboard: port 587 with STARTTLS (e.g. Fasthosts Livemail: smtp.livemail.co.uk).")
            }

            Section("Authentication") {
                TextField("Username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Password", text: $password)
            }

            Section("From") {
                TextField("From email", text: $fromEmail)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                TextField("From name", text: $fromName)
            }
        }
        .navigationTitle("SMTP")
        .navigationBarTitleDisplayMode(.inline)
    }
}
