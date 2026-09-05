// swift-tools-version: 6.0
//
// MacTermX — a native serial terminal for macOS.
// Copyright (C) 2026 Jensy Leonardo Martínez Cruz
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// Dependencies below (ORSSerialPort, SwiftTerm) are MIT-licensed — see
// NOTICE.md for why, and for the plan to replace them with GPL-native
// code if that ever becomes realistic.

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
