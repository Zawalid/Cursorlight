// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Cursorlight",
    platforms: [.macOS("14.6")],
    products: [
        .library(name: "CursorlightCore", targets: ["CursorlightCore"])
    ],
    targets: [
        .target(name: "CursorlightCore"),
        .testTarget(name: "CursorlightCoreTests", dependencies: ["CursorlightCore"]),
    ]
)
