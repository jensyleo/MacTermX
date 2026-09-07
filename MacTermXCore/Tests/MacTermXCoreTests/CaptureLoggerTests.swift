import Foundation
import Testing
@testable import MacTermXCore

@Suite("CaptureLogger")
struct CaptureLoggerTests {
    @Test("appends data to the started file")
    func appendsData() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".txt")
        defer { try? FileManager.default.removeItem(at: url) }

        let logger = CaptureLogger()
        try logger.start(to: url)
        logger.append(Data("hello ".utf8))
        logger.append(Data("world".utf8))
        logger.stop()

        #expect(try Data(contentsOf: url) == Data("hello world".utf8))
    }

    @Test("isActive reflects start/stop")
    func isActiveState() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".txt")
        defer { try? FileManager.default.removeItem(at: url) }

        let logger = CaptureLogger()
        #expect(!logger.isActive)
        try logger.start(to: url)
        #expect(logger.isActive)
        logger.stop()
        #expect(!logger.isActive)
    }

    @Test("JSONL format frames each chunk as one timestamped JSON object per line")
    func jsonlFormat() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jsonl")
        defer { try? FileManager.default.removeItem(at: url) }

        let logger = CaptureLogger()
        try logger.start(to: url, format: .jsonl)
        logger.append(Data("hello".utf8))
        logger.append(Data("world".utf8))
        logger.stop()

        let lines = try String(contentsOf: url, encoding: .utf8).split(separator: "\n")
        #expect(lines.count == 2)
        for line in lines {
            let json = try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any]
            #expect(json?["direction"] as? String == "rx")
            #expect(json?["dataBase64"] != nil)
            #expect(json?["timestamp"] != nil)
        }
    }

    @Test("stop() writes a .sha256 sidecar matching the file's actual hash")
    func sha256Sidecar() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".txt")
        let sidecar = url.appendingPathExtension("sha256")
        defer {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: sidecar)
        }

        let logger = CaptureLogger()
        try logger.start(to: url)
        logger.append(Data("hello world".utf8))
        let hash = logger.stop()

        #expect(hash != nil)
        let sidecarContent = try String(contentsOf: sidecar, encoding: .utf8)
        #expect(sidecarContent.contains(hash!))

        // SHA-256("hello world")
        #expect(hash == "b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9")
    }
}
