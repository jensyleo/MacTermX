import Foundation
import Testing
@testable import MacTermXCore

@Suite("MacroExpander")
struct MacroExpanderTests {
    @Test("expands {profile} and appends the configured line ending")
    func expandsProfileAndLineEnding() {
        let command = MacroCommand(name: "Greet", template: "hello {profile}", lineEnding: .crlf)
        let expanded = MacroExpander.expand(command, profileName: "Relay Lab")
        #expect(expanded == "hello Relay Lab\r\n")
    }

    @Test("expands {date} and {time} using the given reference date")
    func expandsDateAndTime() {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 5
        components.hour = 14
        components.minute = 30
        components.second = 0
        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(from: components)!

        let command = MacroCommand(name: "Stamp", template: "[{date} {time}]")
        let expanded = MacroExpander.expand(command, profileName: "x", now: date)
        #expect(expanded == "[2026-03-05 14:30:00]")
    }

    @Test("a template with no variables passes through unchanged plus line ending")
    func noVariables() {
        let command = MacroCommand(name: "Reset", template: "AT+RESET", lineEnding: .cr, isDangerous: true)
        #expect(MacroExpander.expand(command, profileName: "any") == "AT+RESET\r")
    }
}

@Suite("MacroStore")
struct MacroStoreTests {
    private func makeStore() -> (MacroStore, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return (MacroStore(directory: dir), dir)
    }

    @Test("saves and loads macros round-trip, scoped by key")
    func roundTrip() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let key = "/dev/cu.usbserial-1410"
        let macros = [
            MacroCommand(name: "Status", template: "AT+STATUS", lineEnding: .cr),
            MacroCommand(name: "Reboot", template: "AT+REBOOT", lineEnding: .cr, isDangerous: true),
        ]
        try store.save(macros, for: key)

        #expect(store.load(for: key) == macros)
    }

    @Test("loading for an unknown key returns an empty list, not an error")
    func loadUnknownProfile() {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(store.load(for: "/dev/cu.nonexistent").isEmpty)
    }
}
