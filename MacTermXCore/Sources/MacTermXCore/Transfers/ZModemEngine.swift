import Foundation

/// ZMODEM single-file send/receive, built on `ZModemFraming`.
///
/// Scope note (see `ZModemFraming`'s doc comment): this is a stop-and-wait
/// subset — every data subpacket is sent as `.ackRequested` and awaited
/// before the next one goes out — not the real protocol's streaming
/// windowed transfer, and it has no crash-resume (ZRPOS always starts a
/// fresh transfer at offset 0) or auto-start (no "rz"-triggered detection
/// from plain terminal output). Real streaming, resume, and
/// interoperability with `lrzsz` or other ZMODEM implementations are
/// unverified and remain explicitly pending, per the project's own
/// research doc — this covers reliable single-file transfer over a
/// lossy-but-eventually-delivering link, which is what MacTermX needs for
/// legacy device consoles.
public enum ZModemEngine {
    public struct Options: Sendable {
        public var subpacketSize: Int
        public var maxRetries: Int
        public var headerTimeout: Duration

        public init(subpacketSize: Int = 1024, maxRetries: Int = 10, headerTimeout: Duration = .seconds(10)) {
            self.subpacketSize = subpacketSize
            self.maxRetries = maxRetries
            self.headerTimeout = headerTimeout
        }
    }

    public static func send(
        name: String,
        data: Data,
        options: Options = Options(),
        channel: TransferByteChannel,
        write: @escaping @Sendable ([UInt8]) async throws -> Void
    ) async throws {
        try await negotiate(role: .sender, options: options, channel: channel, write: write)

        var fileHeaderPayload = Array(name.utf8)
        fileHeaderPayload.append(0)
        fileHeaderPayload += Array("\(data.count)".utf8)
        try await sendFrameWithRetries(
            header: ZModemFraming.makeHeader(type: .zfile),
            subpacket: ZModemFraming.makeDataSubpacket(fileHeaderPayload, end: .frameEnd),
            expecting: [.zrpos],
            options: options,
            channel: channel,
            write: write
        )

        try await write(ZModemFraming.makeHeader(type: .zdata, argument: 0))
        if data.isEmpty {
            // Even a zero-length file needs one subpacket, so the
            // receiver's "read subpackets until frameEnd" loop has
            // something to end on.
            try await sendSubpacketWithRetries([], end: .frameEnd, options: options, channel: channel, write: write)
        } else {
            var offset = data.startIndex
            while offset < data.endIndex {
                let end = data.index(offset, offsetBy: options.subpacketSize, limitedBy: data.endIndex) ?? data.endIndex
                let chunk = Array(data[offset..<end])
                let isLast = end == data.endIndex
                try await sendSubpacketWithRetries(
                    chunk,
                    end: isLast ? .frameEnd : .ackRequested,
                    options: options,
                    channel: channel,
                    write: write
                )
                offset = end
            }
        }

        try await sendFrameWithRetries(
            header: ZModemFraming.makeHeader(type: .zeof, argument: UInt32(data.count)),
            subpacket: nil,
            expecting: [.zrinit],
            options: options,
            channel: channel,
            write: write
        )

        try await write(ZModemFraming.makeHeader(type: .zfin))
        _ = try await readHeader(options: options, channel: channel)
        try await write(Array("OO".utf8))
    }

    public static func receive(
        options: Options = Options(),
        channel: TransferByteChannel,
        write: @escaping @Sendable ([UInt8]) async throws -> Void
    ) async throws -> (name: String, data: Data) {
        try await negotiate(role: .receiver, options: options, channel: channel, write: write)

        let fileHeader = try await readSubpacketAfterHeader(expecting: .zfile, options: options, channel: channel)
        guard let nullIndex = fileHeader.firstIndex(of: 0) else { throw TransferError.peerCancelled }
        let name = YModemEngine.sanitizeFilename(String(decoding: fileHeader[..<nullIndex], as: UTF8.self))

        try await write(ZModemFraming.makeHeader(type: .zrpos, argument: 0))

        var result = Data()
        while true {
            let (type, _) = try await readHeader(options: options, channel: channel)
            guard type == .zdata else {
                if type == .zeof {
                    try await write(ZModemFraming.makeHeader(type: .zrinit))
                    break
                }
                continue
            }
            while true {
                let (payload, end) = try await readDataSubpacket(options: options, channel: channel)
                result.append(contentsOf: payload)
                if end == .ackRequested {
                    try await write(ZModemFraming.makeHeader(type: .zack, argument: UInt32(result.count)))
                }
                if end == .frameEnd { break }
            }
        }

        let (finType, _) = try await readHeader(options: options, channel: channel)
        guard finType == .zfin else { throw TransferError.peerCancelled }
        try await write(ZModemFraming.makeHeader(type: .zfin))

        return (name, result)
    }

    // MARK: - Shared handshake

    private enum Role { case sender, receiver }

    private static func negotiate(
        role: Role,
        options: Options,
        channel: TransferByteChannel,
        write: @escaping @Sendable ([UInt8]) async throws -> Void
    ) async throws {
        switch role {
        case .sender:
            try await sendFrameWithRetries(
                header: ZModemFraming.makeHeader(type: .zrqinit),
                subpacket: nil,
                expecting: [.zrinit],
                options: options,
                channel: channel,
                write: write
            )
        case .receiver:
            try await write(ZModemFraming.makeHeader(type: .zrinit))
            _ = try await readHeader(options: options, channel: channel) // ZRQINIT or ZFILE header start
        }
    }

