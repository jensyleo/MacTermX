import Foundation

/// A saved connection profile. Deliberately carries no secrets — device
/// matching is by USB identity only, never by credential.
public struct SerialProfile: Sendable, Equatable, Codable, Identifiable {
    public static let currentSchemaVersion = 1

    public struct DeviceMatch: Sendable, Equatable, Codable {
        public var vendorId: String?
        public var productId: String?
        public var serialNumber: String?

        public init(vendorId: String? = nil, productId: String? = nil, serialNumber: String? = nil) {
            self.vendorId = vendorId
            self.productId = productId
            self.serialNumber = serialNumber
        }
    }

    public enum Environment: String, Sendable, Codable {
        case lab
        case production
    }

    public var schemaVersion: Int
    public var id: UUID
    public var name: String
    public var environment: Environment
    public var deviceMatch: DeviceMatch
    public var serial: SerialConfiguration
    public var groupTags: [String]

    public init(
        id: UUID = UUID(),
        name: String,
        environment: Environment = .lab,
        deviceMatch: DeviceMatch = DeviceMatch(),
        serial: SerialConfiguration = SerialConfiguration(),
        groupTags: [String] = []
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.id = id
        self.name = name
        self.environment = environment
        self.deviceMatch = deviceMatch
        self.serial = serial
        self.groupTags = groupTags
    }
}

public enum SerialProfileError: Error, Equatable {
    case unsupportedSchemaVersion(Int)
}
