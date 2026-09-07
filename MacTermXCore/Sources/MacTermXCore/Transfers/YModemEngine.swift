import Foundation

/// YMODEM batch file transfer, built on top of `XModemEngine`'s block
/// engine: each file is preceded by a "block 0" header (null-terminated
/// filename, a space, then the decimal file size), sent as an ordinary
/// XMODEM/XMODEM-1K block. A header with an empty filename ends the batch.
public enum YModemEngine {
    public struct FilePayload: Sendable {
        public var name: String
        public var data: Data

        public init(name: String, data: Data) {
            self.name = name
            self.data = data
        }
    }

    /// Sends one or more files as a YMODEM batch: header block, file
    /// contents (via `XModemEngine.send`, starting the block numbering
    /// over at 1 for each file's data), repeated per file, then a final
    /// empty header block to close the batch.
    public static func send(
        _ files: [FilePayload],
        options: XModemEngine.Options = .init(use1K: true),
        channel: TransferByteChannel,
        write: @escaping @Sendable ([UInt8]) async throws -> Void
    ) async throws {
        for file in files {
            try await sendHeaderBlock(name: file.name, size: file.data.count, options: options, channel: channel, write: write)
            try await XModemEngine.send(file.data, options: options, channel: channel, write: write)
        }
        try await sendHeaderBlock(name: "", size: 0, options: options, channel: channel, write: write)
    }

    /// Receives a YMODEM batch. Calls `onFileStart` once a header block
    /// names the next file (with its declared size, sanitized — see
    /// `sanitizeFilename`, since it comes from an untrusted device), then
    /// `XModemEngine.receive`s its contents, repeating until an empty
    /// header block ends the batch.
    public static func receive(
        options: XModemEngine.Options = .init(use1K: true),
        channel: TransferByteChannel,
        write: @escaping @Sendable ([UInt8]) async throws -> Void,
        onFileStart: @escaping @Sendable (String, Int) -> Void = { _, _ in }
    ) async throws -> [FilePayload] {
        var files: [FilePayload] = []
        var totalBytes = 0
        while let (name, size) = try await receiveHeaderBlock(options: options, channel: channel, write: write) {
            onFileStart(name, size)
            var data = try await XModemEngine.receive(options: options, channel: channel, write: write)
            if size > 0, size < data.count {
                data = data.prefix(size)
            }
            totalBytes += data.count
            guard totalBytes <= TransferLimits.maxReceiveBytes else { throw TransferError.payloadTooLarge }
            files.append(FilePayload(name: name, data: data))
        }
        return files
    }

    /// Strips path separators and traversal segments from a YMODEM
    /// filename, keeping only the final path component. YMODEM filenames
    /// come from the sending device — never trust them as a safe path.
    public static func sanitizeFilename(_ name: String) -> String {
        let lastComponent = name.split(separator: "/").last.map(String.init) ?? name
        return lastComponent.isEmpty || lastComponent == "." || lastComponent == ".." ? "unnamed" : lastComponent
    }

    private static func sendHeaderBlock(
        name: String,
        size: Int,
        options: XModemEngine.Options,
        channel: TransferByteChannel,
        write: @escaping @Sendable ([UInt8]) async throws -> Void
    ) async throws {
        let useCRC = try await withStartByte(channel: channel, timeout: options.blockTimeout)
        var payload: [UInt8] = []
        if !name.isEmpty {
            payload += Array(name.utf8)
            payload.append(0)
            payload += Array(String(size).utf8)
        }
        let blockSize = options.use1K ? XModemFraming.blockSize1K : XModemFraming.blockSize
        let block = XModemFraming.makeBlock(number: 0, payload: payload, useCRC: useCRC, size: blockSize)
        try await sendBlockWithRetries(block, options: options, channel: channel, write: write)
    }

    /// Returns `(sanitizedName, declaredSize)` for the next file, or `nil`
    /// once the sender closes the batch with an empty header block.
    private static func receiveHeaderBlock(
        options: XModemEngine.Options,
        channel: TransferByteChannel,
        write: @escaping @Sendable ([UInt8]) async throws -> Void
    ) async throws -> (String, Int)? {
        var useCRC = options.useCRC
        try await write([useCRC ? XModemFraming.Control.crcMode : XModemFraming.Control.nak])

        while true {
            let header: UInt8
            do {
                header = try await channel.readByte(timeout: options.blockTimeout)
            } catch {
                if useCRC {
                    useCRC = false
                    try await write([XModemFraming.Control.nak])
                    continue
                }
                throw error
            }
            guard let size = XModemFraming.blockSize(forHeader: header) else { continue }

            let trailerSize = useCRC ? 2 : 1
            var frame: [UInt8] = [header]
            for _ in 0..<(2 + size + trailerSize) {
                frame.append(try await channel.readByte(timeout: options.blockTimeout))
            }
            guard let payload = XModemFraming.validateBlock(frame, expectedNumber: 0, useCRC: useCRC) else {
                try await write([XModemFraming.Control.nak])
                continue
            }
            try await write([XModemFraming.Control.ack])

            guard let nullIndex = payload.firstIndex(of: 0), nullIndex > 0 else {
                return nil // empty header block: end of batch
            }
            let name = sanitizeFilename(String(decoding: payload[..<nullIndex], as: UTF8.self))
            let sizeField = payload[(nullIndex + 1)...].prefix { $0 >= 0x30 && $0 <= 0x39 }
            let declaredSize = Int(String(decoding: sizeField, as: UTF8.self)) ?? 0
            return (name, declaredSize)
        }
    }

    private static func withStartByte(channel: TransferByteChannel, timeout: Duration) async throws -> Bool {
        let byte = try await channel.readByte(timeout: timeout)
        return byte == XModemFraming.Control.crcMode
    }

    private static func sendBlockWithRetries(
        _ block: [UInt8],
        options: XModemEngine.Options,
        channel: TransferByteChannel,
        write: @escaping @Sendable ([UInt8]) async throws -> Void
    ) async throws {
        var attempt = 0
        while true {
            try await write(block)
            let response = try await channel.readByte(timeout: options.blockTimeout)
            if response == XModemFraming.Control.ack { return }
            if response == XModemFraming.Control.can { throw TransferError.peerCancelled }
            attempt += 1
            if attempt >= options.maxRetries { throw TransferError.tooManyRetries }
        }
    }
}
