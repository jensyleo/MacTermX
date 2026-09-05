import MacTermXCore
import SwiftUI

struct TerminalConsoleView: View {
    @StateObject var viewModel: ConnectionViewModel
    @State private var input = ""
    @State private var appendCRLF = true
    @State private var baudRate = 115_200

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                Text(viewModel.lines.joined(separator: "\n"))
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .textSelection(.enabled)
            }
            .background(Color.black)
            .foregroundStyle(.green)

            Divider()

            HStack {
                TextField("Send text or command…", text: $input)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(send)
                Toggle("CRLF", isOn: $appendCRLF)
                    .toggleStyle(.checkbox)
                Button("Send", action: send)
                    .disabled(viewModel.state != .connected)
            }
            .padding(8)

            Divider()

            HStack {
                statusLabel
                Spacer()
                if let error = viewModel.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Spacer()
                Picker("Baud", selection: $baudRate) {
                    ForEach([9600, 19200, 38400, 57600, 115_200], id: \.self) { rate in
                        Text("\(rate)").tag(rate)
                    }
                }
                .frame(width: 140)
                connectButton
            }
            .padding(8)
        }
        .navigationTitle(viewModel.device.name)
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
    private var connectButton: some View {
        if viewModel.state == .connected || viewModel.state == .opening {
            Button("Disconnect") { Task { await viewModel.disconnect() } }
        } else {
            Button("Connect") { Task { await viewModel.connect(baudRate: baudRate) } }
        }
    }

    private func send() {
        guard !input.isEmpty else { return }
        let text = input
        input = ""
        Task { await viewModel.send(text, appendCRLF: appendCRLF) }
    }
}
