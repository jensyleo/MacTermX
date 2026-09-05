import Foundation
import SwiftTerm

/// Wires a `SerialTransport` to SwiftTerm's headless `Terminal` (parser +
/// screen buffer), without using SwiftTerm's `TerminalView`. MacTermX owns
/// SwiftUI rendering of the buffer and can bound/sanitize raw serial bytes
/// before they reach the parser — the host device is untrusted input.
///
/// `TerminalEngine` does not read `transport.events` itself: an
/// `AsyncStream` delivers each element to exactly one consumer, and
/// `SessionCoordinator` already owns that subscription (it also needs
/// `.opened`/`.closed`/`.error` for its state machine). Incoming bytes
/// reach the parser via `feed(_:)`, called by whoever does own the stream.
@MainActor
public final class TerminalEngine {
    public let terminal: Terminal
    private let transport: SerialTransport
    // `Terminal.tdel` holds this weakly, so TerminalEngine must keep the
    // only strong reference alive itself.
    private let delegate: Delegate

    /// Called after every `feed(_:)`, so a view model can re-render its
    /// snapshot of the buffer. Not a Combine publisher: `Terminal` isn't
    /// `Sendable`/observable itself, so the simplest correct hook is a
    /// plain callback fired on the same `@MainActor` this class runs on.
    public var onUpdate: (() -> Void)?

    public init(transport: SerialTransport, options: TerminalOptions = .default) {
        self.transport = transport
        let delegate = Delegate()
        self.delegate = delegate
        self.terminal = Terminal(delegate: delegate, options: options)
        delegate.owner = self
    }

    public func feed(_ data: Data) {
        terminal.feed(byteArray: [UInt8](data))
        onUpdate?()
    }

    /// Renders the visible screen (not scrollback) as plain text lines,
    /// for a simple SwiftUI text-based console. Drops SwiftTerm's styling
    /// (color, bold, etc.) — MacTermX's own renderer can read those
    /// attributes from `terminal` directly later if it needs them.
    public func snapshotLines() -> [String] {
        (0..<terminal.rows).map { row in
            String((0..<terminal.cols).map { terminal.getCharacter(col: $0, row: row) ?? " " })
        }
    }

    public func sendUserInput(_ data: Data) async throws {
        try await transport.write(data)
    }

    private final class Delegate: TerminalDelegate {
        weak var owner: TerminalEngine?

        func send(source: Terminal, data: ArraySlice<UInt8>) {
            guard let owner else { return }
            let bytes = Data(data)
            Task { try? await owner.sendUserInput(bytes) }
        }
    }
}
