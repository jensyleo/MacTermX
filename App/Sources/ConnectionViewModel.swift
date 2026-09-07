import Combine
import Foundation
import MacTermXCore

enum ConsoleViewMode: String, CaseIterable, Identifiable {
    case text, hex
    var id: String { rawValue }
}

enum TerminalTypeKind: String, CaseIterable, Identifiable {
    case xterm256 = "xterm-256color"
    case vt100
    case ansi

    var id: String { rawValue }
    var label: String {
        switch self {
        case .xterm256: return "xterm-256color"
        case .vt100: return "VT100"
        case .ansi: return "ANSI"
        }
    }
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
    @Published var environment: SerialProfile.Environment = .lab
    @Published var lineEnding: LineEnding = .crlf
    @Published var localEcho = false
    @Published var sendAsHex = false
    @Published var encoding: TextEncodingKind = .utf8
    @Published var terminalType: TerminalTypeKind = .xterm256
    @Published var scrollback: Int = 500
    @Published var redactSensitiveData = false
    @Published var captureFormat: CaptureFormat = .plainText
    @Published private(set) var manualSignals = ModemSignals()
    @Published private(set) var captureURL: URL?
    @Published private(set) var lastCaptureHash: String?
    /// Freezes the displayed text/hex snapshot without stopping actual
    /// reception underneath — SwiftTerm keeps parsing, `CaptureLogger`
    /// keeps logging, only the view's refresh is held back. See RF-003's
    /// "pausa visual sin detener la recepción."
    @Published var isPaused = false

    /// Previously sent lines, newest last — CoolTerm's "Line Mode" command
    /// recall. Navigated via explicit Up/Down buttons in the console
    /// (not the arrow keys themselves: that needs an `NSViewRepresentable`
    /// text field to intercept key events, which isn't worth it yet on
    /// top of a plain SwiftUI `TextField`).
    @Published private(set) var commandHistory: [String] = []
    private static let maxHistoryEntries = 100

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

    init(device: SerialDevice, initialConfiguration: SerialConfiguration? = nil, initialEnvironment: SerialProfile.Environment = .lab) {
        self.device = device
        self.configuration = initialConfiguration ?? .fromPreferences()
        self.environment = initialEnvironment
        if initialConfiguration == nil {
            // Only apply app-wide defaults for a fresh port connection —
            // a profile (which supplied `initialConfiguration`) already
            // carries its own explicit line ending/echo choices elsewhere.
            self.lineEnding = .fromPreferences()
            self.localEcho = UserDefaults.standard.bool(forKey: AppPreferencesKeys.defaultLocalEcho)
        }
    }

    func connect() async {
        do {
            let transport = try ORSSerialTransport(devicePath: device.path)
            let profile = SerialProfile(name: device.name, environment: environment, serial: configuration)
            let coordinator = SessionCoordinator(
                profile: profile,
                transport: transport,
                termName: terminalType.rawValue,
                scrollback: scrollback,
                encoding: encoding
            )
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
        recordHistory(text)
        await sendRaw(payload)
    }

    func sendMacro(_ macro: MacroCommand) async {
        let expanded = MacroExpander.expand(macro, profileName: device.name)
        await sendRaw(Data(expanded.utf8))
    }

    private func recordHistory(_ text: String) {
        guard !text.isEmpty else { return }
        commandHistory.append(text)
        if commandHistory.count > Self.maxHistoryEntries {
            commandHistory.removeFirst(commandHistory.count - Self.maxHistoryEntries)
        }
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
            try capture.start(to: url, format: captureFormat)
            captureURL = url
            lastCaptureHash = nil
        } catch {
            lastError = String(describing: error)
        }
    }

    func stopCapture() {
        lastCaptureHash = capture.stop()
        captureURL = nil
    }

    func setPaused(_ paused: Bool) {
        isPaused = paused
        if !paused {
            refreshBuffer()
            hexDump = HexDump.format(rawLog)
        }
    }

    private func handleRawIncoming(_ data: Data) {
        capture.append(redactSensitiveData ? SensitiveRedactor.redact(data) : data)
        rawLog.append(data)
        if rawLog.count > Self.maxRawLogBytes {
            rawLog.removeFirst(rawLog.count - Self.maxRawLogBytes)
        }
        guard !isPaused else { return }
        hexDump = HexDump.format(rawLog)
    }

    private func refreshBuffer() {
        guard !isPaused else { return }
        lines = coordinator?.terminal.snapshotLines() ?? []
    }
}
