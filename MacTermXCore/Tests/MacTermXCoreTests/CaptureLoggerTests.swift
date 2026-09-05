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
}
