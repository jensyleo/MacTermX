import Foundation

public struct SerialConfiguration: Sendable, Equatable, Hashable, Codable {
    public enum Parity: String, Sendable, Codable { case none, even, odd }
    public enum FlowControl: String, Sendable, Codable { case none, rtsCts, xonXoff }

    public var baudRate: Int
    public var dataBits: Int
    public var stopBits: Int
    public var parity: Parity
    public var flowControl: FlowControl

    public init(
        baudRate: Int = 115_200,
        dataBits: Int = 8,
        stopBits: Int = 1,
        parity: Parity = .none,
        flowControl: FlowControl = .none
    ) {
        self.baudRate = baudRate
        self.dataBits = dataBits
        self.stopBits = stopBits
        self.parity = parity
        self.flowControl = flowControl
    }
}

public struct ModemSignals: Sendable, Equatable {
    public var dtr: Bool
    public var rts: Bool

    public init(dtr: Bool = false, rts: Bool = false) {
        self.dtr = dtr
        self.rts = rts
    }
}

public struct SerialDevice: Sendable, Equatable, Hashable, Identifiable {
    public var id: String { path }
    public var path: String
    public var name: String
    public var vendorId: String?
    public var productId: String?
    public var serialNumber: String?

    public init(path: String, name: String, vendorId: String? = nil, productId: String? = nil, serialNumber: String? = nil) {
        self.path = path
        self.name = name
        self.vendorId = vendorId
        self.productId = productId
        self.serialNumber = serialNumber
    }
}

public enum PortChange: Sendable, Equatable {
    case connected(SerialDevice)
    case disconnected(SerialDevice)
}

public enum SerialEvent: Sendable {
    case data(Data)
    case signals(cts: Bool, dsr: Bool, dcd: Bool, ri: Bool)
    case opened
    case closed
    case error(String)
}
