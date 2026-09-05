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
    ],
    targets: [
        .target(
            name: "MacTermXCore",
            dependencies: [.product(name: "ORSSerial", package: "ORSSerialPort")]
        ),
        .testTarget(name: "MacTermXCoreTests", dependencies: ["MacTermXCore"]),
    ]
)
