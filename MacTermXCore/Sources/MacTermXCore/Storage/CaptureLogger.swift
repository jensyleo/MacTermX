import CryptoKit
import Foundation

public enum CaptureFormat: String, Sendable, CaseIterable, Codable {
    /// Raw bytes, appended as-is — what a human opens in a text editor.
    case plainText
    /// One JSON object per chunk: timestamp, direction, and the bytes as
    /// base64 — RF-005's "log estructurado JSONL", timestamped and
    /// machine-parseable, at the cost of not being directly readable.
    case jsonl
    /// Raw bytes, no framing at all — for a capture meant to be replayed
    /// bit-for-bit rather than read.
    case binaryRaw = "binary"
}

/// Records received serial data to a file while capture is active —
/// CoolTerm's "recording received data to text files", extended per
/// RF-005: a chosen format (plain/JSONL/binary) and a SHA-256 hash
/// written alongside the file when capture stops, so the capture can
/// later be verified as unmodified.
public final class CaptureLogger {
    private var handle: FileHandle?
    private var hasher = SHA256()
    public private(set) var destination: URL?
    public private(set) var format: CaptureFormat = .plainText
    public private(set) var lastHash: String?

    public init() {}

    public func start(to url: URL, format: CaptureFormat = .plainText) throws {
        stop()
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        handle = try FileHandle(forWritingTo: url)
        destination = url
        self.format = format
        hasher = SHA256()
        lastHash = nil
    }

    /// Appends one chunk of received data, framed per the active format.
    public func append(_ data: Data, timestamp: Date = Date()) {
        guard let handle else { return }
        let framed: Data
        switch format {
        case .plainText, .binaryRaw:
            framed = data
        case .jsonl:
            let record: [String: Any] = [
                "timestamp": ISO8601DateFormatter().string(from: timestamp),
                "direction": "rx",
                "dataBase64": data.base64EncodedString(),
            ]
            guard let json = try? JSONSerialization.data(withJSONObject: record) else { return }
            framed = json + Data("\n".utf8)
        }
        try? handle.write(contentsOf: framed)
        hasher.update(data: framed)
    }

    /// Stops the capture, writes a `<file>.sha256` sidecar with the hash
    /// of everything written this session, and returns that hash (also
    /// available afterward via `lastHash`).
    @discardableResult
    public func stop() -> String? {
        guard let handle, let destination else { return nil }
        try? handle.close()
        let digest = hasher.finalize()
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        let sidecar = destination.appendingPathExtension("sha256")
        try? "\(hex)  \(destination.lastPathComponent)\n".write(to: sidecar, atomically: true, encoding: .utf8)
        lastHash = hex
        self.handle = nil
        self.destination = nil
        return hex
    }

    public var isActive: Bool { handle != nil }
}
