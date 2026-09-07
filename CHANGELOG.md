# Changelog

All notable changes to MacTermX are documented in this file.

## [0.1.1] - 2026-09-07

### Added — app icon

Professional neón-styled app icon: neon-green X with RS-232 connector and signal indicators (PWR, TX, RX).

## [0.1.0] - 2026-09-07

### Fixed — security review findings and a real memory leak

Ran a focused security review of MacTermX's own code (not the vendored dependencies). No
RCE-class or path-traversal-exploitable issues found — YMODEM/ZMODEM filename sanitization
already handled `../` traversal, absolute paths, and empty names correctly; there's no
`Process`/shell invocation anywhere; profiles and diagnostics genuinely carry no secrets. Two
real availability/robustness gaps got fixed: XMODEM/YMODEM/ZMODEM's receive loops had no cap on
total bytes accumulated, so a malicious or just flaky device that never signals end-of-transfer
could grow memory unbounded until the app crashes (added `TransferLimits.maxReceiveBytes`, a
64 MB ceiling, checked at every accumulation point including the lowest-level ZMODEM subpacket
reader); and the sensitive-data redaction feature only ever looked at one incoming chunk at a
time, so a secret split across two reads from the device (trivially likely for anything as long
as a PEM private-key block) would slip through both halves unredacted — replaced with
`StreamingRedactor`, which keeps a small bounded overlap window so a pattern spanning a chunk
boundary still gets caught. Also found and fixed an unrelated real bug while auditing closures
for retain cycles: `FileTransferViewModel` stored each transfer's `Task` in a property, and that
Task's closure captured `self` strongly — every completed transfer permanently leaked one
`FileTransferViewModel` instance. Silenced the project's one remaining compiler warning (an
ORSSerialPort KVO handler needed an explicit `@Sendable` annotation) — Core and App both now
build with zero warnings.

### Added — remaining backlog items from the original design doc

