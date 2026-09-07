import MacTermXCore
import SwiftUI

/// The serial port configuration sheet — modeled on CoolTerm's and
/// ZTerm's "Serial Port"/"Connection" settings: line settings, flow
/// control (with manual DTR/RTS override when hardware flow control is
/// off), and live CTS/DSR/DCD signal indicators.
struct PortSettingsView: View {
    @Binding var configuration: SerialConfiguration
    @Binding var environment: SerialProfile.Environment
    @Binding var lineEnding: LineEnding
    @Binding var localEcho: Bool
    @Binding var encoding: TextEncodingKind
    @Binding var terminalType: TerminalTypeKind
    @Binding var scrollback: Int
    @Binding var redactSensitiveData: Bool
    @Binding var captureFormat: CaptureFormat
    var liveSignals: (cts: Bool, dsr: Bool, dcd: Bool)?
    var manualSignals: ModemSignals
    var onManualSignalsChange: (ModemSignals) -> Void
    var isConnected: Bool
    @Environment(\.dismiss) private var dismiss

    private static let commonBaudRates = [300, 1200, 2400, 4800, 9600, 19200, 38400, 57600, 115_200, 230_400]

    var body: some View {
        Form {
            Section("Line Settings") {
                Picker("Baud Rate", selection: $configuration.baudRate) {
                    ForEach(Self.commonBaudRates, id: \.self) { rate in
                        Text("\(rate)").tag(rate)
                    }
                }
                TextField(
                    "Custom Baud Rate",
                    value: $configuration.baudRate,
                    format: .number.grouping(.never)
                )
                .help("Enter a non-standard baud rate directly, e.g. for embedded devices.")

                Picker("Data Bits", selection: $configuration.dataBits) {
                    ForEach([5, 6, 7, 8], id: \.self) { Text("\($0)").tag($0) }
                }
                Picker("Parity", selection: $configuration.parity) {
                    Text("None").tag(SerialConfiguration.Parity.none)
                    Text("Even").tag(SerialConfiguration.Parity.even)
                    Text("Odd").tag(SerialConfiguration.Parity.odd)
                }
                Picker("Stop Bits", selection: $configuration.stopBits) {
                    Text("1").tag(1)
                    Text("2").tag(2)
                }
            }

            Section("Flow Control") {
                Picker("Flow Control", selection: $configuration.flowControl) {
                    Text("None").tag(SerialConfiguration.FlowControl.none)
                    Text("RTS/CTS (hardware)").tag(SerialConfiguration.FlowControl.rtsCts)
                    Text("XON/XOFF (software)").tag(SerialConfiguration.FlowControl.xonXoff)
                }
                if configuration.flowControl == .xonXoff {
                    Text("Implemented at the byte-stream level: MacTermX pauses sending when the device sends XOFF (0x13) and resumes on XON (0x11); both bytes are stripped from the console/capture. It doesn't touch the RTS/DTR lines — that's what RTS/CTS above is for.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if configuration.flowControl != .rtsCts {
                    Toggle("DTR", isOn: Binding(
                        get: { manualSignals.dtr },
                        set: { onManualSignalsChange(ModemSignals(dtr: $0, rts: manualSignals.rts)) }
                    ))
                    .disabled(!isConnected)
                    Toggle("RTS", isOn: Binding(
                        get: { manualSignals.rts },
                        set: { onManualSignalsChange(ModemSignals(dtr: manualSignals.dtr, rts: $0)) }
                    ))
                    .disabled(!isConnected)
                    if !isConnected {
                        Text("Connect first to control DTR/RTS manually.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Signal Status") {
                signalRow("CTS", on: liveSignals?.cts ?? false)
                signalRow("DSR", on: liveSignals?.dsr ?? false)
                signalRow("DCD", on: liveSignals?.dcd ?? false)
                if liveSignals == nil {
                    Text("Signals are only reported while connected.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Environment") {
                Picker("Environment", selection: $environment) {
                    Text("Lab").tag(SerialProfile.Environment.lab)
                    Text("Production").tag(SerialProfile.Environment.production)
                }
                .pickerStyle(.segmented)
                if environment == .production {
                    Text("A persistent PRODUCTION banner will show in the console — this is a labeling aid only, not an access control.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section("Terminal") {
                Picker("Line Ending on Send", selection: $lineEnding) {
                    ForEach(LineEnding.allCases) { ending in
                        Text(ending.label).tag(ending)
                    }
                }
                Toggle("Local Echo", isOn: $localEcho)
                    .help("Show what you type in the console, in addition to sending it to the device.")
                Picker("Terminal Type", selection: $terminalType) {
                    ForEach(TerminalTypeKind.allCases) { Text($0.label).tag($0) }
                }
                Picker("Encoding", selection: $encoding) {
                    Text("UTF-8").tag(TextEncodingKind.utf8)
                    Text("ASCII").tag(TextEncodingKind.ascii)
                    Text("Latin-1").tag(TextEncodingKind.latin1)
                }
                Stepper("Scrollback: \(scrollback) lines", value: $scrollback, in: 100...10_000, step: 100)
                Text("Terminal type, encoding, and scrollback take effect on the next connect.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Capture") {
                Picker("Format", selection: $captureFormat) {
                    Text("Plain Text").tag(CaptureFormat.plainText)
                    Text("JSONL (timestamped)").tag(CaptureFormat.jsonl)
                    Text("Binary (raw)").tag(CaptureFormat.binaryRaw)
                }
                Toggle("Redact Sensitive Patterns", isOn: $redactSensitiveData)
                    .help("Masks recognizable secrets (passwords, API keys, bearer tokens, private key blocks) before they're written to a capture file.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 620)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
    }

    private func signalRow(_ label: String, on: Bool) -> some View {
        HStack {
            Circle()
                .fill(on ? Color.green : Color.gray.opacity(0.3))
                .frame(width: 10, height: 10)
            Text(label)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(label) \(on ? "active" : "inactive")"))
    }
}

/// Line ending applied when sending typed text — CoolTerm calls this
/// "Enter key emulation."
enum LineEnding: String, CaseIterable, Identifiable {
    case none, cr, lf, crlf

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "None"
        case .cr: return "CR"
        case .lf: return "LF"
        case .crlf: return "CRLF"
        }
    }

    var bytes: String {
        switch self {
        case .none: return ""
        case .cr: return "\r"
        case .lf: return "\n"
        case .crlf: return "\r\n"
        }
    }
}
