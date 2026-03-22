# Path EPOS – iPad demo (PathTerminalSDK)

A SwiftUI EPOS demo for **iPad** that integrates with the **Path POS Emulator** (Raspberry Pi Pico) **only through [PathTerminalSDK](https://github.com/keyman12/Path-terminal-sdk)**. The app does **not** use direct CoreBluetooth / Nordic UART calls for the supported card flow — it uses **`PathTerminal`** and **`BLEPathTerminalAdapter`** from the SDK.

Supports **sales** and **refunds**, a **transaction log**, and **cash or card** payment.

## Features

### EPOS
- **Inventory grid** – Custom icons and prices (€), category filter
- **Cart** – Right sidebar, running total, Complete Transaction
- **Payment** – Cash or Card; scrollable transaction summary
- **Branding** – Path logo, primary color #3B9F40

### Path SDK & emulator (Pico)
- **Card payments** – **Settings → Manage Devices**: scan and connect to **Path POS Emulator**; **Sale** is sent via the SDK with amount/currency; ACK and result drive the UI
- **Refunds** – Transaction Log → **Refund** → card path sends **Refund** with the same JSON envelope style as Sale (`cmd: "Refund"`)
- **Wire format** – Newline-delimited JSON (handled inside the SDK’s BLE adapter), e.g.  
  `{"req_id":"...","args":{"amount":<minor>,"currency":"GBP"},"cmd":"Sale"|"Refund"}\n`

### Transaction Log
- **Settings → Transaction Log** – Terminal and cash transactions
- **Columns** – URN, Card Number (masked or “Cash”), Value (£), Date, Time, Status, Refund
- **Cash** – Logged with “Cash” in the Card column (no Pico)
- **Card** – Terminal sales/refunds with masked PAN and status from the terminal result
- **Clear log** – Toolbar option

## Build

1. **Add the Swift package** (if not already resolved):  
   **File → Add Package Dependencies…** →  
   `https://github.com/keyman12/Path-terminal-sdk`  
   Add **PathTerminalSDK** (and related products) to the app target.
2. Open **`PathEPOSDemo.xcodeproj`** in Xcode 15+ (or the duplicate project if you use it locally).
3. Target: **iPadOS 17+**; run on simulator or device.

## Structure (high level)

| Area | Purpose |
|------|---------|
| `PathEPOSDemo/` | SwiftUI views, models, assets |
| `SDKTerminalManager.swift` | Wraps **`PathTerminal`** + **`BLEPathTerminalAdapter`**; connection state, logging, transaction log persistence |
| `TerminalConnectionManager.swift` / **Settings** | Device scan, connect, last-terminal hints |
| `Models.swift` | Cart, inventory, `TerminalTransactionLogEntry`, etc. |
| `CardProcessingView.swift` / `RefundView.swift` / `PaymentView.swift` | Payment flows using the SDK |

Legacy or experimental BLE helpers may still exist in the tree for diagnostics; the **supported integration path** is **PathTerminalSDK only**.

## BLE setup

1. Flash/run **[PosEmulator](https://github.com/keyman12/PosEmulator)** on the Pico; it should advertise as **Path POS Emulator**.
2. In the app: **Settings** → **Manage Devices** → **Scan** → select the emulator.
3. After the SDK reports connected, card payments and refunds use that link.

## Related repositories

| Repo | Role |
|------|------|
| [Path-terminal-sdk](https://github.com/keyman12/Path-terminal-sdk) | Swift package, docs, schemas |
| [PosEmulator](https://github.com/keyman12/PosEmulator) | Pico firmware |
| **This repo** | iPad EPOS demo |

See also **[Path-terminal-sdk DEVELOPMENT.md](https://github.com/keyman12/Path-terminal-sdk/blob/main/DEVELOPMENT.md)** for the full three-repo layout.

---
© Path – Demo use only.
