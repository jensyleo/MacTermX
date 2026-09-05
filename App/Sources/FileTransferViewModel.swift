import Foundation
import MacTermXCore

enum TransferProtocolKind: String, CaseIterable, Identifiable {
    case xmodemChecksum = "XMODEM (checksum)"
    case xmodemCRC = "XMODEM (CRC)"
    case xmodem1K = "XMODEM-1K"
    case ymodem = "YMODEM"
    case zmodem = "ZMODEM"
    var id: String { rawValue }
}

enum TransferPhase: Equatable {
    case idle
    case sending(fileName: String)
    case receiving
    case succeeded(String)
    case failed(String)
}

/// Drives a file transfer over the session's serial connection, switching
/// `SessionCoordinator` into transfer mode for its duration so incoming
/// bytes go to the protocol engine instead of the VT100 parser.
@MainActor
final class FileTransferViewModel: ObservableObject {
    @Published private(set) var phase: TransferPhase = .idle
    private weak var coordinator: SessionCoordinator?
    private var task: Task<Void, Never>?

    func attach(_ coordinator: SessionCoordinator) {
        self.coordinator = coordinator
    }

    var isBusy: Bool {
        switch phase {
        case .sending, .receiving: return true
        default: return false
        }
    }

    func cancel() {
        task?.cancel()
    }

    func sendFile(at url: URL, protocolKind: TransferProtocolKind) {
        guard let coordinator, !isBusy else { return }
        phase = .sending(fileName: url.lastPathComponent)
        task = Task {
            let channel = coordinator.beginTransfer()
            defer { coordinator.endTransfer() }
            let write: @Sendable (Data) async throws -> Void = { [weak coordinator] data in
                try await coordinator?.sendUserInput(data)
            }
            do {
                guard let data = try? Data(contentsOf: url) else {
                    throw CocoaError(.fileReadUnknown)
                }
                switch protocolKind {
                case .xmodemChecksum:
                    try await XModemEngine.send(data, options: .init(useCRC: false), channel: channel, write: xmodemWrite(write))
                case .xmodemCRC:
                    try await XModemEngine.send(data, channel: channel, write: xmodemWrite(write))
                case .xmodem1K:
                    try await XModemEngine.send(data, options: .init(use1K: true), channel: channel, write: xmodemWrite(write))
                case .ymodem:
                    try await YModemEngine.send([.init(name: url.lastPathComponent, data: data)], channel: channel, write: xmodemWrite(write))
                case .zmodem:
                    try await ZModemEngine.send(name: url.lastPathComponent, data: data, channel: channel, write: xmodemWrite(write))
                }
                phase = .succeeded("Sent \(url.lastPathComponent) (\(data.count) bytes)")
            } catch is CancellationError {
                phase = .failed("Cancelled")
            } catch {
                phase = .failed(String(describing: error))
            }
        }
    }

    func receiveFile(protocolKind: TransferProtocolKind, to directory: URL) {
        guard let coordinator, !isBusy else { return }
        phase = .receiving
        task = Task {
            let channel = coordinator.beginTransfer()
            defer { coordinator.endTransfer() }
            let write: @Sendable (Data) async throws -> Void = { [weak coordinator] data in
                try await coordinator?.sendUserInput(data)
            }
            do {
                switch protocolKind {
                case .xmodemChecksum, .xmodemCRC, .xmodem1K:
                    let data = try await XModemEngine.receive(channel: channel, write: xmodemWrite(write))
                    let url = directory.appendingPathComponent("received-\(Int(Date().timeIntervalSince1970)).bin")
                    try data.write(to: url)
                    phase = .succeeded("Received \(data.count) bytes → \(url.lastPathComponent)")
                case .ymodem:
                    let files = try await YModemEngine.receive(channel: channel, write: xmodemWrite(write))
                    for file in files {
                        try file.data.write(to: directory.appendingPathComponent(file.name))
                    }
                    phase = .succeeded("Received \(files.count) file(s) into \(directory.lastPathComponent)")
                case .zmodem:
                    let result = try await ZModemEngine.receive(channel: channel, write: xmodemWrite(write))
                    let url = directory.appendingPathComponent(result.name)
                    try result.data.write(to: url)
                    phase = .succeeded("Received \(result.name) (\(result.data.count) bytes)")
                }
            } catch is CancellationError {
                phase = .failed("Cancelled")
            } catch {
                phase = .failed(String(describing: error))
            }
        }
    }

    /// All three engines' `write` closures take `[UInt8]`; bridges to the
    /// `Data`-based closure this view model shares with `sendUserInput`.
    private func xmodemWrite(_ write: @escaping @Sendable (Data) async throws -> Void) -> @Sendable ([UInt8]) async throws -> Void {
        { bytes in try await write(Data(bytes)) }
    }
}
