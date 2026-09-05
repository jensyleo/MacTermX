import Foundation

/// A saved quick command / macro, scoped to a profile. Templates may
/// reference a small, fixed set of approved variables — never arbitrary
/// code — per the project's security-by-design goals (no scripting engine
/// in the macro system itself).
public struct MacroCommand: Sendable, Equatable, Hashable, Codable, Identifiable {
    public var id: UUID
    public var name: String
    public var template: String
    public var lineEnding: LineEndingKind
    /// Requires explicit confirmation before sending — for anything that
    /// could disrupt or reset the connected device.
    public var isDangerous: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        template: String,
        lineEnding: LineEndingKind = .none,
        isDangerous: Bool = false
    ) {
        self.id = id
        self.name = name
        self.template = template
        self.lineEnding = lineEnding
        self.isDangerous = isDangerous
    }
}

public enum LineEndingKind: String, Sendable, Codable, CaseIterable {
    case none, cr, lf, crlf

    public var bytes: String {
        switch self {
        case .none: return ""
        case .cr: return "\r"
        case .lf: return "\n"
        case .crlf: return "\r\n"
        }
    }
}

/// Expands a macro's approved variables (`{date}`, `{time}`, `{profile}`)
/// into literal text — a fixed substitution table, not a template
/// language, so a macro can never execute arbitrary logic.
public enum MacroExpander {
    public static func expand(_ command: MacroCommand, profileName: String, now: Date = Date()) -> String {
        var result = command.template
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"

        result = result.replacingOccurrences(of: "{date}", with: dateFormatter.string(from: now))
        result = result.replacingOccurrences(of: "{time}", with: timeFormatter.string(from: now))
        result = result.replacingOccurrences(of: "{profile}", with: profileName)
        return result + command.lineEnding.bytes
    }
}
