// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MetroGuty",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MetroGuty",
            path: "Sources/MetroGuty"
        )
    ]
)
