// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "colored-sim",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "ColoredSimKit",
            path: "Sources/ColoredSimKit"
        ),
        .executableTarget(
            name: "colored-sim",
            dependencies: [
                "ColoredSimKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/ColoredSim"
        ),
        .executableTarget(
            name: "colored-sim-overlay",
            path: "Sources/Overlay"
        ),
        .executableTarget(
            name: "colored-sim-mcp",
            dependencies: [
                "ColoredSimKit",
            ],
            path: "Sources/MCP"
        ),
    ]
)
