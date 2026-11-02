// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Deckloom",
    platforms: [.iOS(.v17), .macOS(.v14), .visionOS(.v1)],
    products: [.library(name: "Deckloom", targets: ["Deckloom"])],
    targets: [
        .target(name: "Deckloom"),
        .testTarget(name: "DeckloomTests", dependencies: ["Deckloom"])
    ]
)
