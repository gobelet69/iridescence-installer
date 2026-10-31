// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "IridescenceUpdater",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "IridescenceCore",
            targets: ["IridescenceCore"]
        ),
        .executable(
            name: "IridescenceUpdater",
            targets: ["IridescenceUpdater"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "IridescenceCore",
            dependencies: [],
            path: "Sources/IridescenceCore"
        ),
        .executableTarget(
            name: "IridescenceUpdater",
            dependencies: ["IridescenceCore"],
            path: "Sources/IridescenceUpdater"
        ),
        .testTarget(
            name: "IridescenceCoreTests",
            dependencies: ["IridescenceCore"],
            path: "Tests/IridescenceCoreTests"
        )
    ]
)
