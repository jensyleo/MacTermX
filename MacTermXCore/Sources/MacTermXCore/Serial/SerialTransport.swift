import Foundation

/// A single open serial connection. The UI never opens a device directly —
/// it always goes through an implementation of this protocol, so the
/// underlying library (or a mock, for tests) can be swapped freely.
public protocol SerialTransport: Sendable {
    var events: AsyncStream<SerialEvent> { get }
    func open(configuration: SerialConfiguration) async throws
    func write(_ data: Data) async throws
    func setSignals(_ signals: ModemSignals) async throws
    func close() async
}

/// Enumerates and watches `/dev/cu.*` ports.
public protocol PortDiscovering: Sendable {
    func availablePorts() async throws -> [SerialDevice]
    var changes: AsyncStream<PortChange> { get }
}
