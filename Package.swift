// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PSVSwitcher",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "PSVSwitcher",
            path: "Sources/PSVSwitcher"
        )
    ]
)