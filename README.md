# MacTermX

A native macOS serial terminal, built from scratch as a modern successor to
the workflow of classic serial terminal apps (ZTerm-style): connect to
equipment over a serial port, watch and log the session, automate repeat
tasks safely, and transfer files with XMODEM/YMODEM/ZMODEM when the device
requires it.

MacTermX shares no code, resources, or binaries with any prior serial
terminal application. It is a clean-room implementation targeting network
engineers, OT/ICS operators, embedded developers, electronics labs, and
legacy-device support.

## Status

Apple Silicon, macOS 13+. `MacTermXCore` is a Swift package exposing a
`SerialTransport` protocol (backed by
[ORSSerialPort](https://github.com/armadsen/ORSSerialPort), MIT) so the UI
never opens a device directly; the ANSI/VT engine is
[SwiftTerm](https://github.com/migueldeicaza/SwiftTerm), MIT, consumed at
its headless-core level rather than via its bundled AppKit view.

Implemented and building, but **not yet verified against real serial
hardware**:

- Port discovery (with hot-plug) and a full serial line/flow-control
  settings panel, modeled on CoolTerm/ZTerm.
- Terminal console: text and hex views, send-as-text/hex, local echo,
  configurable line ending, pause (freezes the display without stopping
  reception), buffer search.
- Multiple concurrent session tabs, de-duplicated by port; closing a tab
  mid-transfer asks for confirmation.
- Saved profiles: USB-identity matching (not by port path), duplicate,
  JSON export/import.
- Capture-to-file (raw received bytes).
- Quick commands/macros per device, with `{date}`/`{time}`/`{profile}`
  variables and a confirmation gate for commands marked dangerous.
- File transfer: XMODEM (checksum/CRC/1K), YMODEM (batch), and a
  simplified stop-and-wait ZMODEM — the last one is unverified against
  real hardware or `lrzsz` interoperability.
- Diagnostic export (version/OS/arch + sanitized serial config, no
  session content by default).
- A persistent "PRODUCTION" banner and multi-line-paste preview, both
  error-prevention aids from the original design doc.

Known gaps: XON/XOFF software flow control isn't implemented
(ORSSerialPort exposes no API for it), the app isn't localized (English
only; the design doc calls for Spanish too), and accessibility/VoiceOver
hasn't been audited. Terminal parsing currently runs on the main actor —
fine for interactive use, unverified under sustained high-baud-rate
throughput.

## Scope

In scope: serial port discovery and configuration, an ANSI/VT terminal
console, session profiles, capture/logging, safe macros, and legacy file
transfer protocols.

Out of scope for the MVP: RDP/VNC, VPN tunnels, remote agents, autonomous
AI-driven actions, cloud credential sync, a script marketplace, a custom
USB driver, advanced modem/dial-up support, and centralized fleet
management.

## License

Pending — to be decided after a dependency license audit.
