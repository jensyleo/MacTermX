import Foundation
import Testing
@testable import MacTermXCore

@Suite("XModemEngine")
struct XModemEngineTests {
    /// Connects a sender and a receiver so each side's `write` pushes
    /// straight into the other side's channel — a synthetic serial
    /// loopback, standing in for the two ends of a real cable.
    private func makeLoopback() -> (senderChannel: TransferByteChannel, senderWrite: @Sendable ([UInt8]) async throws -> Void,
                                     receiverChannel: TransferByteChannel, receiverWrite: @Sendable ([UInt8]) async throws -> Void) {
        let senderChannel = TransferByteChannel()
        let receiverChannel = TransferByteChannel()
        let senderWrite: @Sendable ([UInt8]) async throws -> Void = { bytes in receiverChannel.push(Data(bytes)) }
        let receiverWrite: @Sendable ([UInt8]) async throws -> Void = { bytes in senderChannel.push(Data(bytes)) }
        return (senderChannel, senderWrite, receiverChannel, receiverWrite)
    }

    @Test("transfers a multi-block payload intact, CRC mode")
    func transfersPayloadCRC() async throws {
        let (senderChannel, senderWrite, receiverChannel, receiverWrite) = makeLoopback()
        let payload = Data((0..<300).map { UInt8($0 % 256) }) // spans 3 blocks of 128

        async let sent: Void = XModemEngine.send(payload, channel: senderChannel, write: senderWrite)
        async let received = XModemEngine.receive(channel: receiverChannel, write: receiverWrite)

        _ = try await sent
        let result = try await received

        #expect(result.prefix(payload.count) == payload)
    }

    @Test("transfers a payload intact, checksum mode")
    func transfersPayloadChecksum() async throws {
        let (senderChannel, senderWrite, receiverChannel, receiverWrite) = makeLoopback()
        let payload = Data("plain checksum mode transfer".utf8)

        async let sent: Void = XModemEngine.send(payload, options: .init(useCRC: false), channel: senderChannel, write: senderWrite)
        async let received = XModemEngine.receive(options: .init(useCRC: false), channel: receiverChannel, write: receiverWrite)

        _ = try await sent
        let result = try await received

        #expect(result.prefix(payload.count) == payload)
    }

    @Test("a single-block payload shorter than 128 bytes round-trips")
    func shortPayload() async throws {
        let (senderChannel, senderWrite, receiverChannel, receiverWrite) = makeLoopback()
        let payload = Data("short".utf8)

        async let sent: Void = XModemEngine.send(payload, channel: senderChannel, write: senderWrite)
        async let received = XModemEngine.receive(channel: receiverChannel, write: receiverWrite)

        _ = try await sent
        let result = try await received

        #expect(result.prefix(payload.count) == payload)
    }
}
