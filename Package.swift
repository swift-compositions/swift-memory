// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "swift-memory",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27),
    ],
    products: [
        .library(
            name: "Memory",
            targets: ["Memory"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/swift-foundations/swift-kernel.git", branch: "main"),
        .package(
            url: "https://github.com/swift-standards/swift-darwin-standard.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-linux-foundation/swift-linux-standard.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-primitives/swift-memory-primitives.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-primitives/swift-memory-allocation-primitives.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-primitives/swift-memory-lock-primitives.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-primitives/swift-memory-shared-primitives.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-primitives/swift-memory-map-primitives.git",
            branch: "main"
        ),
    ],
    targets: [
        .target(
            name: "Memory",
            dependencies: [
                .product(name: "Kernel", package: "swift-kernel"),
                .product(name: "Memory Primitives", package: "swift-memory-primitives"),
                .product(
                    name: "Memory Allocation Primitive",
                    package: "swift-memory-allocation-primitives"
                ),
                .product(name: "Memory Lock Primitives", package: "swift-memory-lock-primitives"),
                .product(
                    name: "Memory Shared Primitives",
                    package: "swift-memory-shared-primitives"
                ),
                .product(name: "Memory Map Primitives", package: "swift-memory-map-primitives"),
                .product(
                    name: "Darwin Memory Standard",
                    package: "swift-darwin-standard",
                    condition: .when(platforms: [.macOS, .iOS, .tvOS, .watchOS, .visionOS])
                ),
                .product(
                    name: "Linux Memory Standard",
                    package: "swift-linux-standard",
                    condition: .when(platforms: [.linux])
                ),
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
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("LifetimeDependence"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
