import Foundation
import MacTermXCore

/// One open session tab: a device (or a profile resolved to a live
/// device), its `ConnectionViewModel`, and a stable identity so selecting
/// the same port/profile twice activates the existing tab instead of
/// opening a duplicate.
struct SessionTab: Identifiable {
    let id: UUID = UUID()
    let key: String // device path — the natural de-duplication key
    let title: String
    let connectionViewModel: ConnectionViewModel
}

@MainActor
final class SessionTabsViewModel: ObservableObject {
    @Published private(set) var tabs: [SessionTab] = []
    @Published var activeTabID: UUID?

    var activeTab: SessionTab? {
        tabs.first { $0.id == activeTabID }
    }

    func openPort(_ device: SerialDevice) {
        activate(key: device.path, title: device.name) {
            ConnectionViewModel(device: device)
        }
    }

    func openProfile(_ profile: SerialProfile, device: SerialDevice) {
        activate(key: device.path, title: profile.name) {
            ConnectionViewModel(device: device, initialConfiguration: profile.serial, initialEnvironment: profile.environment)
        }
    }

    private func activate(key: String, title: String, makeViewModel: () -> ConnectionViewModel) {
        if let existing = tabs.first(where: { $0.key == key }) {
            activeTabID = existing.id
            return
        }
        let tab = SessionTab(key: key, title: title, connectionViewModel: makeViewModel())
        tabs.append(tab)
        activeTabID = tab.id
    }

    /// `true` if closing this tab needs confirmation first — an active
    /// transfer would be aborted mid-flight (see the project's own
    /// "Prevención de cierre accidental durante una transferencia").
    func closeNeedsConfirmation(_ tab: SessionTab) -> Bool {
        tab.connectionViewModel.state == .transferring
    }

    func close(_ tab: SessionTab) {
        tabs.removeAll { $0.id == tab.id }
        if activeTabID == tab.id {
            activeTabID = tabs.last?.id
        }
        Task { await tab.connectionViewModel.disconnect() }
    }
}
