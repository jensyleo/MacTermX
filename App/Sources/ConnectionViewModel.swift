import Combine
import Foundation
import MacTermXCore

@MainActor
final class ConnectionViewModel: ObservableObject {
    @Published private(set) var lines: [String] = []
    @Published private(set) var lastError: String?
    @Published private(set) var state: SessionState = .disconnected
    @Published private(set) var cts = false
    @Published private(set) var dsr = false
    @Published private(set) var dcd = false
    @Published var configuration = SerialConfiguration()
    @Published var lineEnding: LineEnding = .crlf
    @Published var localEcho = false
    @Published private(set) var manualSignals = ModemSignals()

    let device: SerialDevice
    private(set) var coordinator: SessionCoordinator?
    private var subscriptions: Set<AnyCancellable> = []

    var liveSignals: (cts: Bool, dsr: Bool, dcd: Bool)? {
        state == .connected ? (cts, dsr, dcd) : nil
    }

    init(device: SerialDevice) {
        self.device = device
    }

    func connect() async {
        do {
            let transport = try ORSSerialTransport(devicePath: device.path)
            let profile = SerialProfile(name: device.name, serial: configuration)
            let coordinator = SessionCoordinator(profile: profile, transport: transport)
            coordinator.terminal.onUpdate = { [weak self] in self?.refreshBuffer() }
            subscriptions.removeAll()
            coordinator.$state.sink { [weak self] in self?.state = $0 }.store(in: &subscriptions)
            coordinator.$cts.sink { [weak self] in self?.cts = $0 }.store(in: &subscriptions)
            coordinator.$dsr.sink { [weak self] in self?.dsr = $0 }.store(in: &subscriptions)
            coordinator.$dcd.sink { [weak self] in self?.dcd = $0 }.store(in: &subscriptions)
            self.coordinator = coordinator
            await coordinator.connect()
        } catch {
            lastError = String(describing: error)
        }
    }

    func disconnect() async {
        await coordinator?.disconnect()
    }

    func send(_ text: String) async {
        guard let coordinator else { return }
        let payload = text + lineEnding.bytes
        if localEcho {
            coordinator.terminal.feed(Data(payload.utf8))
        }
        do {
            try await coordinator.sendUserInput(Data(payload.utf8))
        } catch {
            lastError = String(describing: error)
        }
    }

    func setManualSignals(_ signals: ModemSignals) {
        manualSignals = signals
        guard let coordinator else { return }
        Task {
            do {
                try await coordinator.setSignals(signals)
            } catch {
                lastError = String(describing: error)
            }
        }
    }

    private func refreshBuffer() {
        lines = coordinator?.terminal.snapshotLines() ?? []
    }
}
