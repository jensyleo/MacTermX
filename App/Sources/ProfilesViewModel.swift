import Foundation
import MacTermXCore

@MainActor
final class ProfilesViewModel: ObservableObject {
    @Published private(set) var profiles: [SerialProfile] = []
    private let store: ProfileStore

    init() {
        let directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MacTermX/Profiles", isDirectory: true)
        self.store = ProfileStore(directory: directory)
        reload()
    }

    func reload() {
        profiles = (try? store.loadAll())?.sorted { $0.name < $1.name } ?? []
    }

    func save(_ profile: SerialProfile) {
        try? store.save(profile)
        reload()
    }

    func delete(_ profile: SerialProfile) {
        try? store.delete(profile)
        reload()
    }

    /// Finds the live port this profile was captured from, matching by
    /// USB identity (never by path — a profile deliberately doesn't store
    /// one, since the same device can enumerate under a different
    /// `/dev/cu.*` path next time it's plugged in).
    func matchingDevice(for profile: SerialProfile, in devices: [SerialDevice]) -> SerialDevice? {
        devices.first {
            $0.vendorId == profile.deviceMatch.vendorId &&
                $0.productId == profile.deviceMatch.productId &&
                (profile.deviceMatch.serialNumber == nil || $0.serialNumber == profile.deviceMatch.serialNumber)
        }
    }
}
