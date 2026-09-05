import Foundation
import SwiftTerm

/// Wires a `SerialTransport` to SwiftTerm's headless `Terminal` (parser +
/// screen buffer), without using SwiftTerm's `TerminalView`. MacTermX owns
/// SwiftUI rendering of the buffer and can bound/sanitize raw serial bytes
/// before they reach the parser — the host device is untrusted input.
@MainActor
public final class TerminalEngine {
    public let terminal: Terminal
    private let transport: SerialTransport
    // `Terminal.tdel` holds this weakly, so TerminalEngine must keep the
    // only strong reference alive itself.
    private let delegate: Delegate
    private var readTask: Task<Void, Never>?

    public init(transport: SerialTransport, options: TerminalOptions = .default) {
        self.transport = transport
        let delegate = Delegate()
        self.delegate = delegate
        self.terminal = Terminal(delegate: delegate, options: options)
        delegate.owner = self

        readTask = Task { [weak self] in
            guard let self else { return }
            for await event in transport.events {
                guard case .data(let data) = event else { continue }
                self.terminal.feed(byteArray: [UInt8](data))
            }
        }
    }

    deinit {
        readTask?.cancel()
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
