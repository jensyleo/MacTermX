import Foundation
import Testing
@testable import MacTermXCore

@Suite("TextEncodingKind")
struct TextEncodingKindTests {
    @Test("UTF-8 passes bytes through unchanged")
    func utf8Passthrough() {
        let data = Data("héllo".utf8)
        #expect(TextEncodingKind.utf8.transcodeToUTF8(data) == data)
    }

    @Test("ASCII replaces bytes above 0x7F with '?'")
    func asciiReplacesHighBytes() {
        let data = Data([0x41, 0x42, 0xFF, 0x43])
        let result = TextEncodingKind.ascii.transcodeToUTF8(data)
        #expect(result == Data([0x41, 0x42, UInt8(ascii: "?"), 0x43]))
    }

    @Test("Latin-1 maps bytes 1:1 onto their Unicode scalar, re-encoded as UTF-8")
    func latin1MapsToUnicodeScalars() {
        // 0xE9 in Latin-1 is 'é' (U+00E9), which UTF-8 encodes as 0xC3 0xA9.
        let data = Data([0x41, 0xE9])
        let result = TextEncodingKind.latin1.transcodeToUTF8(data)
        #expect(result == Data([0x41, 0xC3, 0xA9]))
        #expect(String(decoding: result, as: UTF8.self) == "Aé")
    }
}
