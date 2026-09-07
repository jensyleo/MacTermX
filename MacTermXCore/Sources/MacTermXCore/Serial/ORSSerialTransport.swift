import Foundation
@preconcurrency import ORSSerial

/// `SerialTransport` backed by ORSSerialPort.
public final class ORSSerialTransport: NSObject, SerialTransport, @unchecked Sendable {
    private var port: ORSSerialPort?
    private let continuation: AsyncStream<SerialEvent>.Continuation
    public let events: AsyncStream<SerialEvent>
    private var signalObservations: [NSKeyValueObservation] = []

    public init(devicePath: String) throws {
        guard let port = ORSSerialPort(path: devicePath) else {
            throw SerialTransportError.noPortSelected
        }
        var continuation: AsyncStream<SerialEvent>.Continuation!
        self.events = AsyncStream { continuation = $0 }
        self.continuation = continuation
        self.port = port
        super.init()
    }

    public func open(configuration: SerialConfiguration) async throws {
        guard let port else {
            throw SerialTransportError.noPortSelected
        }
        port.baudRate = NSNumber(value: configuration.baudRate)
        port.numberOfDataBits = UInt(configuration.dataBits)
        port.numberOfStopBits = UInt(configuration.stopBits)
        port.parity = configuration.parity.orsParity
        port.usesRTSCTSFlowControl = configuration.flowControl == .rtsCts
        // ORSSerialPort only exposes RTS/CTS and DTR/DSR *hardware* flow
        // control — there's no .xonXoff equivalent here because XON/XOFF
        // isn't a driver-level feature to begin with; it's two reserved
        // bytes (0x11/0x13) traveling in the data stream. That's handled
        // one layer up, in `SessionCoordinator`, via `XonXoffFlowController`.
        port.delegate = self
        port.open()
        observeSignals(port)
    }

    private func observeSignals(_ port: ORSSerialPort) {
        let continuation = self.continuation
        let handler: @Sendable (ORSSerialPort, NSKeyValueObservedChange<Bool>) -> Void = { port, _ in
            continuation.yield(.signals(cts: port.cts, dsr: port.dsr, dcd: port.dcd, ri: false))
        }
        signalObservations = [
            port.observe(\.cts, changeHandler: handler),
            port.observe(\.dsr, changeHandler: handler),
            port.observe(\.dcd, changeHandler: handler),
        ]
    }

    public func write(_ data: Data) async throws {
        guard let port, port.isOpen else {
            throw SerialTransportError.notOpen
        }
        port.send(data)
    }

    public func setSignals(_ signals: ModemSignals) async throws {
        guard let port, port.isOpen else {
            throw SerialTransportError.notOpen
        }
        port.dtr = signals.dtr
        port.rts = signals.rts
    }

    public func close() async {
        port?.close()
    }
}

public enum SerialTransportError: Error {
    case noPortSelected
    case notOpen
}

extension ORSSerialTransport: ORSSerialPortDelegate {
    public func serialPortWasOpened(_ serialPort: ORSSerialPort) {
        continuation.yield(.opened)
    }

    public func serialPortWasClosed(_ serialPort: ORSSerialPort) {
        continuation.yield(.closed)
    }

    public func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
        port = nil
        continuation.yield(.closed)
    }

    public func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
        continuation.yield(.data(data))
    }

    public func serialPort(_ serialPort: ORSSerialPort, didEncounterError error: Error) {
        continuation.yield(.error(error.localizedDescription))
    }
}

private extension SerialConfiguration.Parity {
    var orsParity: ORSSerialPortParity {
        switch self {
        case .none: return .none
        case .even: return .even
        case .odd: return .odd
        }
    }
}
