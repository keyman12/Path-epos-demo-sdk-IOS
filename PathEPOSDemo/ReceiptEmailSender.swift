//
//  ReceiptEmailSender.swift
//  PathEPOSDemo
//
//  SMTP matching Dashboard: same env-style settings, STARTTLS on port 587 (Fasthosts Livemail).
//  Runs on a dedicated thread with run loop so TLS (STARTTLS) can complete on iOS.
//  Logs status to os_log (Xcode console or Console.app, category "SMTP").
//

import Foundation
import os

struct SMTPConfig {
    var host: String
    var port: Int
    var useTLS: Bool
    var username: String
    var password: String
    var fromEmail: String
    var fromName: String

    static let defaults = UserDefaults.standard
    static var current: SMTPConfig? {
        guard let host = defaults.string(forKey: "smtp_host"), !host.isEmpty else { return nil }
        return SMTPConfig(
            host: host,
            port: defaults.object(forKey: "smtp_port") as? Int ?? 587,
            useTLS: defaults.object(forKey: "smtp_use_tls") as? Bool ?? true,
            username: defaults.string(forKey: "smtp_username") ?? "",
            password: defaults.string(forKey: "smtp_password") ?? "",
            fromEmail: defaults.string(forKey: "smtp_from_email") ?? "noreply@path2ai.tech",
            fromName: defaults.string(forKey: "smtp_from_name") ?? "Path Dashboard"
        )
    }
}

enum ReceiptEmailError: LocalizedError {
    case smtpNotConfigured
    case connectionFailed(String)
    case sendFailed(String)

    var errorDescription: String? {
        switch self {
        case .smtpNotConfigured:
            return "SMTP is not configured. Add server details in Settings → Receipts."
        case .connectionFailed(let msg): return "Connection failed: \(msg)"
        case .sendFailed(let msg): return "Send failed: \(msg)"
        }
    }
}

enum ReceiptEmailSender {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PathEPOSDemoSDK", category: "SMTP")

