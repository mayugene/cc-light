// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "cc-light",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "cc-light",
            path: "Sources"
        )
    ]
)
