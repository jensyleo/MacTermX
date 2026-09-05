import Combine
import Foundation
import MacTermXCore

enum ConsoleViewMode: String, CaseIterable, Identifiable {
    case text, hex
    var id: String { rawValue }
}

@MainActor
final class ConnectionViewModel: ObservableObject {
    @Published private(set) var lines: [String] = []
    @Published private(set) var hexDump = ""
    @Published private(set) var lastError: String?
    @Published private(set) var state: SessionState = .disconnected
    @Published private(set) var cts = false
    @Published private(set) var dsr = false
    @Published private(set) var dcd = false
    @Published var configuration = SerialConfiguration()
    @Published var lineEnding: LineEnding = .crlf
    @Published var localEcho = false
    @Published var sendAsHex = false
    @Published private(set) var manualSignals = ModemSignals()
    @Published private(set) var captureURL: URL?

    let device: SerialDevice
    private(set) var coordinator: SessionCoordinator?
    private var subscriptions: Set<AnyCancellable> = []
    private let capture = CaptureLogger()
    private var rawLog = Data()
    private static let maxRawLogBytes = 1 << 20 // 1 MiB of scrollback for the hex view

    var liveSignals: (cts: Bool, dsr: Bool, dcd: Bool)? {
        state == .connected ? (cts, dsr, dcd) : nil
    }

    var isCapturing: Bool { captureURL != nil }

    init(device: SerialDevice, initialConfiguration: SerialConfiguration? = nil) {
        self.device = device
        if let initialConfiguration {
            self.configuration = initialConfiguration
        }
    }

    func connect() async {
        do {
            let transport = try ORSSerialTransport(devicePath: device.path)
            let profile = SerialProfile(name: device.name, serial: configuration)
            let coordinator = SessionCoordinator(profile: profile, transport: transport)
            coordinator.terminal.onUpdate = { [weak self] in self?.refreshBuffer() }
            coordinator.onRawIncomingData = { [weak self] in self?.handleRawIncoming($0) }
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
        let payload: Data
        if sendAsHex {
            guard let bytes = HexDump.parse(text) else {
                lastError = "Invalid hex — use pairs of hex digits, e.g. \"41 0D 0A\"."
                return
            }
            payload = bytes
        } else {
            payload = Data((text + lineEnding.bytes).utf8)
        }
        await sendRaw(payload)
    }

    func sendMacro(_ macro: MacroCommand) async {
        let expanded = MacroExpander.expand(macro, profileName: device.name)
        await sendRaw(Data(expanded.utf8))
    }

    private func sendRaw(_ payload: Data) async {
        guard let coordinator else { return }
        if localEcho {
            coordinator.terminal.feed(payload)
        }
        do {
            try await coordinator.sendUserInput(payload)
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

    func startCapture(to url: URL) {
        do {
            try capture.start(to: url)
            captureURL = url
        } catch {
            lastError = String(describing: error)
        }
    }

    func stopCapture() {
        capture.stop()
        captureURL = nil
    }

    private func handleRawIncoming(_ data: Data) {
        capture.append(data)
        rawLog.append(data)
        if rawLog.count > Self.maxRawLogBytes {
            rawLog.removeFirst(rawLog.count - Self.maxRawLogBytes)
        }
        hexDump = HexDump.format(rawLog)
    }

    private func refreshBuffer() {
        lines = coordinator?.terminal.snapshotLines() ?? []
    }
}
