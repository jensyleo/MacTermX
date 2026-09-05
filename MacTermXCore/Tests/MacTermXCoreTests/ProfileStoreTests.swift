import Foundation
import Testing
@testable import MacTermXCore

@Suite("ProfileStore")
struct ProfileStoreTests {
    private func makeStore() -> (ProfileStore, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return (ProfileStore(directory: dir), dir)
    }

    @Test("saves and loads a profile round-trip")
    func roundTrip() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let profile = SerialProfile(
            name: "Relay Lab",
            environment: .lab,
            deviceMatch: .init(vendorId: "0x0403", productId: "0x6001"),
            serial: SerialConfiguration(baudRate: 9600)
        )
        try store.save(profile)

        let loaded = try store.loadAll()
        #expect(loaded == [profile])
    }

    @Test("rejects a profile from a newer, unsupported schema version")
    func rejectsFutureSchema() {
        let (store, _) = makeStore()
        let futureJSON = """
        {
          "schemaVersion": 999,
          "id": "\(UUID().uuidString)",
          "name": "From the future",
          "environment": "lab",
          "deviceMatch": {},
          "serial": {"baudRate": 9600, "dataBits": 8, "stopBits": 1, "parity": "none", "flowControl": "none"},
          "groupTags": []
        }
        """.data(using: .utf8)!

        #expect(throws: SerialProfileError.unsupportedSchemaVersion(999)) {
            try store.decode(futureJSON)
        }
    }

    @Test("deletes a saved profile")
    func delete() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let profile = SerialProfile(name: "Temp")
        try store.save(profile)
        try store.delete(profile)

        #expect(try store.loadAll().isEmpty)
    }
}
