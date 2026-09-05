import Foundation

public enum TransferError: Error, Equatable {
    case timeout
    case cancelled
    case tooManyRetries
    case peerCancelled
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
