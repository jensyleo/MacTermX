import Foundation
import Testing
@testable import MacTermXCore

@Suite("HexDump")
struct HexDumpTests {
    @Test("formats bytes with offset, hex, and printable ASCII columns")
    func formatsBasic() {
        let output = HexDump.format(Data("Hi!".utf8))
        #expect(output == "00000000  48 69 21                                         Hi!")
    }

    @Test("non-printable bytes render as a dot in the ASCII column")
    func nonPrintableAsDot() {
        let output = HexDump.format(Data([0x00, 0x41, 0xFF]))
        #expect(output.hasSuffix(".A."))
    }

    @Test("empty data formats to an empty string")
    func emptyData() {
        #expect(HexDump.format(Data()) == "")
    }

    @Test("parses space-separated hex into bytes")
    func parsesSpacedHex() {
        #expect(HexDump.parse("41 42 0D 0A") == Data([0x41, 0x42, 0x0D, 0x0A]))
    }

    @Test("parses contiguous hex into bytes")
    func parsesContiguousHex() {
        #expect(HexDump.parse("41420D0A") == Data([0x41, 0x42, 0x0D, 0x0A]))
    }

    @Test("rejects odd-length or non-hex input")
    func rejectsInvalidInput() {
        #expect(HexDump.parse("4") == nil)
        #expect(HexDump.parse("ZZ") == nil)
        #expect(HexDump.parse("") == nil)
    }
}
