// swift-tools-version: 6.3.3

import PackageDescription

let package = Package(
    name: "swift-memory",
    platforms: [
        .macOS("27"),
        .iOS("27"),
        .tvOS("27"),
        .watchOS("27"),
        .visionOS("27")
    ],
    products: [
        .library(
            name: "Memory",
            targets: ["Memory"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/swift-foundations/swift-kernel.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-memory-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-memory-lock-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-memory-shared-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-memory-map-primitives.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "Memory",
            dependencies: [
                .product(name: "Kernel", package: "swift-kernel"),
                .product(name: "Memory Primitives", package: "swift-memory-primitives"),
                .product(name: "Memory Lock Primitives", package: "swift-memory-lock-primitives"),
                .product(name: "Memory Shared Primitives", package: "swift-memory-shared-primitives"),
                .product(name: "Memory Map Primitives", package: "swift-memory-map-primitives"),
            ]
        ),
        .testTarget(
            name: "Memory Tests",
            dependencies: [
                "Memory",
                .product(name: "Kernel Test Support", package: "swift-kernel"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("LifetimeDependence"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
