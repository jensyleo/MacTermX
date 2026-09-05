import MacTermXCore
import SwiftUI

struct TerminalConsoleView: View {
    @StateObject var viewModel: ConnectionViewModel
    @State private var input = ""
    @State private var showingSettings = false
    @State private var viewMode: ConsoleViewMode = .text
    @State private var showingCaptureSavePanel = false

    var body: some View {
        VStack(spacing: 0) {
            Picker("View", selection: $viewMode) {
                Text("Text").tag(ConsoleViewMode.text)
                Text("Hex").tag(ConsoleViewMode.hex)
            }
            .pickerStyle(.segmented)
            .padding(8)

            ScrollView {
                Text(viewMode == .text ? viewModel.lines.joined(separator: "\n") : viewModel.hexDump)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .textSelection(.enabled)
            }
            .background(Color.black)
            .foregroundStyle(.green)

            Divider()

            HStack {
                TextField(viewModel.sendAsHex ? "Send hex, e.g. 41 0D 0A…" : "Send text or command…", text: $input)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(send)
                Toggle("Hex", isOn: $viewModel.sendAsHex)
                    .toggleStyle(.checkbox)
                Button("Send", action: send)
                    .disabled(viewModel.state != .connected)
            }
            .padding(8)

            Divider()

            HStack {
                statusLabel
                signalIndicators
                Spacer()
                if let error = viewModel.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Spacer()
                captureButton
                connectButton
            }
            .padding(8)
        }
        .navigationTitle(viewModel.device.name)
        .toolbar {
            ToolbarItem {
                Button("Settings", systemImage: "gearshape") {
                    showingSettings = true
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            PortSettingsView(
                configuration: $viewModel.configuration,
                lineEnding: $viewModel.lineEnding,
                localEcho: $viewModel.localEcho,
                liveSignals: viewModel.liveSignals,
                manualSignals: viewModel.manualSignals,
                onManualSignalsChange: { viewModel.setManualSignals($0) },
                isConnected: viewModel.state == .connected
            )
        }
        .fileExporter(
            isPresented: $showingCaptureSavePanel,
            document: CaptureFilePlaceholder(),
            contentType: .plainText,
            defaultFilename: "\(viewModel.device.name)-capture.txt"
        ) { result in
            if case .success(let url) = result {
                viewModel.startCapture(to: url)
            }
        }
    }

    @ViewBuilder
    private var signalIndicators: some View {
        if let signals = viewModel.liveSignals {
            HStack(spacing: 6) {
                signalDot("CTS", on: signals.cts)
                signalDot("DSR", on: signals.dsr)
                signalDot("DCD", on: signals.dcd)
            }
            .padding(.leading, 8)
        }
    }

    private func signalDot(_ label: String, on: Bool) -> some View {
        HStack(spacing: 2) {
            Circle().fill(on ? Color.green : Color.gray.opacity(0.3)).frame(width: 6, height: 6)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch viewModel.state {
        case .disconnected:
            Label("Disconnected", systemImage: "circle")
                .foregroundStyle(.secondary)
        case .opening:
            Label("Connecting…", systemImage: "circle.dotted")
                .foregroundStyle(.orange)
        case .connected:
            Label("Connected", systemImage: "circle.fill")
                .foregroundStyle(.green)
        case .transferring:
            Label("Transferring…", systemImage: "arrow.up.arrow.down.circle")
                .foregroundStyle(.blue)
        case .closing:
            Label("Closing…", systemImage: "circle.dotted")
                .foregroundStyle(.orange)
        case .failed(let message):
            Label("Failed: \(message)", systemImage: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var captureButton: some View {
        if viewModel.isCapturing {
            Button("Stop Capture", systemImage: "record.circle.fill") {
                viewModel.stopCapture()
            }
            .foregroundStyle(.red)
        } else {
            Button("Capture to File…", systemImage: "record.circle") {
                showingCaptureSavePanel = true
            }
        }
    }

    @ViewBuilder
    private var connectButton: some View {
        if viewModel.state == .connected || viewModel.state == .opening {
            Button("Disconnect") { Task { await viewModel.disconnect() } }
        } else {
            Button("Connect") { Task { await viewModel.connect() } }
        }
    }

    private func send() {
        guard !input.isEmpty else { return }
        let text = input
        input = ""
        Task { await viewModel.send(text) }
    }
}