    static func send(pdf: Data, to recipient: String, subject: String) async throws {
        guard let config = SMTPConfig.current else {
            throw ReceiptEmailError.smtpNotConfigured
        }
        let boundary = "ReceiptPDF-\(UUID().uuidString)"
        let introText = [
            "Dear Customer,",
            "",
            "Thank you for visiting Path Cafe. As requested,",
            "please find an email copy of your receipt attached.",
            "",
            "Kind regards,",
            "Path Cafe"
        ].joined(separator: "\r\n")
        let messageLines = [
            "From: \(config.fromName) <\(config.fromEmail)>",
            "To: \(recipient)",
            "Subject: \(subject)",
            "MIME-Version: 1.0",
            "Content-Type: multipart/mixed; boundary=\(boundary)",
            "",
            "--\(boundary)",
            "Content-Type: text/plain; charset=UTF-8",
            "Content-Transfer-Encoding: 7bit",
            "",
            introText,
            "",
            "--\(boundary)",
            "Content-Type: application/pdf; name=\"receipt.pdf\"",
            "Content-Transfer-Encoding: base64",
            "Content-Disposition: attachment; filename=\"receipt.pdf\"",
            "",
            pdf.base64EncodedString(),
            "--\(boundary)--"
        ]
        let messageBody = messageLines.joined(separator: "\r\n")

        logger.info("SMTP send starting host=\(config.host) port=\(config.port) useSTARTTLS=\(config.port == 587 || config.useTLS)")
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try sendSMTPSync(
                        host: config.host,
                        port: config.port,
                        useSTARTTLS: config.port == 587 || config.useTLS,
                        username: config.username,
                        password: config.password,
                        fromEmail: config.fromEmail,
                        recipient: recipient,
                        messageBody: messageBody
                    )
                    logger.info("SMTP send completed successfully")
                    cont.resume()
                } catch {
                    logger.error("SMTP send failed: \(String(describing: error))")
                    cont.resume(throwing: error)
                }
            }
        }
    }

    /// Runs SMTP on a dedicated thread with a run loop so TLS (STARTTLS) can complete.
    private static func sendSMTPSync(
        host: String,
        port: Int,
        useSTARTTLS: Bool,
        username: String,
        password: String,
        fromEmail: String,
        recipient: String,
        messageBody: String
    ) throws {
        var result: Result<Void, Error>?
        let done = DispatchGroup()
        done.enter()
        let thread = Thread {
            defer { done.leave() }
            do {
                try runSMTPOnRunLoop(
                    host: host,
                    port: port,
                    useSTARTTLS: useSTARTTLS,
                    username: username,
                    password: password,
                    fromEmail: fromEmail,
                    recipient: recipient,
                    messageBody: messageBody
                )
                result = .success(())
            } catch {
                result = .failure(error)
            }
        }
        thread.start()
        done.wait()
        switch result {
        case .success?: break
        case .failure(let e)?: throw e
        default: throw ReceiptEmailError.sendFailed("SMTP thread did not finish")
        }
    }

    private static func runSMTPOnRunLoop(
        host: String,
        port: Int,
        useSTARTTLS: Bool,
        username: String,
        password: String,
        fromEmail: String,
        recipient: String,
        messageBody: String
    ) throws {
        var inputStream: InputStream?
        var outputStream: OutputStream?
        Stream.getStreamsToHost(withName: host, port: port, inputStream: &inputStream, outputStream: &outputStream)
        guard let ins = inputStream, let outs = outputStream else {
            logger.error("SMTP could not create streams")
            throw ReceiptEmailError.connectionFailed("Could not create streams")
        }
        logger.info("SMTP streams created, opening…")
        let runLoop = RunLoop.current
        ins.schedule(in: runLoop, forMode: .common)
        outs.schedule(in: runLoop, forMode: .common)
        ins.open()
        outs.open()
        defer { ins.close(); outs.close() }
        let timeout: TimeInterval = 30

        let openDeadline = Date().addingTimeInterval(15)
        while (ins.streamStatus != .open || outs.streamStatus != .open), Date() < openDeadline {
            if let e = ins.streamError ?? outs.streamError {
                logger.error("SMTP stream error while opening: \(e.localizedDescription)")
                throw ReceiptEmailError.connectionFailed(e.localizedDescription)
            }
            runLoop.run(until: Date().addingTimeInterval(0.1))
        }
        guard ins.streamStatus == .open, outs.streamStatus == .open else {
            logger.error("SMTP streams did not open in time in=\(ins.streamStatus.rawValue) out=\(outs.streamStatus.rawValue)")
            throw ReceiptEmailError.connectionFailed("Streams did not open in time (in: \(ins.streamStatus.rawValue), out: \(outs.streamStatus.rawValue))")
        }
        logger.info("SMTP streams open, waiting for 220 greeting")

        func readReply(step: String) throws -> String {
            var data = Data()
            let start = Date()
            var lastLogTime = start
            logger.info("SMTP waiting for reply: [\(step)]")
            while Date().timeIntervalSince(start) < timeout {
                runLoop.run(until: Date().addingTimeInterval(0.1))
                if let e = ins.streamError {
                    logger.error("SMTP [\(step)] stream error: \(e.localizedDescription)")
                    throw ReceiptEmailError.sendFailed(e.localizedDescription)
                }
                if ins.hasBytesAvailable {
                    var buffer = [UInt8](repeating: 0, count: 512)
                    let n = ins.read(&buffer, maxLength: buffer.count)
                    if n > 0 { data.append(contentsOf: buffer.prefix(n)) }
                    if n < 0, let e = ins.streamError { throw ReceiptEmailError.sendFailed(e.localizedDescription) }
                }
                let elapsed = Date().timeIntervalSince(start)
                if Date().timeIntervalSince(lastLogTime) >= 5.0 {
                    logger.info("SMTP [\(step)] still waiting elapsed=\(String(format: "%.1f", elapsed))s hasBytes=\(ins.hasBytesAvailable) dataCount=\(data.count) inStatus=\(ins.streamStatus.rawValue)")
                    lastLogTime = Date()
                }
                // UTF-8 can fail if server sends non-ASCII or we have partial multibyte; Latin1 accepts any bytes (SMTP is ASCII).
                let s = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
                // Split by "\n"; use last non-empty line so "220-\r\n220 ready\r\n" gives "220 ready" not "".
                let lines = s.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                let last = lines.last(where: { !$0.isEmpty })
                if let last = last, last.count >= 4 {
                    let code = String(last.prefix(4))
                    if code.count == 4, code.last != "-" {
                        logger.info("SMTP [\(step)] got: \(last.prefix(80))")
                        return last
                    }
                }
            }
            let decoded = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
            logger.error("SMTP [\(step)] read timeout after \(String(format: "%.1f", timeout))s hasBytes=\(ins.hasBytesAvailable) dataCount=\(data.count) inStatus=\(ins.streamStatus.rawValue) decoded=\(decoded.prefix(80).replacingOccurrences(of: "\r", with: "\\r").replacingOccurrences(of: "\n", with: "\\n"))")
            throw ReceiptEmailError.sendFailed("Read timeout")
        }

        func write(_ s: String) throws {
            let firstLine = s.split(separator: "\n").first.map(String.init) ?? s
            logger.debug("SMTP send: \(firstLine.prefix(60))")
            let line = s.hasSuffix("\r\n") ? s : s + "\r\n"
            guard let d = line.data(using: .utf8) else { return }
            var sent = 0
            let writeTimeout = Date().addingTimeInterval(timeout)
            while sent < d.count {
                if Date() > writeTimeout { throw ReceiptEmailError.sendFailed("Write timeout") }
                let written: Int = d.withUnsafeBytes { ptr in
                    let base = ptr.baseAddress!.assumingMemoryBound(to: UInt8.self)
                    return outs.write(base.advanced(by: sent), maxLength: d.count - sent)
                }
                if written > 0 { sent += written }
                else {
                    if let e = outs.streamError { throw ReceiptEmailError.sendFailed(e.localizedDescription) }
                    runLoop.run(until: Date().addingTimeInterval(0.1))
                }
            }
        }

        var r = try readReply(step: "220-greeting")
        if !r.hasPrefix("220") { throw ReceiptEmailError.sendFailed(r) }

        try write("EHLO localhost")
        r = try readReply(step: "EHLO")
        if !r.hasPrefix("250") { throw ReceiptEmailError.sendFailed("EHLO: \(r)") }

        if useSTARTTLS {
            try write("STARTTLS")
            r = try readReply(step: "STARTTLS")
            if !r.uppercased().hasPrefix("220") { throw ReceiptEmailError.sendFailed("STARTTLS: \(r)") }
            logger.info("SMTP upgrading to TLS…")
            let tlsLevel = StreamSocketSecurityLevel.negotiatedSSL
            ins.setProperty(tlsLevel, forKey: .socketSecurityLevelKey)
            outs.setProperty(tlsLevel, forKey: .socketSecurityLevelKey)
            try write("EHLO localhost")
            r = try readReply(step: "EHLO-after-TLS")
            if !r.hasPrefix("250") { throw ReceiptEmailError.sendFailed("EHLO after TLS: \(r)") }
        }

        if !username.isEmpty && !password.isEmpty {
            try write("AUTH LOGIN")
            r = try readReply(step: "AUTH-LOGIN")
            if !r.hasPrefix("334") { throw ReceiptEmailError.sendFailed("AUTH: \(r)") }
            try write(Data(username.utf8).base64EncodedString())
            r = try readReply(step: "AUTH-user")
            if !r.hasPrefix("334") { throw ReceiptEmailError.sendFailed("AUTH user: \(r)") }
            try write(Data(password.utf8).base64EncodedString())
            r = try readReply(step: "AUTH-result")
            if !r.hasPrefix("235") { throw ReceiptEmailError.sendFailed("AUTH result: \(r)") }
        }

        try write("MAIL FROM:<\(fromEmail)>")
        r = try readReply(step: "MAIL-FROM")
        if !r.hasPrefix("250") { throw ReceiptEmailError.sendFailed(r) }
        try write("RCPT TO:<\(recipient)>")
        r = try readReply(step: "RCPT-TO")
        if !r.hasPrefix("250") { throw ReceiptEmailError.sendFailed(r) }
        try write("DATA")
        r = try readReply(step: "DATA")
        if !r.hasPrefix("354") { throw ReceiptEmailError.sendFailed(r) }
        try write(messageBody)
        try write(".")
        r = try readReply(step: "DATA-end")
        if !r.hasPrefix("250") { throw ReceiptEmailError.sendFailed(r) }
        try write("QUIT")
    }
}
