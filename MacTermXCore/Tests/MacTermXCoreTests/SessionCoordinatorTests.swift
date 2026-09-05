import Foundation
import Testing
@testable import MacTermXCore

@Suite("SessionCoordinator")
@MainActor
struct SessionCoordinatorTests {
    @Test("moves disconnected -> opening -> connected on a successful open")
    func connectSucceeds() async throws {
        let transport = MockSerialTransport()
        let coordinator = SessionCoordinator(profile: SerialProfile(name: "Test"), transport: transport)

        #expect(coordinator.state == .disconnected)
        await coordinator.connect()
        try await Task.sleep(for: .milliseconds(300))

        #expect(coordinator.state == .connected)
    }

    @Test("moves to failed when the transport reports an error")
    func transportErrorFails() async throws {
        let transport = MockSerialTransport()
        let coordinator = SessionCoordinator(profile: SerialProfile(name: "Test"), transport: transport)

        await coordinator.connect()
        try await Task.sleep(for: .milliseconds(50))
        transport.simulateError("port vanished")
        try await Task.sleep(for: .milliseconds(50))

        #expect(coordinator.state == .failed("port vanished"))
    }

    @Test("disconnect closes the transport and returns to disconnected")
    func disconnect() async throws {
        let transport = MockSerialTransport()
        let coordinator = SessionCoordinator(profile: SerialProfile(name: "Test"), transport: transport)

        await coordinator.connect()
        try await Task.sleep(for: .milliseconds(50))
        await coordinator.disconnect()

        #expect(coordinator.state == .disconnected)
    }
}
