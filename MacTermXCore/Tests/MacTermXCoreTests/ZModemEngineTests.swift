import Foundation
import Testing
@testable import MacTermXCore

@Suite("ZModemEngine")
struct ZModemEngineTests {
    private func makeLoopback() -> (senderChannel: TransferByteChannel, senderWrite: @Sendable ([UInt8]) async throws -> Void,
                                     receiverChannel: TransferByteChannel, receiverWrite: @Sendable ([UInt8]) async throws -> Void) {
        let senderChannel = TransferByteChannel()
        let receiverChannel = TransferByteChannel()
        let senderWrite: @Sendable ([UInt8]) async throws -> Void = { bytes in receiverChannel.push(Data(bytes)) }
        let receiverWrite: @Sendable ([UInt8]) async throws -> Void = { bytes in senderChannel.push(Data(bytes)) }
        return (senderChannel, senderWrite, receiverChannel, receiverWrite)
    }

    @Test("transfers a multi-subpacket file intact, with its name")
    func transfersFile() async throws {
        let (senderChannel, senderWrite, receiverChannel, receiverWrite) = makeLoopback()
        let payload = Data((0..<3000).map { UInt8($0 % 256) }) // spans 3 subpackets of 1024

        async let sent: Void = ZModemEngine.send(name: "firmware.bin", data: payload, channel: senderChannel, write: senderWrite)
        async let received = ZModemEngine.receive(channel: receiverChannel, write: receiverWrite)

        _ = try await sent
        let result = try await received

        #expect(result.name == "firmware.bin")
        #expect(result.data == payload)
    }

    @Test("transfers a zero-length file")
    func transfersEmptyFile() async throws {
        let (senderChannel, senderWrite, receiverChannel, receiverWrite) = makeLoopback()

        async let sent: Void = ZModemEngine.send(name: "empty.txt", data: Data(), channel: senderChannel, write: senderWrite)
        async let received = ZModemEngine.receive(channel: receiverChannel, write: receiverWrite)

        _ = try await sent
        let result = try await received

        #expect(result.name == "empty.txt")
        #expect(result.data.isEmpty)
    }

    @Test("transfers a payload smaller than one subpacket")
    func transfersShortFile() async throws {
        let (senderChannel, senderWrite, receiverChannel, receiverWrite) = makeLoopback()
        let payload = Data("hello zmodem".utf8)

        async let sent: Void = ZModemEngine.send(name: "short.txt", data: payload, channel: senderChannel, write: senderWrite)
        async let received = ZModemEngine.receive(channel: receiverChannel, write: receiverWrite)

        _ = try await sent
        let result = try await received

        #expect(result.data == payload)
    }
}
