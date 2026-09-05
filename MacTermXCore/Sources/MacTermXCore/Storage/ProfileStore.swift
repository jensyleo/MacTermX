import Foundation

/// Reads and writes `SerialProfile` JSON files in a directory. One file per
/// profile, named by its `id`, so import/export is just copying a file.
public struct ProfileStore: Sendable {
    private let directory: URL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(directory: URL) {
        self.directory = directory
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    private func fileURL(for id: UUID) -> URL {
        directory.appendingPathComponent(id.uuidString).appendingPathExtension("json")
    }

    public func loadAll() throws -> [SerialProfile] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        return try files.map { try load(from: $0) }
    }

    public func load(from url: URL) throws -> SerialProfile {
        let data = try Data(contentsOf: url)
        return try decode(data)
    }

    public func decode(_ data: Data) throws -> SerialProfile {
        let profile = try decoder.decode(SerialProfile.self, from: data)
        guard profile.schemaVersion <= SerialProfile.currentSchemaVersion else {
            throw SerialProfileError.unsupportedSchemaVersion(profile.schemaVersion)
        }
        return profile
    }

    public func save(_ profile: SerialProfile) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(profile)
        try data.write(to: fileURL(for: profile.id), options: .atomic)
    }

    public func delete(_ profile: SerialProfile) throws {
        try FileManager.default.removeItem(at: fileURL(for: profile.id))
    }

    public func export(_ profile: SerialProfile, to url: URL) throws {
        let data = try encoder.encode(profile)
        try data.write(to: url, options: .atomic)
    }
}
