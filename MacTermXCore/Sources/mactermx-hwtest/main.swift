import Foundation
import MacTermXCore

// A small CLI harness that drives MacTermX's *actual* production code
// (ORSPortDiscovery, ORSSerialTransport, SessionCoordinator) against real
// hardware. Usage: mactermx-hwtest [devicePath] [baudRate]
// Defaults to the first discovered port at 9600 baud if no path is given.

@MainActor
func run() async {
    print("=== MacTermX hardware test ===")

    let discovery = ORSPortDiscovery()
    let ports: [SerialDevice]
    do {
        ports = try await discovery.availablePorts()
    } catch {
        print("FAIL: availablePorts() threw \(error)")
        return
    }

    print("\n-- Port discovery --")
    if ports.isEmpty {
        print("No serial ports found.")
    }
    for port in ports {
        print("  \(port.path)  name=\(port.name)  vendor=\(port.vendorId ?? "?")  product=\(port.productId ?? "?")  serial=\(port.serialNumber ?? "?")")
    }

    let args = CommandLine.arguments
    let devicePath = args.count > 1 ? args[1] : ports.first(where: { $0.path.contains("usbserial") })?.path
    guard let devicePath else {
        print("\nNo usbserial device path given or discovered. Pass one explicitly, e.g.:")
        print("  swift run mactermx-hwtest /dev/cu.usbserial-AI046KOY")
        return
    }
    let baudRate = args.count > 2 ? Int(args[2]) ?? 9600 : 9600

    print("\n-- Opening \(devicePath) at \(baudRate) baud --")
    guard let transport = try? ORSSerialTransport(devicePath: devicePath) else {
        print("FAIL: could not construct ORSSerialTransport for \(devicePath)")
        return
    }

    var receivedBuffer = Data()
    var sawOpened = false
    var sawError: String?
    var lastSignals: (cts: Bool, dsr: Bool, dcd: Bool)?

    let readTask = Task {
        for await event in transport.events {
            switch event {
            case .opened:
                sawOpened = true
                print("  event: opened")
            case .closed:
                print("  event: closed")
            case .error(let message):
                sawError = message
                print("  event: error — \(message)")
            case .data(let data):
                receivedBuffer.append(data)
                print("  event: data (\(data.count) bytes) = \(HexDump.format(data))")
            case .signals(let cts, let dsr, let dcd, _):
                lastSignals = (cts, dsr, dcd)
                print("  event: signals cts=\(cts) dsr=\(dsr) dcd=\(dcd)")
            }
        }
    }

    do {
        try await transport.open(configuration: SerialConfiguration(baudRate: baudRate))
    } catch {
        print("FAIL: open(configuration:) threw \(error)")
        readTask.cancel()
        return
    }

    try? await Task.sleep(for: .milliseconds(300))
    print(sawOpened ? "PASS: received .opened event" : "FAIL: never received .opened event")

    print("\n-- Write test --")
    let marker = "MacTermX-HWTEST-\(Int(Date().timeIntervalSince1970))\r\n"
    do {
        try await transport.write(Data(marker.utf8))
        print("PASS: write(_:) did not throw — sent \(marker.count) bytes: \(marker.trimmingCharacters(in: .whitespacesAndNewlines))")
    } catch {
        print("FAIL: write(_:) threw \(error)")
    }

    try? await Task.sleep(for: .milliseconds(500))
    if receivedBuffer.isEmpty {
        print("INFO: nothing echoed back. Expected unless TX/RX are physically looped back, or a peer device is attached and listening.")
    } else if String(decoding: receivedBuffer, as: UTF8.self).contains(marker.trimmingCharacters(in: .whitespacesAndNewlines)) {
        print("PASS: loopback confirmed — sent marker was echoed back exactly.")
    } else {
        print("INFO: received \(receivedBuffer.count) bytes, but not our marker (probably a live peer device, not a loopback).")
    }

    print("\n-- Signal control test (DTR/RTS) --")
    do {
        try await transport.setSignals(ModemSignals(dtr: true, rts: true))
        try? await Task.sleep(for: .milliseconds(200))
        print("PASS: setSignals(dtr: true, rts: true) did not throw")
        if let lastSignals {
            print("  last observed signals after toggle: cts=\(lastSignals.cts) dsr=\(lastSignals.dsr) dcd=\(lastSignals.dcd)")
        } else {
            print("  INFO: no signal-change events observed (expected if CTS/DSR/DCD aren't wired on this cable)")
        }
        try await transport.setSignals(ModemSignals(dtr: false, rts: false))
    } catch {
        print("FAIL: setSignals(_:) threw \(error)")
    }

    print("\n-- Multiple baud rates --")
    for rate in [9600, 19200, 38400, 57600, 115_200] {
        do {
            try await transport.open(configuration: SerialConfiguration(baudRate: rate))
            print("PASS: reconfigured to \(rate) baud without throwing")
        } catch {
            print("FAIL: \(rate) baud threw \(error)")
        }
    }

    if let sawError {
        print("\nNOTE: a transport-level error event was observed during the run: \(sawError)")
    }

    await transport.close()
    try? await Task.sleep(for: .milliseconds(200))
    readTask.cancel()

    print("\n=== Done ===")
}

await run()
