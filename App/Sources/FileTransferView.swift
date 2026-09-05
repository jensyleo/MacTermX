import SwiftUI
import UniformTypeIdentifiers

struct FileTransferView: View {
    @ObservedObject var viewModel: FileTransferViewModel
    @State private var protocolKind: TransferProtocolKind = .zmodem
    @State private var showingFilePicker = false
    @State private var showingDirectoryPicker = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Protocol") {
                Picker("Protocol", selection: $protocolKind) {
                    ForEach(TransferProtocolKind.allCases) { Text($0.rawValue).tag($0) }
                }
                .disabled(viewModel.isBusy)
                if protocolKind == .zmodem {
                    Text("ZMODEM here is a simplified stop-and-wait implementation — reliable, but not the real protocol's streaming/resume behavior. Verified only against a synthetic loopback, not real hardware/lrzsz yet.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section("Action") {
                Button("Send File…") { showingFilePicker = true }
                    .disabled(viewModel.isBusy)
                Button("Receive File…") { showingDirectoryPicker = true }
                    .disabled(viewModel.isBusy)
            }

            Section("Status") {
                statusView
                if viewModel.isBusy {
                    Button("Cancel", role: .destructive) { viewModel.cancel() }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 340)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .fileImporter(isPresented: $showingFilePicker, allowedContentTypes: [.data]) { result in
            if case .success(let url) = result {
                viewModel.sendFile(at: url, protocolKind: protocolKind)
            }
        }
        .fileImporter(isPresented: $showingDirectoryPicker, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result {
                viewModel.receiveFile(protocolKind: protocolKind, to: url)
            }
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch viewModel.phase {
        case .idle:
            Text("Idle").foregroundStyle(.secondary)
        case .sending(let name):
            HStack {
                ProgressView().controlSize(.small)
                Text("Sending \(name)…")
            }
        case .receiving:
            HStack {
                ProgressView().controlSize(.small)
                Text("Waiting for sender…")
            }
        case .succeeded(let message):
            Label(message, systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed(let message):
            Label(message, systemImage: "xmark.circle.fill").foregroundStyle(.red)
        }
    }
}
