// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "SwiftIndexStore",
    products: [
        .library(
            name: "SwiftIndexStore",
            targets: ["SwiftIndexStore"]),
        .executable(
            name: "index-dump-tool",
            targets: ["IndexDumpTool"]),
    ],
    dependencies: [
        .package(name: "swift-argument-parser", url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "0.4.0")),
    ],
    targets: [
        .target(
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
