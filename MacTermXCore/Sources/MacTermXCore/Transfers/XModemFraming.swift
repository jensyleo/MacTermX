import Foundation

/// Pure XMODEM framing: checksum/CRC16 and 128-byte block construction and
/// validation. No I/O, no transport, no timing — this is the piece the
/// full send/receive engine (with retries, timeouts and cancellation) will
/// build on, kept separately testable against known XMODEM byte layouts.
public enum XModemFraming {
    public static let blockSize = 128
    public static let paddingByte: UInt8 = 0x1A // SUB, standard XMODEM pad

    public enum Control {
        public static let soh: UInt8 = 0x01
        public static let eot: UInt8 = 0x04
        public static let ack: UInt8 = 0x06
        public static let nak: UInt8 = 0x15
        public static let can: UInt8 = 0x18
        public static let crcMode: UInt8 = 0x43 // 'C'
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

    /// Pads `payload` to `blockSize` with `paddingByte` and wraps it in a
    /// full XMODEM frame: SOH, block number, its one's-complement, the
    /// (padded) payload, and a trailing checksum or CRC16.
    public static func makeBlock(number: UInt8, payload: [UInt8], useCRC: Bool) -> [UInt8] {
        precondition(payload.count <= blockSize, "XMODEM payload must fit in one \(blockSize)-byte block")
        var padded = payload
        if padded.count < blockSize {
            padded += Array(repeating: paddingByte, count: blockSize - padded.count)
        }

        var frame: [UInt8] = [Control.soh, number, ~number]
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
    /// expected block number, verifying the block-number complement and
    /// the trailing checksum/CRC. Returns the 128-byte padded payload on
    /// success, `nil` on any mismatch (never throws — corrupt bytes from
    /// an untrusted serial device are expected, not exceptional).
    public static func validateBlock(_ frame: [UInt8], expectedNumber: UInt8, useCRC: Bool) -> [UInt8]? {
        let trailerSize = useCRC ? 2 : 1
        let expectedCount = 3 + blockSize + trailerSize
        guard frame.count == expectedCount, frame[0] == Control.soh else { return nil }
        guard frame[1] == expectedNumber, frame[2] == ~expectedNumber else { return nil }

        let payload = Array(frame[3..<(3 + blockSize)])
        let trailer = frame[(3 + blockSize)...]

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
