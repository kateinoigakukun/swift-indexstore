// swift-tools-version:5.8

import PackageDescription

let package = Package(
    name: "SwiftIndexStore",
    platforms: [.macOS(.v13)],
    products: [
        .library(
            name: "SwiftIndexStore",
            targets: ["SwiftIndexStore"]),
        .executable(
            name: "index-dump-tool",
            targets: ["IndexDumpTool"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMajor(from: "1.0.0")),
    ],
    targets: [
        .executableTarget(
            name: "IndexDumpTool",
            dependencies: [
                .target(name: "SwiftIndexStore"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]),
        .target(
            name: "SwiftIndexStore",
            dependencies: [
                .target(name: "_CIndexStore"),
            ]),
        .target(
            name: "_CIndexStore",
            dependencies: []),
        .testTarget(
            name: "SwiftIndexStoreTests",
            dependencies: ["SwiftIndexStore"]),
    ]
)
