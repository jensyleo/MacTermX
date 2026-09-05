import Foundation

/// XMODEM sender and receiver (checksum and CRC-16 variants), built purely
/// on `XModemFraming` plus an injected write function and read channel —
/// no dependency on `SerialTransport` or the UI, so it can be driven by a
/// loopback in tests and by the real transport in production alike.
public enum XModemEngine {
    public static let maxRetries = 10
    public static let blockTimeout: Duration = .seconds(5)
    public static let startTimeout: Duration = .seconds(60)

    public struct Options: Sendable {
        public var useCRC: Bool
        public var use1K: Bool
        public var maxRetries: Int
        public var blockTimeout: Duration

        public init(
            useCRC: Bool = true,
            use1K: Bool = false,
            maxRetries: Int = XModemEngine.maxRetries,
            blockTimeout: Duration = XModemEngine.blockTimeout
        ) {
            self.useCRC = useCRC
            self.use1K = use1K
            self.maxRetries = maxRetries
            self.blockTimeout = blockTimeout
        }
    }

    /// Sends `payload` block by block. Waits for the receiver's initial
    /// 'C' (CRC mode) or NAK (checksum mode) before the first block, and
    /// for EOT to be acknowledged before returning.
    public static func send(
        _ payload: Data,
        options: Options = Options(),
        channel: TransferByteChannel,
        write: @escaping @Sendable ([UInt8]) async throws -> Void
    ) async throws {
        let useCRC = try await waitForStart(channel: channel, timeout: options.blockTimeout)
        let size = options.use1K ? XModemFraming.blockSize1K : XModemFraming.blockSize
        var blockNumber: UInt8 = 1
        var offset = payload.startIndex

        while offset < payload.endIndex {
            let end = payload.index(offset, offsetBy: size, limitedBy: payload.endIndex) ?? payload.endIndex
            let block = XModemFraming.makeBlock(number: blockNumber, payload: Array(payload[offset..<end]), useCRC: useCRC, size: size)
            try await sendBlockWithRetries(block, options: options, channel: channel, write: write)
            blockNumber = blockNumber &+ 1
            offset = end
        }

        try await write([XModemFraming.Control.eot])
        let ack = try await channel.readByte(timeout: options.blockTimeout)
        guard ack == XModemFraming.Control.ack else { throw TransferError.peerCancelled }
    }

    /// Receives a payload of unknown length, terminated by EOT. Requests
    /// CRC mode by sending 'C' first; if the sender doesn't answer with a
    /// valid CRC block, falls back to plain NAK (checksum mode). Strips
    /// trailing padding bytes from the last block on return.
    public static func receive(
        options: Options = Options(),
        channel: TransferByteChannel,
        write: @escaping @Sendable ([UInt8]) async throws -> Void
    ) async throws -> Data {
        var useCRC = options.useCRC
        var expectedNumber: UInt8 = 1
        var result = Data()

        try await write([useCRC ? XModemFraming.Control.crcMode : XModemFraming.Control.nak])

        while true {
            let header: UInt8
            do {
                header = try await channel.readByte(timeout: options.blockTimeout)
            } catch {
                // No response to our start byte yet — if we asked for CRC,
                // fall back to checksum mode and try again, per the classic
                // XMODEM negotiation.
                if useCRC {
                    useCRC = false
                    try await write([XModemFraming.Control.nak])
                    continue
                }
                throw error
            }

            if header == XModemFraming.Control.eot {
                try await write([XModemFraming.Control.ack])
                return result
            }
            if header == XModemFraming.Control.can {
                throw TransferError.peerCancelled
            }
            guard let size = XModemFraming.blockSize(forHeader: header) else { continue }

            let trailerSize = useCRC ? 2 : 1
            var frame: [UInt8] = [header]
            for _ in 0..<(2 + size + trailerSize) {
                frame.append(try await channel.readByte(timeout: options.blockTimeout))
            }

            if let payload = XModemFraming.validateBlock(frame, expectedNumber: expectedNumber, useCRC: useCRC) {
                result.append(contentsOf: payload)
                expectedNumber = expectedNumber &+ 1
                try await write([XModemFraming.Control.ack])
            } else if let payload = XModemFraming.validateBlock(frame, expectedNumber: expectedNumber &- 1, useCRC: useCRC) {
                // Duplicate of the last accepted block (our ACK was lost) —
                // ACK it again without re-appending, don't treat as corrupt.
                _ = payload
                try await write([XModemFraming.Control.ack])
            } else {
                try await write([XModemFraming.Control.nak])
            }
        }
    }

    private static func waitForStart(channel: TransferByteChannel, timeout: Duration) async throws -> Bool {
        // The sender stays idle until the receiver announces which mode it
        // wants: 'C' for CRC, NAK for the original checksum mode.
        let byte = try await channel.readByte(timeout: timeout)
        return byte == XModemFraming.Control.crcMode
    }

    private static func sendBlockWithRetries(
        _ block: [UInt8],
        options: Options,
        channel: TransferByteChannel,
        write: @escaping @Sendable ([UInt8]) async throws -> Void
    ) async throws {
        var attempt = 0
        while true {
            try await write(block)
            let response = try await channel.readByte(timeout: options.blockTimeout)
            if response == XModemFraming.Control.ack { return }
            if response == XModemFraming.Control.can { throw TransferError.peerCancelled }
            attempt += 1
            if attempt >= options.maxRetries { throw TransferError.tooManyRetries }
        }
    }
}
