import Foundation

/// Formats bytes as a classic hex dump: offset, 16 hex bytes per row, and
/// the printable-ASCII rendering alongside — the "hexadecimal format" view
/// CoolTerm and similar serial terminals offer next to their text view.
public enum HexDump {
    public static func format(_ data: Data, bytesPerRow: Int = 16) -> String {
        guard !data.isEmpty else { return "" }
        var lines: [String] = []
        let bytes = [UInt8](data)
        var offset = 0
        while offset < bytes.count {
            let end = min(offset + bytesPerRow, bytes.count)
            let row = bytes[offset..<end]
            let hex = row.map { String(format: "%02X", $0) }.joined(separator: " ")
            let padded = hex.padding(toLength: bytesPerRow * 3 - 1, withPad: " ", startingAt: 0)
            let ascii = String(row.map { (0x20...0x7E).contains($0) ? Character(UnicodeScalar($0)) : "." })
            lines.append(String(format: "%08X  %@  %@", offset, padded, ascii))
            offset = end
        }
        return lines.joined(separator: "\n")
    }

    /// Parses a hex string like "41 42 0D 0A" or "41420D0A" into bytes, for
    /// a "Send in hex" input mode. Returns `nil` if any token isn't valid
    /// hex — the caller (untrusted user input) should surface that as an
    /// error rather than silently sending a truncated/garbled payload.
    public static func parse(_ hexString: String) -> Data? {
        let cleaned = hexString.filter { !$0.isWhitespace }
        guard !cleaned.isEmpty, cleaned.count % 2 == 0 else { return nil }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(cleaned.count / 2)
        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let next = cleaned.index(index, offsetBy: 2)
            guard let byte = UInt8(cleaned[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        return Data(bytes)
    }
}
