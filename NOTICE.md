# Third-Party Notices

MacTermX is licensed under the GNU General Public License v3.0 (see
`LICENSE`). It links two third-party Swift packages, both under the MIT
license — permissive licenses can be linked into a GPL-3.0 binary without
conflict (the combined work is still distributed under GPL-3.0, and both
MIT notices below must travel with any binary distribution).

This file exists so that dependency choice is never silent: what's used,
why, under what license, and whether a GPL-native replacement is
realistic. For the complete, flat accounting — every resolved package
including transitive ones, and whether each is actually linked into the
app — see `docs/dependency-license-matrix.md`.

---

## 1. ORSSerialPort

- **Used for:** `SerialTransport` — opening, configuring, reading, and
  writing the actual serial port (`MacTermXCore/Sources/MacTermXCore/Serial/ORSSerialTransport.swift`,
  `ORSPortDiscovery.swift`).
- **License:** MIT. Copyright (c) 2011-2012 Andrew R. Madsen.
- **Repository:** <https://github.com/armadsen/ORSSerialPort>
- **Why this one:** researched explicitly (2026-09-04) against a GPL
  requirement — see "GPL replacement feasibility" below. No maintained
  GPL serial-port library exists for Swift/macOS. ORSSerialPort won on
  its own merits too: mature, macOS-native (IOKit/BSD serial APIs, not a
  cross-platform shim), explicit RTS/CTS and DTR/RTS signal control,
  hot-plug detection via KVO, native Swift Package Manager support.

### GPL replacement feasibility

Not currently viable. The one real GPL-family candidate is
[libserialport](https://sigrok.org/wiki/Libserialport) (sigrok project)
— but it is actually **LGPL-3.0**, not GPL, and has no maintained Swift
binding for macOS; a community report noted it failing to load correctly
on macOS at all. Adopting it today would mean writing and maintaining a
C-interop wrapper from scratch around an unmaintained-for-macOS library —
trading a working, tested dependency for an unproven one, for a
licensing preference rather than a functional gain (MIT already permits
everything GPL-3.0 needs from a dependency).

**Revisit when:** a maintained GPL (or LGPL, which is compatible either
way) serial library appears for Swift/macOS, or if ORSSerialPort becomes
unmaintained/incompatible with a future Swift/macOS release and a rewrite
is needed anyway — at that point, evaluate writing a from-scratch
POSIX/IOKit serial layer (see `ZTerm_Next_macOS_Investigacion_y_Plan_Desarrollo.md`,
section 9, "Opción C") as an in-house GPL-licensed replacement, since it
would already require new code with no upstream license to inherit from.

---

## 2. SwiftTerm

- **Used for:** `TerminalEngine` — the ANSI/VT100 parser and screen
  buffer (`MacTermXCore/Sources/MacTermXCore/Terminal/TerminalEngine.swift`).
  Only its headless core is used, not its bundled AppKit `TerminalView`;
  MacTermX renders its own SwiftUI console from `snapshotLines()`.
- **License:** MIT. Copyright (c) 2019-2026 Miguel de Icaza and others
  (xterm.js authors, SourceLair, Christopher Jeffrey — SwiftTerm's parser
  traces its lineage to xterm.js).
- **Repository:** <https://github.com/migueldeicaza/SwiftTerm>
- **Why this one:** researched explicitly (2026-09-04). It is, in
  practice, the only actively maintained terminal-emulation engine in
  the Swift ecosystem — searches turned up only forks/derivatives of
  SwiftTerm itself, no independent competitor. Broad, well-tested
  CSI/OSC/DCS/Sixel/Kitty coverage that a rewrite would take significant
  time to replicate.

### GPL replacement feasibility

Not realistic in the near term. Writing a from-scratch VT100/ANSI parser
is a substantial, security-sensitive undertaking on its own (see the
CVE-2022-23465-class risk noted in `TerminalEngine`'s design — malformed
escape sequences from an untrusted serial device are a real attack
surface), and SwiftTerm is the only option that has already absorbed
years of that hardening. A GPL rewrite would need to match or exceed its
sequence coverage before it could safely replace it.

**Revisit when:** the terminal-parsing needs of MacTermX stabilize
enough (post-hardware-testing) that a scoped, MacTermX-specific parser —
covering only the sequences legacy/embedded/OT devices actually emit,
not full xterm compatibility — becomes a realistic, smaller project than
matching SwiftTerm wholesale. That would be a natural GPL-native
replacement, since it would be written for MacTermX from zero.

---

## Summary table

| Dependency | License | Replaceable with GPL today? | Tracked for future replacement |
|---|---|---|---|
| ORSSerialPort | MIT | No — no maintained GPL alternative exists | Yes, see above |
| SwiftTerm | MIT | No — no maintained GPL alternative exists | Yes, see above |

Both dependencies were chosen after an explicit GPL-first search (see
project history / commit log for 2026-09-04) that came up empty in both
cases. This file should be updated whenever that search is repeated or a
replacement is attempted.
