import Foundation
import Testing
@testable import MacTermXCore

@Suite("YModemEngine")
struct YModemEngineTests {
    private func makeLoopback() -> (senderChannel: TransferByteChannel, senderWrite: @Sendable ([UInt8]) async throws -> Void,
                                     receiverChannel: TransferByteChannel, receiverWrite: @Sendable ([UInt8]) async throws -> Void) {
        let senderChannel = TransferByteChannel()
        let receiverChannel = TransferByteChannel()
        let senderWrite: @Sendable ([UInt8]) async throws -> Void = { bytes in receiverChannel.push(Data(bytes)) }
        let receiverWrite: @Sendable ([UInt8]) async throws -> Void = { bytes in senderChannel.push(Data(bytes)) }
        return (senderChannel, senderWrite, receiverChannel, receiverWrite)
    }

    @Test("transfers a single-file batch with its name and content intact")
    func singleFileBatch() async throws {
        let (senderChannel, senderWrite, receiverChannel, receiverWrite) = makeLoopback()
        let file = YModemEngine.FilePayload(name: "boot.cfg", data: Data("baud=9600\n".utf8))

        async let sent: Void = YModemEngine.send([file], channel: senderChannel, write: senderWrite)
        async let received = YModemEngine.receive(channel: receiverChannel, write: receiverWrite)

        _ = try await sent
        let files = try await received

        #expect(files.count == 1)
        #expect(files.first?.name == "boot.cfg")
        #expect(files.first?.data == file.data)
    }

    @Test("transfers a multi-file batch in order")
    func multiFileBatch() async throws {
        let (senderChannel, senderWrite, receiverChannel, receiverWrite) = makeLoopback()
        let files = [
            YModemEngine.FilePayload(name: "a.txt", data: Data("first file".utf8)),
            YModemEngine.FilePayload(name: "b.txt", data: Data(repeating: 0x42, count: 1500)),
        ]

        async let sent: Void = YModemEngine.send(files, channel: senderChannel, write: senderWrite)
        async let received = YModemEngine.receive(channel: receiverChannel, write: receiverWrite)

        _ = try await sent
        let result = try await received

        #expect(result.map(\.name) == ["a.txt", "b.txt"])
        #expect(result.map(\.data) == files.map(\.data))
    }

    @Test("strips path traversal and directory components from filenames")
    func sanitizesFilenames() {
        #expect(YModemEngine.sanitizeFilename("../../etc/passwd") == "passwd")
        #expect(YModemEngine.sanitizeFilename("sub/dir/file.bin") == "file.bin")
        #expect(YModemEngine.sanitizeFilename("plain.txt") == "plain.txt")
        #expect(YModemEngine.sanitizeFilename("..") == "unnamed")
    }
}
