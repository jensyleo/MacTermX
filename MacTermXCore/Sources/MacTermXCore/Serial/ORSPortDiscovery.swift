import Foundation
import IOKit
import IOKit.usb
import ORSSerial

/// `PortDiscovering` backed by `ORSSerialPortManager`, which enumerates
/// `/dev/cu.*` and posts KVO notifications on hot-plug.
public final class ORSPortDiscovery: NSObject, PortDiscovering, @unchecked Sendable {
    private let continuation: AsyncStream<PortChange>.Continuation
    public let changes: AsyncStream<PortChange>
    private var observation: NSKeyValueObservation?

    public override init() {
        var continuation: AsyncStream<PortChange>.Continuation!
        self.changes = AsyncStream { continuation = $0 }
        self.continuation = continuation
        super.init()
        observation = ORSSerialPortManager.shared().observe(\.availablePorts) { [weak self] manager, _ in
            guard let self else { return }
            for port in manager.availablePorts {
                self.continuation.yield(.connected(port.asSerialDevice))
            }
        }
    }

    public func availablePorts() async throws -> [SerialDevice] {
        ORSSerialPortManager.shared().availablePorts.map { $0.asSerialDevice }
    }
}

private extension ORSSerialPort {
    var asSerialDevice: SerialDevice {
        let usb = ioKitDevice.usbMetadata
        return SerialDevice(
            path: path,
            name: name,
            vendorId: usb.vendorId,
            productId: usb.productId,
            serialNumber: usb.serialNumber
        )
    }
}

private extension io_object_t {
    /// Walks up the IOKit registry from the serial device (a
    /// IOSerialBSDClient/IOUSBHostSerial node) to find the enclosing USB
    /// device node, and reads its vendor/product IDs and serial number —
    /// none of which ORSSerialPort itself exposes.
    var usbMetadata: (vendorId: String?, productId: String?, serialNumber: String?) {
        guard self != 0 else { return (nil, nil, nil) }

        func property(_ key: String, on entry: io_object_t) -> CFTypeRef? {
            IORegistryEntrySearchCFProperty(
                entry,
                kIOServicePlane,
                key as CFString,
                kCFAllocatorDefault,
                IOOptionBits(kIORegistryIterateRecursively | kIORegistryIterateParents)
            )
        }

        let vendorId = (property("idVendor", on: self) as? NSNumber).map { "0x\(String($0.intValue, radix: 16))" }
        let productId = (property("idProduct", on: self) as? NSNumber).map { "0x\(String($0.intValue, radix: 16))" }
        let serialNumber = property("USB Serial Number", on: self) as? String

        return (vendorId, productId, serialNumber)
    }
}
