// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-memory",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
    ],
    products: [
        .library(
            name: "Memory",
            targets: ["Memory"]
        ),
    ],
    dependencies: [
        .package(path: "../swift-kernel"),
    ],
    targets: [
        .target(
            name: "Memory",
            dependencies: [
                .product(name: "Kernel", package: "swift-kernel"),
            ]
        ),
        .testTarget(
            name: "Memory Tests",
            dependencies: [
                "Memory",
            ]
        ),
    ]
)

for target in package.targets where ![.system, .binary, .plugin].contains(target.type) {
    let settings: [SwiftSetting] = [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility")
    ]
    target.swiftSettings = (target.swiftSettings ?? []) + settings
}
