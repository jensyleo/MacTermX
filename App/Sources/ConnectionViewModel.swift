import Combine
import Foundation
import MacTermXCore

@MainActor
final class ConnectionViewModel: ObservableObject {
    @Published private(set) var lines: [String] = []
    @Published private(set) var lastError: String?
    @Published private(set) var state: SessionState = .disconnected
    let device: SerialDevice
    private(set) var coordinator: SessionCoordinator?
    private var stateSubscription: AnyCancellable?

    init(device: SerialDevice) {
        self.device = device
    }

    func connect(baudRate: Int) async {
        do {
            let transport = try ORSSerialTransport(devicePath: device.path)
            let profile = SerialProfile(name: device.name, serial: SerialConfiguration(baudRate: baudRate))
            let coordinator = SessionCoordinator(profile: profile, transport: transport)
            coordinator.terminal.onUpdate = { [weak self] in self?.refreshBuffer() }
            stateSubscription = coordinator.$state.sink { [weak self] newState in
                self?.state = newState
            }
            self.coordinator = coordinator
            await coordinator.connect()
        } catch {
            lastError = String(describing: error)
        }
    }

    func disconnect() async {
        await coordinator?.disconnect()
    }

    func send(_ text: String, appendCRLF: Bool) async {
        guard let coordinator else { return }
        var payload = text
        if appendCRLF { payload += "\r\n" }
        do {
            try await coordinator.sendUserInput(Data(payload.utf8))
        } catch {
            lastError = String(describing: error)
        }
    }

    private func refreshBuffer() {
        lines = coordinator?.terminal.snapshotLines() ?? []
    }
}
