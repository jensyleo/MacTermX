import Foundation
@testable import MacTermXCore

/// In-memory `SerialTransport` double for exercising higher-level logic
/// (like `TerminalEngine`) without real hardware or ORSSerialPort's IOKit
/// device matching, which rejects synthetic PTYs (see
/// ORSSerialTransport's use of `ORSSerialPort(path:)`).
final class MockSerialTransport: SerialTransport, @unchecked Sendable {
    let events: AsyncStream<SerialEvent>
    private let continuation: AsyncStream<SerialEvent>.Continuation
    private(set) var written: [Data] = []

    init() {
        var continuation: AsyncStream<SerialEvent>.Continuation!
        self.events = AsyncStream { continuation = $0 }
        self.continuation = continuation
    }

    func open(configuration: SerialConfiguration) async throws {
        continuation.yield(.opened)
    }

    func write(_ data: Data) async throws {
        written.append(data)
    }

    func setSignals(_ signals: ModemSignals) async throws {}

    func close() async {
        continuation.yield(.closed)
    }

    func simulateIncoming(_ data: Data) {
        continuation.yield(.data(data))
    }

    func simulateError(_ message: String) {
        continuation.yield(.error(message))
    }
}
