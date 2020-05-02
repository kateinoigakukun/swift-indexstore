// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "SwiftIndexStore",
    products: [
        .library(
            name: "SwiftIndexStore",
            targets: ["SwiftIndexStore"]),
    ],
    dependencies: [],
    targets: [
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
