import Foundation
import Testing
@testable import MacTermXCore

@Suite("TerminalEngine")
@MainActor
struct TerminalEngineTests {
    @Test("feeds incoming serial bytes into SwiftTerm's screen buffer")
    func incomingBytesReachBuffer() async throws {
        let transport = MockSerialTransport()
        let engine = TerminalEngine(transport: transport)

        transport.simulateIncoming(Data("hello".utf8))
        try await Task.sleep(for: .milliseconds(50))

        let text = (0..<5).map { engine.terminal.getCharacter(col: $0, row: 0) ?? " " }
        #expect(String(text) == "hello")
    }

    @Test("user input typed into the terminal is written to the transport")
    func userInputWritesToTransport() async throws {
        let transport = MockSerialTransport()
        let engine = TerminalEngine(transport: transport)

        engine.terminal.sendResponse(text: "ls\r")
        try await Task.sleep(for: .milliseconds(300))

        #expect(transport.written.map { String(decoding: $0, as: UTF8.self) } == ["ls\r"])
    }
}
