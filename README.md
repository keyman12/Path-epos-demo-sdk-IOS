# Path EPOS with Path SDK (PathEPOSwithPathSDK)

A SwiftUI EPOS demo for iPad that talks to the **Path POS Emulator** (Pico) **only via PathTerminalSDK**. No direct BLE code. Supports sales and refunds, transaction log, cash or card payment.

## Features

### EPOS
- **Inventory grid** – Custom icons and prices (€), category filter
- **Cart** – Right sidebar, running total, Complete Transaction
- **Payment** – Cash or Card; scrollable transaction summary
- **Branding** – Path logo, primary color #3B9F40

### Path SDK & Emulator (Pico)
- **Card payments** – Connect to the Pico terminal via the SDK (BLE adapter); send Sale with amount/currency; receive ACK and result
- **Refunds** – From the Transaction Log, tap Refund → Select Refund Method → Card sends a Refund command to the Pico (same JSON format as Sale, `cmd: "Refund"`)
- **Message format** – Newline‑delimited JSON: `{"req_id":"...","args":{"amount":<minor>,"currency":"GBP"},"cmd":"Sale"|"Refund"}\n`

### Transaction Log
- **Settings → Transaction Log** – List of all terminal and cash transactions
- **Columns** – URN, Card Number (masked or “Cash”), Value (£), Date, Time, Status (Success/Decline), Refund button
- **Cash** – Cash payments are logged with “Cash” in the Card column (no Pico involved)
- **Card** – Sales/refunds from the Pico are logged with masked card (e.g. **** **** **** 1234) and Status from the terminal result
- **Refund** – Tap Refund on a sale row to open the Refund screen and send a Refund to the Pico when Card is selected
- **Clear log** – Toolbar option to clear the transaction log

## Build

1. Open **PathEPOSwithPathSDK.xcodeproj** in Xcode 15+
2. Target: **PathEPOSDemo** (or the app target), **iPadOS 17+**
3. Run on iPad simulator or device

## Structure

- `PathEPOSDemo/` – App source (SwiftUI views, models)
- `SDKTerminalManager.swift` – Wraps PathTerminalSDK (PathTerminal + BLEPathTerminalAdapter); transaction log persistence
- `Models.swift` – Cart, inventory, `TerminalTransactionLogEntry` (URN, amount, type, status, isCash)
- `TransactionLogView.swift` – Transaction log list and Refund entry point
- `RefundView.swift` – Refund screen and RefundCardView (sends Refund to Pico)
- `CardProcessingView.swift` – Card payment flow (sends Sale to Pico)
- `PaymentView.swift` – Payment method selection; cash completion logs via `addCashTransaction`
- `Assets.xcassets/` – App and item icons

## Setup (SDK → Emulator)

1. Open **PathEPOSwithPathSDK.xcodeproj**. Ensure the PathTerminalSDK package is resolved (File → Packages → Resolve).
2. Ensure the Path POS Emulator (Pico) is powered on and advertising.
3. In the app: **Settings** (gear) → **Manage Devices** → **Scan** → select **Path POS Emulator**.
4. After connection, card payments and refunds use the connected terminal via the SDK.

## Version Notes

- **Transaction log** – URN, Status, Cash vs card, alternating row shading, clear log
- **Refund flow** – Refund screen (Select Refund Method), RefundCardView sends Refund to Pico
- **Cash transactions** – Logged in transaction log with “Cash” in Card column
- **BLE** – JSON over Nordic UART; Sale/Refund; ACK/result handling; chunked writes for MTU

---
© Path – Demo use only.
