# Dependency License Matrix

Formal companion to `NOTICE.md` (which explains the *why* behind each choice
and the GPL-replacement outlook). This file is the complete, flat
accounting: every package SwiftPM resolves for MacTermX, its exact
license, and whether it's actually linked into the shipping app.

Regenerate the "resolved" column by inspecting
`MacTermXCore/Package.resolved` after any dependency change, and re-check
this table before every release.

## Direct dependencies (declared in `MacTermXCore/Package.swift`)

| Package | Resolved version | License | Linked into MacTermX? |
|---|---|---|---|
| [ORSSerialPort](https://github.com/armadsen/ORSSerialPort) | 2.1.0 | MIT | Yes — `MacTermXCore` target links its `ORSSerial` product |
| [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) | 1.20.0 | MIT | Yes — `MacTermXCore` target links its `SwiftTerm` product |

## Transitive dependencies (pulled in by the above, per `Package.resolved`)

| Package | Resolved version | License | Linked into MacTermX? |
|---|---|---|---|
| [swift-argument-parser](https://github.com/apple/swift-argument-parser) | 1.8.2 | Apache-2.0 | **No.** SwiftTerm's own `Package.swift` only uses it for `Termcast`, a demo CLI executable target that ships inside SwiftTerm's repo, not for the `SwiftTerm` library product MacTermX actually depends on. SwiftPM still resolves it as part of the full package graph, but it's never compiled into MacTermX's own build. |

## App-local tooling (not shipped in the app bundle)

| Tool | License | Notes |
|---|---|---|
| [XcodeGen](https://github.com/yonaskolb/XcodeGen) | MIT | Generates `MacTermX.xcodeproj` from `project.yml`; a build-time tool, not a linked dependency. |

## License compatibility summary

MacTermX itself is GPL-3.0 (`LICENSE`). Every dependency actually linked
into the app (ORSSerialPort, SwiftTerm) is MIT, which is permissive and
freely combinable into a GPL-3.0 work — the combined binary is
distributed under GPL-3.0, and both MIT copyright notices travel with it
(satisfied by this file plus `NOTICE.md`). Apache-2.0
(swift-argument-parser) never actually enters the binary, so no
Apache/GPL interaction needs resolving today — noted here only for
completeness, in case a future SwiftTerm update changes which of its
targets MacTermX ends up depending on.

No copyleft (GPL/LGPL/AGPL) dependency is present. If one is ever added,
re-verify explicitly: a GPL-3.0-or-later dependency is fine (same
license); an LGPL dependency is fine if only dynamically linked or used
per its own terms; a GPL-2.0-only dependency would conflict outright and
block the merge.
