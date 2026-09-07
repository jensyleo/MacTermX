import Foundation
import MacTermXCore
import SwiftUI

/// App-level defaults (Settings scene, ⌘,) — distinct from `PortSettingsView`,
/// which configures the *current* connection. These are just the starting
/// point for a newly opened session; nothing here is enforced afterward.
enum AppPreferencesKeys {
    static let defaultBaudRate = "defaultBaudRate"
    static let defaultLineEnding = "defaultLineEnding"
    static let defaultLocalEcho = "defaultLocalEcho"
    static let consoleTheme = "consoleTheme"
}

enum ConsoleTheme: String, CaseIterable, Identifiable {
    case classicGreen
    case neutral

    var id: String { rawValue }

    var label: String {
        switch self {
        case .classicGreen: return "Classic Green"
        case .neutral: return "Neutral"
        }
    }

    var background: Color {
        switch self {
        case .classicGreen: return .black
        case .neutral: return Color(nsColor: .textBackgroundColor)
        }
    }

    var foreground: Color {
        switch self {
        case .classicGreen: return .green
        case .neutral: return Color(nsColor: .textColor)
        }
    }
}

extension SerialConfiguration {
    /// Seeds a fresh configuration from the app's stored preferences,
    /// falling back to `SerialConfiguration`'s own defaults for anything
    /// not yet set (first launch).
    static func fromPreferences() -> SerialConfiguration {
        var config = SerialConfiguration()
        let defaults = UserDefaults.standard
        let storedBaud = defaults.integer(forKey: AppPreferencesKeys.defaultBaudRate)
        if storedBaud > 0 {
            config.baudRate = storedBaud
        }
        return config
    }
}

extension LineEnding {
    static func fromPreferences() -> LineEnding {
        guard let raw = UserDefaults.standard.string(forKey: AppPreferencesKeys.defaultLineEnding),
              let ending = LineEnding(rawValue: raw) else {
            return .crlf
        }
        return ending
    }
}

struct AppPreferencesView: View {
    @AppStorage(AppPreferencesKeys.defaultBaudRate) private var defaultBaudRate = 115_200
    @AppStorage(AppPreferencesKeys.defaultLineEnding) private var defaultLineEnding = LineEnding.crlf.rawValue
    @AppStorage(AppPreferencesKeys.defaultLocalEcho) private var defaultLocalEcho = false
    @AppStorage(AppPreferencesKeys.consoleTheme) private var consoleTheme = ConsoleTheme.classicGreen.rawValue

    private static let commonBaudRates = [300, 1200, 2400, 4800, 9600, 19200, 38400, 57600, 115_200, 230_400]

    var body: some View {
        Form {
            Section("New Session Defaults") {
                Picker("Baud Rate", selection: $defaultBaudRate) {
                    ForEach(Self.commonBaudRates, id: \.self) { Text("\($0)").tag($0) }
                }
                Picker("Line Ending on Send", selection: $defaultLineEnding) {
                    ForEach(LineEnding.allCases) { Text($0.label).tag($0.rawValue) }
                }
                Toggle("Local Echo", isOn: $defaultLocalEcho)
                Text("Applies to newly opened sessions only — reconnecting an already-open tab keeps its current settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Appearance") {
                Picker("Console Theme", selection: $consoleTheme) {
                    ForEach(ConsoleTheme.allCases) { Text($0.label).tag($0.rawValue) }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 280)
        .padding()
    }
}