    // MARK: - Frame I/O with retries

    private static func sendFrameWithRetries(
        header: [UInt8],
        subpacket: [UInt8]?,
        expecting: Set<ZModemFraming.FrameType>,
        options: Options,
        channel: TransferByteChannel,
        write: @escaping @Sendable ([UInt8]) async throws -> Void
    ) async throws {
        var attempt = 0
        while true {
            try await write(header)
            if let subpacket { try await write(subpacket) }
            do {
                let (type, _) = try await readHeader(options: options, channel: channel)
                if expecting.contains(type) { return }
            } catch {
                // fall through to retry
            }
            attempt += 1
            if attempt >= options.maxRetries { throw TransferError.tooManyRetries }
        }
    }

    private static func sendSubpacketWithRetries(
        _ payload: [UInt8],
        end: ZModemFraming.SubpacketEnd,
        options: Options,
        channel: TransferByteChannel,
        write: @escaping @Sendable ([UInt8]) async throws -> Void
    ) async throws {
        let frame = ZModemFraming.makeDataSubpacket(payload, end: end)
        var attempt = 0
        while true {
            try await write(frame)
            if end == .frameEnd { return }
            do {
                let (type, _) = try await readHeader(options: options, channel: channel)
                if type == .zack { return }
            } catch {
                // retry
            }
            attempt += 1
            if attempt >= options.maxRetries { throw TransferError.tooManyRetries }
        }
    }

    // MARK: - Raw frame reading (unescapes as it goes)

    private static func readUnescapedBytes(count: Int, options: Options, channel: TransferByteChannel) async throws -> [UInt8] {
        var result: [UInt8] = []
        while result.count < count {
            let byte = try await channel.readByte(timeout: options.headerTimeout)
            if byte == ZModemFraming.Control.zdle {
                let next = try await channel.readByte(timeout: options.headerTimeout)
                result.append(next ^ 0x40)
            } else {
                result.append(byte)
            }
        }
        return result
    }

    /// Scans for the ZPAD ZPAD ZDLE ZBIN32 sync sequence, then reads and
    /// validates the 9-byte header body.
    private static func readHeader(options: Options, channel: TransferByteChannel) async throws -> (ZModemFraming.FrameType, UInt32) {
        while true {
            guard try await channel.readByte(timeout: options.headerTimeout) == ZModemFraming.Control.zpad else { continue }
            guard try await channel.readByte(timeout: options.headerTimeout) == ZModemFraming.Control.zpad else { continue }
            guard try await channel.readByte(timeout: options.headerTimeout) == ZModemFraming.Control.zdle else { continue }
            guard try await channel.readByte(timeout: options.headerTimeout) == ZModemFraming.Control.zbin32 else { continue }
            let body = try await readUnescapedBytes(count: 9, options: options, channel: channel)
            guard let parsed = validateUnescapedHeaderBody(body) else { continue }
            return parsed
        }
    }

    private static func validateUnescapedHeaderBody(_ body: [UInt8]) -> (ZModemFraming.FrameType, UInt32)? {
        guard body.count == 9 else { return nil }
        let unescapedBody = Array(body[0..<5])
        let crc = ZModemFraming.crc32(unescapedBody)
        guard crc == UInt32(body[5]) | (UInt32(body[6]) << 8) | (UInt32(body[7]) << 16) | (UInt32(body[8]) << 24) else { return nil }
        guard let type = ZModemFraming.FrameType(rawValue: body[0]) else { return nil }
        let argument = UInt32(body[1]) | (UInt32(body[2]) << 8) | (UInt32(body[3]) << 16) | (UInt32(body[4]) << 24)
        return (type, argument)
    }

    private static func readDataSubpacket(options: Options, channel: TransferByteChannel) async throws -> ([UInt8], ZModemFraming.SubpacketEnd) {
        var payload: [UInt8] = []
        while true {
            let byte = try await channel.readByte(timeout: options.headerTimeout)
            guard byte == ZModemFraming.Control.zdle else {
                payload.append(byte)
                continue
            }
            let next = try await channel.readByte(timeout: options.headerTimeout)
            guard let end = ZModemFraming.SubpacketEnd(rawValue: next) else {
                payload.append(next ^ 0x40)
                continue
            }
            let crcBytes = try await readUnescapedBytes(count: 4, options: options, channel: channel)
            let expectedCRC = ZModemFraming.crc32(payload + [end.rawValue])
            let actualCRC = UInt32(crcBytes[0]) | (UInt32(crcBytes[1]) << 8) | (UInt32(crcBytes[2]) << 16) | (UInt32(crcBytes[3]) << 24)
            guard expectedCRC == actualCRC else { throw TransferError.tooManyRetries }
            return (payload, end)
        }
    }

    private static func readSubpacketAfterHeader(expecting: ZModemFraming.FrameType, options: Options, channel: TransferByteChannel) async throws -> [UInt8] {
        while true {
            let (type, _) = try await readHeader(options: options, channel: channel)
            if type == expecting {
                let (payload, _) = try await readDataSubpacket(options: options, channel: channel)
                return payload
            }
        }
    }
}
