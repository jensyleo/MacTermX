import Foundation

/// Software (XON/XOFF) flow control, implemented at the byte-stream
/// level rather than through the OS driver — unlike RTS/CTS, XON/XOFF is
/// just two reserved control bytes travelling in the data itself, so it
/// needs no termios/driver support at all. This closes the gap noted in
/// `ORSSerialTransport`: ORSSerialPort exposes no software-flow-control
/// API, but that API was never actually necessary for this.
///
/// The device tells us to pause by sending XOFF (0x13) and to resume by
/// sending XON (0x11); both bytes are stripped from what reaches the
/// terminal parser. Outgoing writes are held (queued, in order) while
/// halted and flushed once XON arrives.
public actor XonXoffFlowController {
    private static let xon: UInt8 = 0x11
    private static let xoff: UInt8 = 0x13

    private var halted = false
    private var pendingWrites: [CheckedContinuation<Void, Never>] = []

    public init() {}

    public var isHalted: Bool { halted }

    /// Strips XON/XOFF control bytes from incoming data and updates the
    /// halted state. Returns the cleaned payload — pass this to the
    /// terminal parser / capture / hex view instead of the raw bytes.
    public func filterIncoming(_ data: Data) -> Data {
        var result = Data()
        result.reserveCapacity(data.count)
        for byte in data {
            switch byte {
            case Self.xoff:
                halted = true
            case Self.xon:
                halted = false
                flushPendingWrites()
            default:
                result.append(byte)
            }
        }
        return result
    }

    /// Waits until the flow isn't halted, then returns — call this
    /// before actually writing to the transport. Resolves immediately if
    /// not currently halted.
    public func waitUntilClearToSend() async {
        guard halted else { return }
        await withCheckedContinuation { continuation in
            pendingWrites.append(continuation)
        }
    }

    private func flushPendingWrites() {
        let writes = pendingWrites
        pendingWrites.removeAll()
        for continuation in writes {
            continuation.resume()
        }
    }
}
