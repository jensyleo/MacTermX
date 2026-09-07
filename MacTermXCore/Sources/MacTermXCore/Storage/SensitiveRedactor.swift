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
