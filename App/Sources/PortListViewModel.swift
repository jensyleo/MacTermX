import Foundation
import MacTermXCore

@MainActor
final class PortListViewModel: ObservableObject {
    @Published private(set) var ports: [SerialDevice] = []
    private let discovery: PortDiscovering
    private var watchTask: Task<Void, Never>?

    init(discovery: PortDiscovering = ORSPortDiscovery()) {
        self.discovery = discovery
        watchTask = Task { [weak self] in
            guard let self else { return }
            for await _ in discovery.changes {
                await self.refresh()
            }
        }
        Task { await refresh() }
    }

    deinit {
        watchTask?.cancel()
    }

    func refresh() async {
        ports = (try? await discovery.availablePorts()) ?? []
    }
}
