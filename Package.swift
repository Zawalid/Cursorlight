// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Beacon",
    platforms: [.macOS("14.6")],
    products: [
        .library(name: "BeaconCore", targets: ["BeaconCore"])
    ],
    targets: [
        .target(name: "BeaconCore"),
        .testTarget(name: "BeaconCoreTests", dependencies: ["BeaconCore"]),
    ]
)
