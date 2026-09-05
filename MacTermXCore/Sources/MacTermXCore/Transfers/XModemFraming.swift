import Foundation

/// Pure XMODEM framing: checksum/CRC16 and 128-byte block construction and
/// validation. No I/O, no transport, no timing — this is the piece the
/// full send/receive engine (with retries, timeouts and cancellation) will
/// build on, kept separately testable against known XMODEM byte layouts.
public enum XModemFraming {
    public static let blockSize = 128
    public static let blockSize1K = 1024
    public static let paddingByte: UInt8 = 0x1A // SUB, standard XMODEM pad

    public enum Control {
        public static let soh: UInt8 = 0x01 // 128-byte block follows
        public static let stx: UInt8 = 0x02 // 1024-byte block follows (XMODEM-1K/YMODEM)
        public static let eot: UInt8 = 0x04
        public static let ack: UInt8 = 0x06
        public static let nak: UInt8 = 0x15
        public static let can: UInt8 = 0x18
        public static let crcMode: UInt8 = 0x43 // 'C'
    }

    /// The block size a frame's leading control byte (SOH/STX) declares,
    /// or `nil` if it isn't a recognized block header.
    public static func blockSize(forHeader header: UInt8) -> Int? {
        switch header {
        case Control.soh: return blockSize
        case Control.stx: return blockSize1K
        default: return nil
        }
    }

    /// Simple 8-bit sum checksum (original XMODEM).
    public static func checksum(_ payload: [UInt8]) -> UInt8 {
        payload.reduce(0) { $0 &+ $1 }
    }

    /// CRC-16/XMODEM: poly 0x1021, init 0x0000, no reflection, no final XOR.
    public static func crc16(_ payload: [UInt8]) -> UInt16 {
        var crc: UInt16 = 0
        for byte in payload {
            crc ^= UInt16(byte) << 8
            for _ in 0..<8 {
                if crc & 0x8000 != 0 {
                    crc = (crc << 1) ^ 0x1021
                } else {
                    crc <<= 1
                }
            }
        }
        return crc
    }

    /// Pads `payload` to `size` (128 for SOH, 1024 for STX) with
    /// `paddingByte` and wraps it in a full XMODEM frame: the header byte,
    /// block number, its one's-complement, the (padded) payload, and a
    /// trailing checksum or CRC16.
    public static func makeBlock(number: UInt8, payload: [UInt8], useCRC: Bool, size: Int = blockSize) -> [UInt8] {
        precondition(payload.count <= size, "XMODEM payload must fit in one \(size)-byte block")
        let header: UInt8 = size == blockSize1K ? Control.stx : Control.soh
        var padded = payload
        if padded.count < size {
            padded += Array(repeating: paddingByte, count: size - padded.count)
        }

        var frame: [UInt8] = [header, number, ~number]
        frame += padded
        if useCRC {
            let crc = crc16(padded)
            frame += [UInt8(crc >> 8), UInt8(crc & 0xFF)]
        } else {
            frame.append(checksum(padded))
        }
        return frame
    }

    /// Validates a full frame (as produced by `makeBlock`) against the
    /// expected block number, verifying the header's declared size, the
    /// block-number complement, and the trailing checksum/CRC. Returns the
    /// padded payload on success, `nil` on any mismatch (never throws —
    /// corrupt bytes from an untrusted serial device are expected, not
    /// exceptional).
    public static func validateBlock(_ frame: [UInt8], expectedNumber: UInt8, useCRC: Bool) -> [UInt8]? {
        guard let header = frame.first, let size = blockSize(forHeader: header) else { return nil }
        let trailerSize = useCRC ? 2 : 1
        let expectedCount = 3 + size + trailerSize
        guard frame.count == expectedCount else { return nil }
        guard frame[1] == expectedNumber, frame[2] == ~expectedNumber else { return nil }

        let payload = Array(frame[3..<(3 + size)])
        let trailer = frame[(3 + size)...]

        if useCRC {
            let crc = crc16(payload)
            guard trailer.first == UInt8(crc >> 8), trailer.dropFirst().first == UInt8(crc & 0xFF) else {
                return nil
            }
        } else {
            guard trailer.first == checksum(payload) else { return nil }
        }
        return payload
    }
}
