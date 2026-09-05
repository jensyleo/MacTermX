import Foundation

/// Pure ZMODEM framing: byte escaping, CRC-32, and header/data-subpacket
/// encode/decode. No I/O, no timing — mirrors `XModemFraming`'s role for
/// the XMODEM/YMODEM engines.
///
/// Scope note: this implements the CRC-32 binary header form (ZBIN32) and
/// stop-and-wait data subpackets (each ending in ZCRCW, acknowledged
/// before the next), not the full streaming/windowed/resume protocol or
/// the ZHEX terminal-safe header form. That mirrors the doc's own plan
/// (`ZMODEM con reanudación y autoarranque, solo después de pruebas de
/// interoperabilidad`) — this is the piece that can be built and unit
/// tested against a synthetic loopback now; real-device interoperability
/// (e.g. against `lrzsz`) is unverified and stays a pending, explicit gap.
public enum ZModemFraming {
    public enum Control {
        public static let zpad: UInt8 = 0x2A // '*'
        public static let zdle: UInt8 = 0x18 // CAN, also the escape marker
        public static let zdlee: UInt8 = 0x58 // 'X', ZDLE XORed with 0x40
        public static let zbin32: UInt8 = 0x43 // 'C', binary header with CRC-32
    }

    public enum FrameType: UInt8 {
        case zrqinit = 0
        case zrinit = 1
        case zack = 3
        case zfile = 4
        case znak = 6
        case zabort = 7
        case zfin = 8
        case zrpos = 9
        case zdata = 10
        case zeof = 11
        case zcan = 16
    }

    /// How a data subpacket ends: whether more subpackets follow, and
    /// whether the sender wants an explicit ACK before continuing.
    public enum SubpacketEnd: UInt8 {
        case frameEnd = 0x68 // ZCRCE: end of frame, no ACK expected
        case ackRequested = 0x6B // ZCRCW: end of subpacket, ACK required
    }

