import Foundation
import ORSSerial

/// `PortDiscovering` backed by `ORSSerialPortManager`, which enumerates
/// `/dev/cu.*` and posts KVO notifications on hot-plug.
public final class ORSPortDiscovery: NSObject, PortDiscovering, @unchecked Sendable {
    private let continuation: AsyncStream<PortChange>.Continuation
    public let changes: AsyncStream<PortChange>
    private var observation: NSKeyValueObservation?

    public override init() {
        var continuation: AsyncStream<PortChange>.Continuation!
        self.changes = AsyncStream { continuation = $0 }
        self.continuation = continuation
        super.init()
        observation = ORSSerialPortManager.shared().observe(\.availablePorts) { [weak self] manager, _ in
            guard let self else { return }
            for port in manager.availablePorts {
                self.continuation.yield(.connected(port.asSerialDevice))
            }
        }
    }

    public func availablePorts() async throws -> [SerialDevice] {
        ORSSerialPortManager.shared().availablePorts.map { $0.asSerialDevice }
    }
}

private extension ORSSerialPort {
    var asSerialDevice: SerialDevice {
        SerialDevice(path: path, name: name)
    }
}
