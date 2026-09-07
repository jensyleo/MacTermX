import Foundation

public enum TransferError: Error, Equatable {
    case timeout
    case cancelled
    case tooManyRetries
    case peerCancelled
    /// A receive grew past its safety ceiling without the sender ever
    /// signaling end-of-transfer — guards against a malicious or
    /// malfunctioning device streaming blocks forever and exhausting
    /// memory. See `TransferLimits.maxReceiveBytes`.
    case payloadTooLarge
}

/// Safety ceilings shared by the XMODEM/YMODEM/ZMODEM receive paths, all
/// of which accumulate bytes in memory until the sender signals it's
/// done. Untrusted/flaky serial hardware can't be trusted to ever send
/// that signal, so every receive loop checks against this cap instead of
/// growing without bound.
public enum TransferLimits {
    /// Generous enough for real firmware/config-file transfers over a
    /// legacy serial link (which is inherently slow — nobody is pushing
    /// gigabytes over XMODEM at 115200 baud) while still bounding worst-
    /// case memory use from a stream that never terminates.
    public static let maxReceiveBytes = 64 * 1024 * 1024
}

/// Feeds a transfer engine (XMODEM/YMODEM/ZMODEM) a byte stream it doesn't
/// own the source of. `SessionCoordinator` is the sole consumer of
/// `SerialTransport.events` (see `TerminalEngine`'s doc comment for why —
/// an `AsyncStream` only delivers each event to one reader); while a
/// transfer is active it calls `push(_:)` here instead of feeding the
/// terminal. This gives the transfer engine a private, dedicated stream it
/// really does own, so it can safely await bytes with a timeout.
public final class TransferByteChannel: @unchecked Sendable {
    private let stream: AsyncStream<UInt8>
    private let continuation: AsyncStream<UInt8>.Continuation
    private var iterator: AsyncStream<UInt8>.AsyncIterator

    public init() {
        var continuation: AsyncStream<UInt8>.Continuation!
        let stream = AsyncStream<UInt8> { continuation = $0 }
        self.stream = stream
        self.continuation = continuation
        self.iterator = stream.makeAsyncIterator()
    }

    public func push(_ data: Data) {
        for byte in data { continuation.yield(byte) }
    }

    public func finish() {
        continuation.finish()
    }

    /// Waits for the next byte, or throws `.timeout` if none arrives in time.
    public func readByte(timeout: Duration) async throws -> UInt8 {
        let result = try await withThrowingTaskGroup(of: UInt8?.self) { group -> UInt8? in
            group.addTask { await self.iterator.next() }
            group.addTask {
                try await Task.sleep(for: timeout)
                return nil
            }
            defer { group.cancelAll() }
            return try await group.next() ?? nil
        }
        guard let byte = result else { throw TransferError.timeout }
        return byte
    }
}