Closed out the rest of the applicable pendientes list (GitHub publishing, the app icon, and
real-hardware verification stay explicitly deferred): RF-005 sensitive-data redaction for
captures (`SensitiveRedactor` — passwords, API keys, bearer tokens, PEM private-key blocks),
`CaptureLogger` gained selectable formats (plain text / JSONL with per-chunk timestamps / raw
binary) and writes a `.sha256` sidecar hash when a capture stops. Added an RX/TX encoding
setting (UTF-8/ASCII/Latin-1 — transcoded into UTF-8 before reaching SwiftTerm's parser, since
SwiftTerm itself assumes UTF-8 input), a terminal-type selector (xterm-256color/VT100/ANSI, via
SwiftTerm's own `termName`), and a configurable scrollback buffer size. Added command history
recall (Previous/Next Command buttons — raw arrow-key capture would need an `NSViewRepresentable`
text field instead of a plain SwiftUI one, not worth it yet). Added `CONTRIBUTING.md`,
`CODE_OF_CONDUCT.md`, and real screenshots in the README (captured against the actual app,
including one session connected to a real FTDI adapter).

### Validated — first real hardware test

Ran a genuine FTDI FT232R USB-serial adapter (not a simulated/mock transport) through both a new
CLI harness (`mactermx-hwtest`, built specifically for this — exercises `ORSPortDiscovery` and
`ORSSerialTransport` directly, no SwiftUI involved) and the actual app: port discovery correctly
reported vendor/product/serial IDs, connect/disconnect, write, DTR/RTS control, and baud-rate
reconfiguration (9600 through 115200) all worked without error. The Port Settings panel rendered
correctly against the live connection. No physical loopback or peer device was available, so
reception and the X/Y/ZMODEM transfer engines remain unverified against real hardware — that's
next once a loopback or a second device is available.

### Added — GPL-3.0 license, with MIT dependencies documented

Licensed the project under GPL-3.0 (`LICENSE`). Added `NOTICE.md`, a detailed writeup of the two
MIT-licensed dependencies (ORSSerialPort, SwiftTerm): why each was chosen, an explicit accounting
of why no maintained GPL alternative exists for either today (libserialport is LGPL with no
maintained macOS Swift binding; SwiftTerm has no independent competitor in the Swift ecosystem),
and what would need to be true to revisit that — a from-scratch POSIX/IOKit serial layer or a
MacTermX-scoped VT parser, respectively, once real-world needs are better understood.

### Closed — XON/XOFF software flow control

Turned out to be genuinely implementable, despite ORSSerialPort exposing no driver-level API for
it: XON/XOFF is just two reserved bytes (0x11/0x13) traveling in the data stream itself, not a
termios feature. Added `XonXoffFlowController` (an actor): halts outgoing writes when the device
sends XOFF, resumes on XON, and strips both control bytes before they reach the terminal parser,
capture, or hex view. Not applied during file transfers — XMODEM/YMODEM/ZMODEM have their own
ACK/NAK flow control, and 0x11/0x13 can legitimately appear in binary payloads.

### Closed — partial redraw-performance gap (RNF-003)

`TerminalEngine.onUpdate` now coalesces to roughly 60 Hz instead of firing once per `feed(_:)`
call. `snapshotLines()` is O(rows×cols); a bursty serial device could otherwise trigger far more
SwiftUI re-renders than the console could ever usefully display. Parsing itself still runs
synchronously on the main actor — SwiftTerm's `Terminal` isn't documented as safe to drive from a
background thread, so that part of the gap remains open pending real high-throughput testing.

### Added — Spanish localization

`Localizable.xcstrings` with translations for the app's UI strings, verified to compile to
`es.lproj/Localizable.strings` in the built app bundle. Known limitation: SwiftUI only
auto-localizes string literals at the `Text()`/`Button()` call site — a couple of strings built
from a variable don't pick up a translation (harmless: they just show English).

### Closed — accessibility gap in the session tab bar

`SessionTabBarView`'s tab-select region was built on `onTapGesture`, which VoiceOver can't see or
activate. Rebuilt as sibling `Button`s with proper labels, a "switches to this session tab" hint,
and selected-state traits. The CTS/DSR/DCD signal indicators (console and Port Settings) now
announce "active"/"inactive" instead of relying on color alone.

### Added — file transfer UI (XMODEM/YMODEM/ZMODEM)

A "Transfer Files…" sheet: protocol picker (XMODEM checksum/CRC/1K, YMODEM, ZMODEM), send/receive
with native file/folder pickers, cancel, live status. `SessionCoordinator` gained a transfer mode
(`beginTransfer()`/`endTransfer()`) that routes incoming bytes to the transfer engine's channel
instead of the VT100 parser while a transfer is running — the same "one consumer per event
stream" constraint the terminal engine already had to solve, just resolved per-mode instead of by
a single permanent owner. ZMODEM here is an intentionally simplified stop-and-wait implementation
(no real streaming or resume) — flagged in the UI, unverified against `lrzsz` or real hardware.

### Added — Quick Commands / macros (RF-006)

A per-device macro library (name, template, line ending, "requires confirmation" flag) with
`{date}`/`{time}`/`{profile}` variable expansion — a fixed substitution table, not a scripting
language, so a macro can never execute arbitrary logic. Dangerous commands require an explicit
confirmation dialog before they're sent.

### Added — multi-tab sessions (RF-008)

Each port or profile now opens in its own de-duplicated tab (selecting an already-open port just
switches to its tab). Closing a tab mid-transfer asks for confirmation first, since it would abort
the transfer. A tab bar shows each session's connection state at a glance.

### Added — diagnostic export (RF-009)

Version, macOS/architecture, and the active session's sanitized serial configuration — no session
content by default, matching the "sin datos de sesión por defecto" requirement from the original
design doc.

### Added — console Pause and buffer search

Pause freezes the displayed text/hex snapshot without stopping actual reception underneath —
SwiftTerm keeps parsing and `CaptureLogger` keeps logging, only the view's own refresh is held
back. Search filters displayed lines by a case-insensitive substring, with a match count.

### Added — persistent PRODUCTION banner and multi-line-paste preview

Two error-prevention aids straight from the original design doc's UX section: an environment
(lab/production) picker in Port Settings that shows a persistent red banner in the console when
set to production, and a confirmation sheet (with line count and full content preview) before
sending anything pasted that contains a newline.

### Added — saved profiles (RF-004): duplicate, export, import

Profiles can now be duplicated, exported to a JSON file, and imported back — always assigning a
fresh ID on import rather than trusting an ID from outside the app.

### Added — hex console view, send-as-hex, capture-to-file

Researched CoolTerm and SerialTool specifically for feature parity. Added a Text/Hex toggle for
the console (`HexDump`), a "send as hex" input mode, and "Capture to File…" (raw received bytes,
`CaptureLogger`). Explicitly left out of scope: Modbus, Python scripting, an oscilloscope view,
kernel-level COM sniffing — all SerialTool Pro-tier features that don't belong in a native serial
terminal.

### Added — serial Port Settings panel

Modeled on CoolTerm's and ZTerm's own connection-settings dialogs: baud rate (standard list plus
free-text custom value), data bits, parity, stop bits, flow control (with manual DTR/RTS toggles
when hardware flow control is off), and live CTS/DSR/DCD signal indicators wired up via
ORSSerialPort's KVO notifications (previously only read at connect time, never live).

### Added — first real SwiftUI UI

Port list with live discovery and hot-plug, and a terminal console (connect/disconnect, send
text, status). `SessionCoordinator` became `ObservableObject`; `TerminalEngine` gained `onUpdate`
and `snapshotLines()` so the console has something to render.

### Added — XMODEM, YMODEM, and ZMODEM transfer engines (Core, no UI yet at this point)

Built in that order, each against a synthetic loopback in tests before any hardware existed to
test against: XMODEM (checksum and CRC-16, retries, duplicate-block handling), then XMODEM-1K,
then YMODEM (batch transfer, header blocks, filename sanitization against path traversal), then a
from-scratch ZMODEM subset (byte escaping, CRC-32, stop-and-wait subpackets) — deliberately scoped
down from full streaming/resume ZMODEM, since that needs real hardware to validate safely.

### Added — session/profile/terminal core

`SerialProfile` + `ProfileStore` (versioned JSON, no secrets, USB-identity matching rather than by
port path — the same adapter can enumerate under a different `/dev/cu.*` path next time).
`SessionCoordinator`, a single explicit state machine per session (disconnected → opening →
connected → transferring/closing/failed). Fixed a real bug along the way: `TerminalEngine` and
`SessionCoordinator` both tried to consume the same transport event `AsyncStream`, which only ever
delivers each event to one reader — `SessionCoordinator` now owns that subscription exclusively
and feeds the terminal engine explicitly.

### Added — project scaffold

XcodeGen + SwiftPM structure (`MacTermXCore` package, `App` SwiftUI target). `SerialTransport`
backed by ORSSerialPort (MIT — researched explicitly against a GPL requirement first; no
maintained GPL serial library exists for Swift/macOS). `TerminalEngine` backed by SwiftTerm (MIT,
same story), consumed at its headless-core level rather than via its bundled AppKit view, so
MacTermX owns its own SwiftUI rendering.
