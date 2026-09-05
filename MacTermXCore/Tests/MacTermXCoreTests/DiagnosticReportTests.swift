import Foundation
import Testing
@testable import MacTermXCore

@Suite("DiagnosticReport")
struct DiagnosticReportTests {
    @Test("includes app version and omits session details when none is active")
    func noActiveSession() {
        let report = DiagnosticReport.generate(
            appVersion: "0.1.0",
            buildNumber: "1",
            activeSession: nil,
            lastError: nil
        )
        #expect(report.contains("0.1.0 (1)"))
        #expect(report.contains("(none)"))
    }

    @Test("includes sanitized serial configuration for the active session")
    func activeSessionIncluded() {
        let report = DiagnosticReport.generate(
            appVersion: "0.1.0",
            buildNumber: "1",
            activeSession: ("Relay Lab", SerialConfiguration(baudRate: 9600), "connected"),
            lastError: "port vanished"
        )
        #expect(report.contains("Relay Lab"))
        #expect(report.contains("9600"))
        #expect(report.contains("connected"))
        #expect(report.contains("port vanished"))
    }
}
