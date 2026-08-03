// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QuietOverlay",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "QuietOverlay", targets: ["QuietOverlay"])
    ],
    targets: [
        .target(name: "QuietOverlay"),
        .executableTarget(name: "QuietOverlayDemo", dependencies: ["QuietOverlay"]),
        .testTarget(name: "QuietOverlayTests", dependencies: ["QuietOverlay"])
    ]
)
