// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "modo",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        // Core library — all logic, no CLI. Importable by tests.
        .target(
            name: "ModoCore",
            path: "Sources/ModoCore"
        ),
        // CLI executable — thin wrapper that calls into ModoCore.
        .executableTarget(
            name: "modo",
            dependencies: [
                "ModoCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/modo"
        ),
        // Tests
        .testTarget(
            name: "ModoTests",
            dependencies: ["ModoCore"],
            path: "Tests/ModoTests"
        ),
    ]
)
