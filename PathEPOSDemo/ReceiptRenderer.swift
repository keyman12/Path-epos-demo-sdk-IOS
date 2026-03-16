//
//  ReceiptRenderer.swift
//  PathEPOSDemo
//
//  Renders FullReceipt to plain text and PDF (receipt-width, monospaced).
//  UIGraphicsPDFRenderer uses UIKit coordinates (origin top-left, Y down).
//

import UIKit
import PathCoreModels

enum ReceiptRenderer {
    private static let receiptWidthPoints: CGFloat = 226  // ~80mm
    private static let fontPointSize: CGFloat = 10
    private static let lineSpacing: CGFloat = 4
    private static let margin: CGFloat = 12
    private static let maxLineLength = 34

    private static let separator = String(repeating: "-", count: maxLineLength)
    private static let paymentSeparator = String(repeating: "=", count: maxLineLength)
    private static let paymentEndSep = String(repeating: "=", count: maxLineLength)

    /// Right-aligns a price string so item name + price fills exactly maxLineLength chars.
    private static func priceRow(label: String, price: String) -> String {
        let gap = maxLineLength - label.count - price.count
        let padding = gap > 0 ? String(repeating: " ", count: gap) : " "
        return label + padding + price
    }

    /// Plain text: 1) Header 2) Items + totals 3) Regulated payment 4) Footer.
    static func plainText(from receipt: FullReceipt) -> String {
        var lines: [String] = []
        lines.append(receipt.merchantName)
        lines.append(receipt.merchantAddress)
        lines.append("")
        lines.append("Order: \(receipt.orderNumber)   Till: \(receipt.tillNumber)   \(receipt.cashierName)")
        lines.append(FullReceipt.formatDate(receipt.orderDate))
        lines.append(separator)
        for item in receipt.lineItems {
            let label = "\(item.quantity) x \(item.name)"
            let price = "£\(String(format: "%.2f", item.lineTotal))"
            lines.append(priceRow(label: label, price: price))
        }
        lines.append(separator)
        lines.append(priceRow(label: "Subtotal:", price: "£\(String(format: "%.2f", receipt.subtotal))"))
        lines.append(priceRow(label: "VAT:",     price: "£\(String(format: "%.2f", receipt.vatAmount))"))
        lines.append(priceRow(label: "TOTAL:",   price: "£\(String(format: "%.2f", receipt.total))"))
        if let card = receipt.cardReceiptBlock {
            lines.append("")
            lines.append(paymentSeparator)
            lines.append("PAYMENT")
            lines.append(paymentEndSep)
            lines.append(card.status)
            lines.append(card.timestamp)
            lines.append(card.txnRef)
            lines.append("Terminal ID: \(card.terminalId)")
            lines.append("Merchant ID: \(card.merchantId)")
            lines.append("Authorization: \(card.authCode)")
            lines.append("Verification: \(card.verification)")
            lines.append("AID: \(card.aid)")
            lines.append("Entry Mode: \(card.entryMode)")
            lines.append("Account: \(card.maskedPan)")
            lines.append("Card: \(card.cardScheme)")
            lines.append(paymentEndSep)
        }
        for footer in receipt.footerLines {
            lines.append("")
            lines.append(footer)
        }
        return lines.joined(separator: "\n")
    }

    private static let pathGreen = UIColor(red: 59/255, green: 159/255, blue: 64/255, alpha: 1)

    /// PDF data (receipt-width) for print/email. Path logo top right, green header/separators.
    static func pdfData(from receipt: FullReceipt) -> Data {
        let text = plainText(from: receipt)
        let lines = text.components(separatedBy: "\n")
        let font = UIFont(name: "Courier", size: fontPointSize) ?? UIFont.monospacedSystemFont(ofSize: fontPointSize, weight: .regular)
        let boldFont = UIFont(name: "Courier-Bold", size: fontPointSize) ?? font
        let lineHeight = font.lineHeight + lineSpacing
        let logoHeight: CGFloat = 56  // 100% bigger than 28
        let pageHeight = margin + logoHeight + 4 + CGFloat(lines.count) * lineHeight + margin
        let pageRect = CGRect(x: 0, y: 0, width: receiptWidthPoints, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { ctx in
            ctx.beginPage()
            var drawY = margin
            if let logo = UIImage(named: "PathCafeLogo") {
                let logoW = logo.size.width * (logoHeight / logo.size.height)
                logo.draw(in: CGRect(x: margin, y: drawY, width: logoW, height: logoHeight))
            }
            drawY += logoHeight + 4
            for (index, line) in lines.enumerated() {
                let drawn = line.count <= maxLineLength ? line : String(line.prefix(maxLineLength - 1)) + "…"
                let useBold = index == 0
                let attrs: [NSAttributedString.Key: Any] = [.font: useBold ? boldFont : font, .foregroundColor: UIColor.black]
                let attrString = NSAttributedString(string: drawn, attributes: attrs)
                attrString.draw(at: CGPoint(x: margin, y: drawY))
                drawY += lineHeight
            }
        }
    }
}
