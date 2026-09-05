import Combine
import Foundation

/// One serial session: a profile, its transport, and the terminal engine
/// feeding off it, tracked through a single explicit state machine.
/// `ObservableObject`/`@Published` (not the newer `@Observable` macro) so
/// this stays usable back to macOS 13.
@MainActor
public final class SessionCoordinator: ObservableObject {
    @Published public private(set) var state: SessionState = .disconnected
    @Published public private(set) var cts = false
    @Published public private(set) var dsr = false
    @Published public private(set) var dcd = false
    public let profile: SerialProfile
    public let terminal: TerminalEngine
    private let transport: SerialTransport
    private var eventTask: Task<Void, Never>?
    private var transferChannel: TransferByteChannel?

    /// Every received byte, before it reaches the VT100 parser — for a hex
    /// view or a capture/log file, which need the raw wire bytes rather
    /// than SwiftTerm's interpreted screen buffer.
    public var onRawIncomingData: ((Data) -> Void)?

    public init(profile: SerialProfile, transport: SerialTransport) {
        self.profile = profile
        self.transport = transport
        self.terminal = TerminalEngine(transport: transport)
        // `terminal.snapshotLines()` isn't itself Published — forward its
        // updates as ordinary SwiftUI change notifications.
        self.terminal.onUpdate = { [weak self] in self?.objectWillChange.send() }
    }

    public func connect() async {
        guard state == .disconnected || isFailed else { return }
        state = .opening
        eventTask = Task { [weak self] in
            guard let self else { return }
            for await event in transport.events {
                await self.handle(event)
            }
        }
        do {
            try await transport.open(configuration: profile.serial)
        } catch {
            state = .failed(String(describing: error))
        }
    }

    public func disconnect() async {
        state = .closing
        await transport.close()
        eventTask?.cancel()
        eventTask = nil
        state = .disconnected
    }

    public func sendUserInput(_ data: Data) async throws {
        try await terminal.sendUserInput(data)
    }

    public func setSignals(_ signals: ModemSignals) async throws {
        try await transport.setSignals(signals)
    }

    /// Switches incoming bytes away from the VT100 parser and into a
    /// dedicated channel for a file transfer engine (XMODEM/YMODEM/ZMODEM)
    /// to read from — the same "only one consumer of an event stream"
    /// constraint `TerminalEngine`'s doc comment describes, just resolved
    /// by mode instead of by a permanent owner. Also switches `state` to
    /// `.transferring`, so the UI can't start a second transfer or an
    /// accidental disconnect mid-transfer.
    public func beginTransfer() -> TransferByteChannel {
        let channel = TransferByteChannel()
        transferChannel = channel
        state = .transferring
        return channel
    }

    /// Restores normal terminal operation after a transfer finishes,
    /// succeeds or fails.
    public func endTransfer() {
        transferChannel = nil
        if state == .transferring { state = .connected }
    }

    private var isFailed: Bool {
        if case .failed = state { return true }
        return false
    }

    private func handle(_ event: SerialEvent) async {
        switch event {
        case .opened:
            state = .connected
        case .closed:
            if !isFailed { state = .disconnected }
        case .error(let message):
            state = .failed(message)
        case .data(let data):
            if let transferChannel {
                transferChannel.push(data)
            } else {
                onRawIncomingData?(data)
                terminal.feed(data)
            }
        case .signals(let cts, let dsr, let dcd, _):
            self.cts = cts
            self.dsr = dsr
            self.dcd = dcd
        }
    }
}
