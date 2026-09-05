import Foundation
import Testing
@testable import MacTermXCore

@Suite("ZModemFraming")
struct ZModemFramingTests {
    @Test("CRC-32 matches the well-known check value for \"123456789\"")
    func crc32KnownVector() {
        #expect(ZModemFraming.crc32(Array("123456789".utf8)) == 0xCBF4_3926)
    }

    @Test("escape/unescape round-trips arbitrary bytes, including ZDLE and control chars")
    func escapeRoundTrip() {
        let original: [UInt8] = [0x00, 0x18, 0x0D, 0x1F, 0x41, 0x80, 0x9F, 0xFF, 0x7E]
        let escaped = ZModemFraming.escape(original)
        #expect(ZModemFraming.unescape(escaped) == original)
    }

    @Test("a header frame round-trips through makeHeader/parseHeaderBody")
    func headerRoundTrip() {
        let frame = ZModemFraming.makeHeader(type: .zrpos, argument: 0x1234_5678)
        // Strip ZPAD ZPAD ZDLE ZBIN32 to get the escaped body parseHeaderBody expects.
        let body = Array(frame.dropFirst(4))
        let parsed = ZModemFraming.parseHeaderBody(body)
        #expect(parsed?.type == .zrpos)
        #expect(parsed?.argument == 0x1234_5678)
    }

    @Test("a corrupted header CRC is rejected")
    func headerRejectsCorruption() {
        var frame = ZModemFraming.makeHeader(type: .zfile)
        frame[frame.count - 1] ^= 0xFF
        let body = Array(frame.dropFirst(4))
        #expect(ZModemFraming.parseHeaderBody(body) == nil)
    }

    @Test("a data subpacket round-trips through makeDataSubpacket/parseDataSubpacket")
    func dataSubpacketRoundTrip() {
        let payload = Array("hello zmodem, with a ZDLE byte: \u{18} inside".utf8)
        let frame = ZModemFraming.makeDataSubpacket(payload, end: .ackRequested)
        let parsed = ZModemFraming.parseDataSubpacket(frame)
        #expect(parsed?.payload == payload)
        #expect(parsed?.end == .ackRequested)
    }

    @Test("a corrupted data subpacket CRC is rejected")
    func dataSubpacketRejectsCorruption() {
        var frame = ZModemFraming.makeDataSubpacket(Array("data".utf8), end: .frameEnd)
        frame[frame.count - 1] ^= 0xFF
        #expect(ZModemFraming.parseDataSubpacket(frame) == nil)
    }
}
