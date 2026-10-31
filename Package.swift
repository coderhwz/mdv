// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MDV",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "MDV", targets: ["MDV"])],
    targets: [
        .executableTarget(name: "MDV"),
        .testTarget(name: "MDVTests", dependencies: ["MDV"])
    ]
)
