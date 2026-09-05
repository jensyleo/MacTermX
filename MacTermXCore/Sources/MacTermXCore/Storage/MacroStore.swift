import Foundation

/// Reads and writes a saved macro library as one JSON array file per key —
/// mirrors `ProfileStore`'s one-file-per-item approach. Keyed by a plain
/// string (the device path, in practice) rather than a profile ID, so
/// quick commands work even for a port that was never saved as a profile.
public struct MacroStore: Sendable {
    private let directory: URL
    private let decoder = JSONDecoder()
    private let encoder: JSONEncoder

    public init(directory: URL) {
        self.directory = directory
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    private func fileURL(for key: String) -> URL {
        let sanitized = key.replacingOccurrences(of: "/", with: "_")
        return directory.appendingPathComponent(sanitized).appendingPathExtension("json")
    }

    public func load(for key: String) -> [MacroCommand] {
        let url = fileURL(for: key)
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? decoder.decode([MacroCommand].self, from: data)) ?? []
    }

    public func save(_ macros: [MacroCommand], for key: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(macros)
        try data.write(to: fileURL(for: key), options: .atomic)
    }
}
