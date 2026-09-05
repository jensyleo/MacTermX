import Foundation

/// Records received serial data to a file while capture is active —
/// CoolTerm's "recording received data to text files". Deliberately
/// minimal: plain appended bytes, no rotation, no structured format (see
/// the project's own research doc for the fuller JSONL/hash-on-close
/// design planned for a later phase).
public final class CaptureLogger {
    private var handle: FileHandle?
    public private(set) var destination: URL?

    public init() {}

    public func start(to url: URL) throws {
        stop()
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        handle = try FileHandle(forWritingTo: url)
        destination = url
    }

    public func append(_ data: Data) {
        guard let handle else { return }
        try? handle.write(contentsOf: data)
    }

    public func stop() {
        try? handle?.close()
        handle = nil
        destination = nil
    }

    public var isActive: Bool { handle != nil }
}
