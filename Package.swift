// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "IXAK",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "IXAK",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("SwiftUI")
            ]
        )
    ]
)
