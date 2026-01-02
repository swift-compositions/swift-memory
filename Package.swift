// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-mmap",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
    ],
    products: [
        .library(
            name: "MMap",
            targets: ["MMap"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/coenttb/swift-kernel.git", from: "0.2.5"),
    ],
    targets: [
        .target(
            name: "MMap",
            dependencies: [
                .product(name: "Kernel", package: "swift-kernel"),
            ]
        ),
        .testTarget(
            name: "MMap Tests",
            dependencies: [
                "MMap",
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
