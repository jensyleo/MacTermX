import Foundation

/// The RX/TX character encoding a session assumes for incoming bytes.
/// SwiftTerm's own parser expects UTF-8 — this transcodes non-UTF-8
/// input into it before feeding the terminal, rather than trying to make
/// SwiftTerm itself encoding-aware.
public enum TextEncodingKind: String, Sendable, CaseIterable, Codable {
    case utf8
    case ascii
    case latin1

    /// Converts raw incoming bytes to a UTF-8 byte sequence SwiftTerm can
    /// parse directly. ASCII bytes above 0x7F are replaced with `?` — a
    /// deliberate lossy fallback (matches the classic terminal
    /// convention) rather than throwing away framing by dropping bytes.
    public func transcodeToUTF8(_ data: Data) -> Data {
        switch self {
        case .utf8:
            return data
        case .ascii:
            var result = Data()
            result.reserveCapacity(data.count)
            for byte in data {
                result.append(byte <= 0x7F ? byte : UInt8(ascii: "?"))
            }
            return result
        case .latin1:
            // Latin-1 code points map 1:1 onto the first 256 Unicode
            // scalars, so each byte becomes its corresponding scalar's
            // UTF-8 encoding (1 or 2 bytes).
            var result = Data()
            result.reserveCapacity(data.count)
            for byte in data {
                guard let scalar = Unicode.Scalar(UInt32(byte)) else { continue }
                result.append(contentsOf: Array(String(scalar).utf8))
            }
            return result
        }
    }
}
