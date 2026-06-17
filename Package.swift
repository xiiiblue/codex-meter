// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "codex-meter",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CodexMeter", targets: ["CodexMeter"])
    ],
    targets: [
        .executableTarget(
            name: "CodexMeter",
            path: "Sources/CodexMeter",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
