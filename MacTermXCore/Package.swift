// swift-tools-version: 6.0
//
// MacTermX — a native serial terminal for macOS.

import PackageDescription

let package = Package(
    name: "MacTermXCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "MacTermXCore", targets: ["MacTermXCore"])
    ],
    dependencies: [
        // Serial I/O backend for SerialTransport. MIT license, macOS-native,
        // built on IOKit/BSD serial APIs with RTS/CTS/DTR control and
        // hot-plug detection. No maintained GPL alternative exists for
        // Swift/macOS (checked: libserialport is LGPL with no macOS-safe
        // Swift wrapper).
        .package(url: "https://github.com/armadsen/ORSSerialPort.git", from: "2.1.0"),
        // ANSI/VT terminal engine. MIT license, actively maintained, only
        // real option in the Swift ecosystem. We consume its headless
        // core (parser + screen buffer), not TerminalView, so MacTermX
        // owns SwiftUI rendering and can sanitize/limit raw serial bytes
        // before they reach the parser.
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.2.0"),
    ],
    targets: [
        .target(
            name: "MacTermXCore",
            dependencies: [
                .product(name: "ORSSerial", package: "ORSSerialPort"),
                .product(name: "SwiftTerm", package: "SwiftTerm"),
            ]
        ),
        .testTarget(name: "MacTermXCoreTests", dependencies: ["MacTermXCore"]),
    ]
)
