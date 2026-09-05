import Foundation
import Testing
@testable import MacTermXCore

@Suite("XModemFraming")
struct XModemFramingTests {
    @Test("checksum is the 8-bit sum of the payload, wrapping on overflow")
    func checksumWraps() {
        let payload = [UInt8](repeating: 0xFF, count: 4)
        #expect(XModemFraming.checksum(payload) == 0xFC) // 4*255 = 1020 mod 256 = 252
    }

    @Test("CRC16/XMODEM matches the well-known vector for \"123456789\"")
    func crc16KnownVector() {
        let payload = Array("123456789".utf8)
        #expect(XModemFraming.crc16(payload) == 0x31C3)
    }

    @Test("makeBlock pads short payloads to 128 bytes with 0x1A")
    func padsShortPayload() {
        let block = XModemFraming.makeBlock(number: 1, payload: Array("hi".utf8), useCRC: false)
        #expect(block.count == 3 + 128 + 1)
        #expect(block[3] == UInt8(ascii: "h"))
        #expect(block[4] == UInt8(ascii: "i"))
        #expect(block[5] == XModemFraming.paddingByte)
    }

    @Test("a block round-trips through makeBlock/validateBlock, checksum mode")
    func roundTripChecksum() {
        let payload = Array("hello xmodem".utf8)
        let block = XModemFraming.makeBlock(number: 5, payload: payload, useCRC: false)
        let recovered = XModemFraming.validateBlock(block, expectedNumber: 5, useCRC: false)
        #expect(recovered?.prefix(payload.count).elementsEqual(payload) == true)
    }

    @Test("a block round-trips through makeBlock/validateBlock, CRC mode")
    func roundTripCRC() {
        let payload = Array("hello xmodem".utf8)
        let block = XModemFraming.makeBlock(number: 5, payload: payload, useCRC: true)
        let recovered = XModemFraming.validateBlock(block, expectedNumber: 5, useCRC: true)
        #expect(recovered?.prefix(payload.count).elementsEqual(payload) == true)
    }

    @Test("a single flipped byte in the payload is detected in both modes")
    func detectsCorruption() {
        let payload = Array("hello xmodem".utf8)
        for useCRC in [false, true] {
            var block = XModemFraming.makeBlock(number: 1, payload: payload, useCRC: useCRC)
            block[10] ^= 0xFF
            #expect(XModemFraming.validateBlock(block, expectedNumber: 1, useCRC: useCRC) == nil)
        }
    }

    @Test("a mismatched block number complement is rejected")
    func detectsBadBlockNumberComplement() {
        var block = XModemFraming.makeBlock(number: 1, payload: [1, 2, 3], useCRC: false)
        block[2] = 0x00 // corrupt the one's-complement byte
        #expect(XModemFraming.validateBlock(block, expectedNumber: 1, useCRC: false) == nil)
    }

    @Test("a block presented with the wrong expected number is rejected")
    func detectsWrongExpectedNumber() {
        let block = XModemFraming.makeBlock(number: 2, payload: [1, 2, 3], useCRC: false)
        #expect(XModemFraming.validateBlock(block, expectedNumber: 1, useCRC: false) == nil)
    }
}
