//
//  ReceiptView.swift
//  PathEPOSDemo
//
//  Receipt with three options: No receipt (return, clear cart), Print, Email.
//

import SwiftUI
import UIKit

struct ReceiptView: View {
    let receipt: FullReceipt
    /// Show the green "Payment Authorised" banner at the top (set true after a live payment).
    var showAuthorisedBanner: Bool = false
    /// When non-nil, show "No receipt" (return to main, clear cart). When nil, show "Done" (e.g. from Transaction Log).
    var onNoReceipt: (() -> Void)? = nil
    /// Called when Done is tapped (e.g. from Transaction Log) or for toolbar dismiss.
    var onDismiss: (() -> Void)? = nil
    /// Called when the email receipt has been sent and the confirmation alert dismissed.
    var onEmailSent: (() -> Void)? = nil

    @AppStorage("receipt_include_card_details") private var includeCardDetails: Bool = true
    @State private var showPrintSheet = false
    @State private var showEmailSheet = false

    private var displayedReceipt: FullReceipt {
        if includeCardDetails { return receipt }
        return FullReceipt(
            merchantName: receipt.merchantName,
            merchantAddress: receipt.merchantAddress,
            orderNumber: receipt.orderNumber,
            tillNumber: receipt.tillNumber,
            cashierName: receipt.cashierName,
            orderDate: receipt.orderDate,
            lineItems: receipt.lineItems,
            subtotal: receipt.subtotal,
            vatAmount: receipt.vatAmount,
            total: receipt.total,
            currency: receipt.currency,
            cardReceiptBlock: nil,
            footerLines: receipt.footerLines
        )
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if showAuthorisedBanner {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                        Text("Payment Authorised")
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(hex: "#3B9F40"))
                }

                ReceiptContentView(receipt: displayedReceipt)
                    .padding()

                VStack(spacing: 12) {
                    if let onNoReceipt = onNoReceipt {
                        Button(action: onNoReceipt) {
                            Label("No receipt", systemImage: "xmark.circle")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .buttonStyle(.bordered)
                        .tint(Color(hex: "#3B9F40"))
                    } else {
                        Button(action: { onDismiss?() }) {
                            Label("Done", systemImage: "checkmark.circle")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .buttonStyle(.bordered)
                        .tint(Color(hex: "#3B9F40"))
                    }

                    Button(action: { showPrintSheet = true }) {
                        Label("Print receipt", systemImage: "printer")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: "#3B9F40"))

                    Button(action: { showEmailSheet = true }) {
                        Label("Email receipt", systemImage: "envelope")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: "#3B9F40"))
                }
                .padding()
            }
            .navigationTitle("Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPrintSheet) {
                PrintSheet(pdfData: ReceiptRenderer.pdfData(from: displayedReceipt))
            }
            .sheet(isPresented: $showEmailSheet) {
                EmailReceiptSheet(
                    receipt: displayedReceipt,
                    onSent: {
                        showEmailSheet = false
                        onEmailSent?()
                    },
                    onCancel: { showEmailSheet = false }
                )
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { onDismiss?() }
                }
            }
        }
        .interactiveDismissDisabled(onNoReceipt != nil)
    }
}

