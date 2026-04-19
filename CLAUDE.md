# Path EPOS Demo — iOS

You are working in the **fuller iPad EPOS demo** app. Canonical remote: `https://github.com/keyman12/Path-epos-demo-sdk-IOS` (the historic `Path-epos-demo-sdk` URL redirects here).

## Ecosystem at a glance

One of **7 repos** in the Path semi-integrated terminal system:

| iOS | Android | Cross-platform |
|---|---|---|
| `Path-terminal-sdk-IOS` | `path-terminal-sdk-android` | `Path-mcp-server` |
| `Path-epos-demo-sdk-IOS` ← **you are here** | `Path-epos-demo-sdk-android` | `PosEmulator` (Pico firmware) |
| `Path-EPOS-TestHarness-IOS` | `Path-EPOS-TestHarness-Android` | |

See `Path-terminal-sdk-IOS/DEVELOPMENT.md` for the canonical map.

## Role

Fuller SwiftUI iPad EPOS — the reference app we build **new SDK features** against. Represents a realistic customer app so features get exercised in a real-world context before they're considered done.

Distinction:
- **This repo (demo)** = fuller app, develop new SDK features here.
- **`Path-EPOS-TestHarness-IOS`** = simpler app kept in parity with the Android harness. Used to test **agentic SDK installs**, not for development.

## SDK dependency

Depends on **`Path-terminal-sdk-IOS`** via Swift Package Manager. No vendored SDK source — the app consumes `PathTerminal` + `BLEPathTerminalAdapter` (or `MockPathTerminalAdapter` in tests) through SPM.

## What lives here

- `PathEPOSDemo/` — app sources
- `PathEPOSDemoTests/`, `PathEPOSDemoUITests/` — test targets
- `PathEPOSwithPathSDK.xcodeproj` — Xcode project (open this one)
- `PathEPOSDemo.xctestplan` — test plan

## Commands

```bash
open PathEPOSwithPathSDK.xcodeproj
# Build + run in Xcode 15+, target iPadOS 17+
```

## When modifying payment flow

If you change how sale / refund / receipt fields are used, check parity with:
- `Path-EPOS-TestHarness-IOS` (simpler app — must keep matching behaviour)
- `Path-epos-demo-sdk-android` (Android sibling demo)
