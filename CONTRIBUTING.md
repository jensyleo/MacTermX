# Contributing

MacTermX is a personal, GPL-3.0 project — there's no formal contributor
process, but issues and pull requests are welcome.

## Reporting bugs

Open a GitHub issue with:

- macOS version and Mac model (Apple Silicon only is supported today).
- The serial adapter/device involved, if relevant (vendor/product IDs
  from the port list help).
- Steps to reproduce, and what you expected vs. what happened.
- Never include real device credentials, production configuration, or
  sensitive capture content — redact first.

## Working on the code

1. Requirements: Xcode with Swift 6 toolchain, [XcodeGen](https://github.com/yonaskolb/XcodeGen),
   and the Metal Toolchain component (`xcodebuild -downloadComponent MetalToolchain`) —
   SwiftTerm bundles Metal shaders for its own unused AppKit renderer, and the app
   won't build without it.
2. `xcodegen generate` to produce `MacTermX.xcodeproj` (it's gitignored — never commit it).
3. Build with `xcodebuild -project MacTermX.xcodeproj -scheme MacTermX -configuration Release
   -skipPackagePluginValidation build` (the flag is required — SwiftTerm ships a build-info
   Swift Package plugin Xcode otherwise refuses to run without interactive approval).
4. Run `MacTermXCore`'s tests with `swift test` from that directory before opening a PR —
   they're fast and cover the protocol engines (XMODEM/YMODEM/ZMODEM), the terminal
   plumbing, and the domain/storage layers.

## Design principles this project tries to hold to

- **The UI never opens a device directly** — everything serial-related goes through
  `SerialTransport`/`SessionCoordinator` in `MacTermXCore`, so it stays testable
  without hardware.
- **An `AsyncStream` of transport events has exactly one owner at a time** — see the doc
  comments on `TerminalEngine` and `SessionCoordinator.beginTransfer()` for why; a second
  consumer silently steals events instead of erroring, which is easy to reintroduce by
  accident.
- **Bytes off the wire are untrusted input.** Don't assume the device sends
  well-formed sequences, complete frames, or valid UTF-8.
- **No secrets in profiles, logs, or exported diagnostics by default.**

## License

By contributing, you agree your contribution is licensed under this project's GPL-3.0
license (see `LICENSE`).
