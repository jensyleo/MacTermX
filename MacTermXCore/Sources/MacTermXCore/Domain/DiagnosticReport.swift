import Foundation

/// A support/troubleshooting bundle with no session content by default —
/// version, platform, and a sanitized serial configuration (never a
/// secret to begin with, since `SerialConfiguration` carries none) — per
/// RF-009's "sin datos de sesión por defecto" requirement. Console output
/// or capture files are opt-in, attached by the caller only after the
/// user explicitly consents.
public struct DiagnosticReport {
    public static func generate(
        appVersion: String,
        buildNumber: String,
        activeSession: (deviceName: String, configuration: SerialConfiguration, state: String)?,
        lastError: String?
    ) -> String {
        var lines: [String] = []
        lines.append("MacTermX Diagnostic Report")
        lines.append("Generated: \(ISO8601DateFormatter().string(from: Date()))")
        lines.append("")
        lines.append("## App")
        lines.append("Version: \(appVersion) (\(buildNumber))")
        lines.append("")
        lines.append("## System")
        lines.append("macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        lines.append("Architecture: \(architecture)")
        lines.append("")
        lines.append("## Active Session")
        if let session = activeSession {
            lines.append("Device: \(session.deviceName)")
            lines.append("State: \(session.state)")
            lines.append("Baud Rate: \(session.configuration.baudRate)")
            lines.append("Data Bits: \(session.configuration.dataBits)")
            lines.append("Parity: \(session.configuration.parity.rawValue)")
            lines.append("Stop Bits: \(session.configuration.stopBits)")
            lines.append("Flow Control: \(session.configuration.flowControl.rawValue)")
        } else {
            lines.append("(none)")
        }
        lines.append("")
        lines.append("## Last Error")
        lines.append(lastError ?? "(none)")
        return lines.joined(separator: "\n")
    }

    private static var architecture: String {
        #if arch(arm64)
        return "arm64 (Apple Silicon)"
        #elseif arch(x86_64)
        return "x86_64 (Intel)"
        #else
        return "unknown"
        #endif
    }
}
