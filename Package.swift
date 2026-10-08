// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Gaveta",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "GavetaCore", targets: ["GavetaCore"]),
        .executable(name: "gaveta", targets: ["GavetaCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.11.0"),
    ],
    targets: [
        .target(name: "GavetaCore"),
        .target(
            name: "GavetaMCP",
            dependencies: [
                "GavetaCore",
                .product(name: "MCP", package: "swift-sdk"),
            ]
        ),
        .executableTarget(
            name: "GavetaCLI",
            dependencies: [
                "GavetaCore",
                "GavetaMCP",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .executableTarget(name: "GavetaApp", dependencies: ["GavetaCore"]),
        .testTarget(name: "GavetaCoreTests", dependencies: ["GavetaCore"]),
        .testTarget(name: "GavetaAppTests", dependencies: ["GavetaApp", "GavetaCore"]),
        .testTarget(name: "GavetaMCPTests", dependencies: ["GavetaMCP", "GavetaCore"]),
    ]
)
