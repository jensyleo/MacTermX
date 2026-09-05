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

Early scaffold — Apple Silicon, macOS 13+. `MacTermXCore` is a Swift
package exposing a `SerialTransport` protocol (backed by
[ORSSerialPort](https://github.com/armadsen/ORSSerialPort), MIT) so the UI
never opens a device directly. Nothing here is functional yet beyond a
placeholder window.

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
