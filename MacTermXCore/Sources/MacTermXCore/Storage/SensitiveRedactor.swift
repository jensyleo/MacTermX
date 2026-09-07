import Foundation

/// Redacts common secret-shaped substrings from captured text before it
/// hits disk — RF-005's "política configurable de redacción para
/// patrones sensibles." This is a best-effort, pattern-based filter, not
/// a guarantee: it catches recognizable shapes (password= assignments,
/// bearer tokens, private-key headers, AWS-style keys), not every secret
/// a device might ever print.
public enum SensitiveRedactor {
    private static let patterns: [(label: String, regex: NSRegularExpression)] = [
        ("password", try! NSRegularExpression(pattern: #"(?i)(password|passwd|pwd)\s*[:=]\s*\S+"#)),
        ("api key", try! NSRegularExpression(pattern: #"(?i)(api[_-]?key|apikey)\s*[:=]\s*\S+"#)),
        ("bearer token", try! NSRegularExpression(pattern: #"(?i)bearer\s+[A-Za-z0-9\-._~+/]+=*"#)),
        ("AWS access key", try! NSRegularExpression(pattern: #"AKIA[0-9A-Z]{16}"#)),
        ("private key block", try! NSRegularExpression(pattern: #"-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----"#)),
    ]

    /// Returns `text` with each recognized secret pattern replaced by
    /// `[REDACTED:<label>]`.
    public static func redact(_ text: String) -> String {
        var result = text
        for (label, regex) in patterns {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "[REDACTED:\(label)]")
        }
        return result
    }

    /// Byte-oriented convenience for capture logging: decodes as UTF-8
    /// (lossy, since raw serial bytes aren't guaranteed valid UTF-8),
    /// redacts, and re-encodes.
    public static func redact(_ data: Data) -> Data {
        Data(redact(String(decoding: data, as: UTF8.self)).utf8)
    }
}

/// Applies `SensitiveRedactor` across a live byte stream rather than one
/// isolated chunk at a time. A secret pattern (especially a multi-line one
/// like a PEM private-key block) can straddle two separate reads from a
/// serial device — plain per-chunk redaction would miss anything split
/// across that boundary. This keeps a bounded trailing window of
/// not-yet-emitted bytes so a pattern spanning two chunks still gets
/// caught, without buffering the whole stream.
public final class StreamingRedactor {
    private var pending = Data()
    private let overlapWindow: Int

    public init(overlapWindow: Int = 4096) {
        self.overlapWindow = overlapWindow
    }

    /// Feeds new data in; returns the prefix of it (if any) that's now
    /// safe to write out, already redacted. The trailing `overlapWindow`
    /// bytes are always held back until the next call (or `flush()`), so
    /// a pattern beginning near the end of this chunk has a chance to be
    /// completed by the next one before being redacted and released.
    public func process(_ data: Data) -> Data {
        pending.append(data)
        guard pending.count > overlapWindow * 2 else { return Data() }
        let redacted = SensitiveRedactor.redact(pending)
        let emitCount = redacted.count - overlapWindow
        guard emitCount > 0 else { return Data() }
        let toEmit = redacted.prefix(emitCount)
        pending = Data(redacted.suffix(from: emitCount))
        return Data(toEmit)
    }

    /// Call when the stream ends (e.g. capture stopped) to redact and
    /// return whatever's still held back.
    public func flush() -> Data {
        defer { pending = Data() }
        return SensitiveRedactor.redact(pending)
    }
}