// MARK: - Styled receipt content (Path colours, logo top right, richer fonts)
struct ReceiptContentView: View {
    let receipt: FullReceipt
    private let pathGreen = Color(hex: "#3B9F40")

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header: logo left, merchant details below
                VStack(alignment: .leading, spacing: 4) {
                    Image("PathCafeLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 72)
                        .padding(6)
                        .background(Color.white)
                        .cornerRadius(8)
                        .padding(.bottom, 6)
                    Text(receipt.merchantName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(pathGreen)
                    Text(receipt.merchantAddress)
                        .font(.subheadline)
                        .foregroundColor(pathGreen.opacity(0.9))
                    HStack(spacing: 4) {
                        Text("Order: \(receipt.orderNumber)")
                        Text("•")
                        Text("Till: \(receipt.tillNumber)")
                        Text("•")
                        Text(receipt.cashierName)
                    }
                    .font(.caption)
                    .foregroundColor(pathGreen.opacity(0.8))
                    Text(FullReceipt.formatDate(receipt.orderDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 8)

                separator

                // Line items
                ForEach(Array(receipt.lineItems.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 4) {
                        Text("\(item.quantity) x \(item.name)")
                            .font(.subheadline)
                        Spacer(minLength: 8)
                        Text("£\(String(format: "%.2f", item.lineTotal))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .fixedSize()
                            .padding(.trailing, 16)
                    }
                    .padding(.vertical, 2)
                }

                separator

                // Totals
                totalRow("Subtotal", receipt.subtotal)
                totalRow("VAT", receipt.vatAmount)
                HStack(spacing: 4) {
                    Text("TOTAL")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(pathGreen)
                    Spacer(minLength: 8)
                    Text("£\(String(format: "%.2f", receipt.total))")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(pathGreen)
                        .fixedSize()
                        .padding(.trailing, 16)
                }
                .padding(.vertical, 4)

                if let card = receipt.cardReceiptBlock {
                    separator
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PAYMENT")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        Text(card.status)
                            .font(.caption)
                        Text(card.timestamp)
                            .font(.caption)
                        Text(card.txnRef)
                            .font(.caption)
                        Text("Terminal ID: \(card.terminalId)")
                            .font(.caption)
                        Text("Merchant ID: \(card.merchantId)")
                            .font(.caption)
                        Text("Authorization: \(card.authCode)")
                            .font(.caption)
                        Text("Verification: \(card.verification)")
                            .font(.caption)
                        Text("AID: \(card.aid)")
                            .font(.caption)
                        Text("Entry Mode: \(card.entryMode)")
                            .font(.caption)
                        Text("Account: \(card.maskedPan)")
                            .font(.caption)
                        Text("Card: \(card.cardScheme)")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }

                separator
                ForEach(receipt.footerLines, id: \.self) { line in
                    Text(line)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }
            }
        }
        .background(Color.white)
    }

    private var separator: some View {
        Rectangle()
            .fill(pathGreen.opacity(0.4))
            .frame(maxWidth: .infinity)
            .frame(height: 1)
            .padding(.vertical, 6)
    }

    private func totalRow(_ label: String, _ value: Double) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.subheadline)
            Spacer(minLength: 8)
            Text("£\(String(format: "%.2f", value))")
                .font(.subheadline)
                .fixedSize()
                .padding(.trailing, 16)
        }
        .padding(.vertical, 1)
    }
}

// MARK: - Email capture and send
struct EmailReceiptSheet: View {
    let receipt: FullReceipt
    let onSent: () -> Void
    let onCancel: () -> Void

    @State private var email: String = ""
    @State private var isSending = false
    @State private var message: String = ""
    @State private var showAlert = false
    @FocusState private var emailFocused: Bool

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Customer email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($emailFocused)
                } header: {
                    Text("Email address")
                }
                if !message.isEmpty {
                    Section {
                        Text(message)
                            .foregroundColor(isSending ? .secondary : (message.contains("failed") ? .red : .green))
                    }
                }
            }
            .navigationTitle("Email receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                        .disabled(isSending)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { sendEmail() }
                        .disabled(email.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
                }
            }
            .onAppear { emailFocused = true }
            .alert("Email receipt", isPresented: $showAlert) {
                Button("OK") {
                    if message.contains("Sent") { onSent() }
                }
            } message: {
                Text(message)
            }
        }
    }

    private func sendEmail() {
        let addr = email.trimmingCharacters(in: .whitespaces)
        guard !addr.isEmpty else { return }
        isSending = true
        message = "Sending..."
        let pdfData = ReceiptRenderer.pdfData(from: receipt)
        Task {
            do {
                try await ReceiptEmailSender.send(pdf: pdfData, to: addr, subject: "Your receipt from \(receipt.merchantName)")
                await MainActor.run {
                    isSending = false
                    message = "Sent to \(addr)."
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    isSending = false
                    message = "Failed: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
}

/// Presents print dialog with PDF when the view appears.
struct PrintSheet: UIViewControllerRepresentable {
    let pdfData: Data

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard context.coordinator.presented else {
            context.coordinator.presented = true
            let print = UIPrintInteractionController.shared
            let printInfo = UIPrintInfo.printInfo()
            printInfo.outputType = .general
            printInfo.jobName = "Receipt"
            print.printInfo = printInfo
            print.printingItem = pdfData
            DispatchQueue.main.async {
                print.present(animated: true) { _, _, _ in }
            }
            return
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    class Coordinator { var presented = false }
}
