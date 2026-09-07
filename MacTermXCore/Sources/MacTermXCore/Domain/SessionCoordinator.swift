import Combine
import Foundation
import SwiftTerm

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
    /// Only active when the profile requests software flow control — see
    /// `XonXoffFlowController`'s doc comment for why this needs no
    /// termios/driver support. Not applied during a file transfer:
    /// XMODEM/YMODEM/ZMODEM have their own ACK/NAK-based flow control,
    /// and 0x11/0x13 are ordinary bytes that can legitimately appear in a
    /// binary payload — stripping them would corrupt the transfer.
    private let xonXoff: XonXoffFlowController?
    private let encoding: TextEncodingKind

    /// Every received byte, before it reaches the VT100 parser — for a hex
    /// view or a capture/log file, which need the raw wire bytes rather
    /// than SwiftTerm's interpreted screen buffer. Already transcoded to
    /// UTF-8 per `encoding` (see `TextEncodingKind`), same as what the
    /// parser sees.
    public var onRawIncomingData: ((Data) -> Void)?

    /// - Parameters:
    ///   - termName: The terminal type to report, e.g. `"xterm-256color"`,
    ///     `"vt100"`, or `"ansi"`. Passed straight to SwiftTerm without
    ///     the app layer needing to import SwiftTerm itself.
    ///   - scrollback: Scrollback buffer size in lines.
    public init(
        profile: SerialProfile,
        transport: SerialTransport,
        termName: String = "xterm-256color",
        scrollback: Int = 500,
        encoding: TextEncodingKind = .utf8
    ) {
        self.profile = profile
        self.transport = transport
        self.encoding = encoding
        self.xonXoff = profile.serial.flowControl == .xonXoff ? XonXoffFlowController() : nil
        var options = TerminalOptions.default
        options.termName = termName
        options.scrollback = scrollback
        self.terminal = TerminalEngine(transport: transport, options: options)
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
        if let xonXoff {
            await xonXoff.waitUntilClearToSend()
        }
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
                let filtered: Data
                if let xonXoff {
                    filtered = await xonXoff.filterIncoming(data)
                } else {
                    filtered = data
                }
                let transcoded = encoding.transcodeToUTF8(filtered)
                onRawIncomingData?(transcoded)
                terminal.feed(transcoded)
            }
        case .signals(let cts, let dsr, let dcd, _):
            self.cts = cts
            self.dsr = dsr
            self.dcd = dcd
        }
    }
}