    /// Standard reflected CRC-32 (poly 0xEDB88320), as used by ZMODEM.
    public static func crc32(_ bytes: [UInt8]) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in bytes {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc & 1 != 0) ? (crc >> 1) ^ 0xEDB8_8320 : crc >> 1
            }
        }
        return ~crc
    }

    /// Escapes ZDLE itself, CR (to survive naive line-ending translation),
    /// and control bytes in 0x00–0x1F / 0x80–0x9F, by ZDLE-prefixing the
    /// byte XORed with 0x40.
    public static func escape(_ bytes: [UInt8]) -> [UInt8] {
        var result: [UInt8] = []
        result.reserveCapacity(bytes.count)
        for byte in bytes {
            if needsEscaping(byte) {
                result.append(Control.zdle)
                result.append(byte ^ 0x40)
            } else {
                result.append(byte)
            }
        }
        return result
    }

    private static func needsEscaping(_ byte: UInt8) -> Bool {
        byte == Control.zdle || byte == 0x0D || (byte & 0x60) == 0
    }

    /// Reverses `escape(_:)`. Returns `nil` if the bytes end mid-escape
    /// (a ZDLE with no following byte) — treated as corrupt/truncated.
    public static func unescape(_ bytes: [UInt8]) -> [UInt8]? {
        var result: [UInt8] = []
        result.reserveCapacity(bytes.count)
        var index = bytes.startIndex
        while index < bytes.endIndex {
            let byte = bytes[index]
            if byte == Control.zdle {
                let nextIndex = bytes.index(after: index)
                guard nextIndex < bytes.endIndex else { return nil }
                result.append(bytes[nextIndex] ^ 0x40)
                index = bytes.index(after: nextIndex)
            } else {
                result.append(byte)
                index = bytes.index(after: index)
            }
        }
        return result
    }

    /// A header frame: ZPAD ZPAD ZDLE ZBIN32, then the escaped
    /// [type, arg0, arg1, arg2, arg3, crc32×4] bytes.
    public static func makeHeader(type: FrameType, argument: UInt32 = 0) -> [UInt8] {
        let arg0 = UInt8(argument & 0xFF)
        let arg1 = UInt8((argument >> 8) & 0xFF)
        let arg2 = UInt8((argument >> 16) & 0xFF)
        let arg3 = UInt8((argument >> 24) & 0xFF)
        let unescapedBody: [UInt8] = [type.rawValue, arg0, arg1, arg2, arg3]
        let crc = crc32(unescapedBody)
        let crcBytes: [UInt8] = [
            UInt8(crc & 0xFF), UInt8((crc >> 8) & 0xFF), UInt8((crc >> 16) & 0xFF), UInt8((crc >> 24) & 0xFF),
        ]
        var frame: [UInt8] = [Control.zpad, Control.zpad, Control.zdle, Control.zbin32]
        frame += escape(unescapedBody + crcBytes)
        return frame
    }

    /// Parses the escaped header body (post ZPAD ZPAD ZDLE ZBIN32) back
    /// into its frame type and argument, verifying the CRC-32.
    public static func parseHeaderBody(_ escaped: [UInt8]) -> (type: FrameType, argument: UInt32)? {
        guard let body = unescape(escaped), body.count == 9 else { return nil }
        let unescapedBody = Array(body[0..<5])
        guard crc32(unescapedBody) == UInt32(body[5]) | (UInt32(body[6]) << 8) | (UInt32(body[7]) << 16) | (UInt32(body[8]) << 24) else {
            return nil
        }
        guard let type = FrameType(rawValue: body[0]) else { return nil }
        let argument = UInt32(body[1]) | (UInt32(body[2]) << 8) | (UInt32(body[3]) << 16) | (UInt32(body[4]) << 24)
        return (type, argument)
    }

    /// A data subpacket: escaped payload, then ZDLE + end-marker, then the
    /// escaped CRC-32 of (payload + end-marker byte).
    public static func makeDataSubpacket(_ payload: [UInt8], end: SubpacketEnd) -> [UInt8] {
        let crc = crc32(payload + [end.rawValue])
        let crcBytes: [UInt8] = [
            UInt8(crc & 0xFF), UInt8((crc >> 8) & 0xFF), UInt8((crc >> 16) & 0xFF), UInt8((crc >> 24) & 0xFF),
        ]
        var frame = escape(payload)
        frame.append(Control.zdle)
        frame.append(end.rawValue)
        frame += escape(crcBytes)
        return frame
    }

    /// Parses a data subpacket produced by `makeDataSubpacket`, scanning
    /// for the unescaped ZDLE + end-marker pair (distinguishable from an
    /// escaped payload byte because end-marker values never appear as an
    /// escape's second byte), then verifying the trailing CRC-32. Returns
    /// `nil` if the frame is truncated (no terminator found) or the CRC
    /// doesn't match.
    public static func parseDataSubpacket(_ frame: [UInt8]) -> (payload: [UInt8], end: SubpacketEnd)? {
        var payload: [UInt8] = []
        var index = frame.startIndex
        while index < frame.endIndex {
            let byte = frame[index]
            guard byte == Control.zdle else {
                payload.append(byte)
                index = frame.index(after: index)
                continue
            }
            let nextIndex = frame.index(after: index)
            guard nextIndex < frame.endIndex else { return nil }
            let next = frame[nextIndex]
            guard let end = SubpacketEnd(rawValue: next) else {
                payload.append(next ^ 0x40)
                index = frame.index(after: nextIndex)
                continue
            }
            let crcStart = frame.index(after: nextIndex)
            guard let crcBytes = unescape(Array(frame[crcStart...])), crcBytes.count == 4 else { return nil }
            let expectedCRC = crc32(payload + [end.rawValue])
            let actualCRC = UInt32(crcBytes[0]) | (UInt32(crcBytes[1]) << 8) | (UInt32(crcBytes[2]) << 16) | (UInt32(crcBytes[3]) << 24)
            guard expectedCRC == actualCRC else { return nil }
            return (payload, end)
        }
        return nil
    }
}
