// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "IridescenceInstaller",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "IridescenceCore",
            targets: ["IridescenceCore"]
        ),
        .executable(
            name: "IridescenceInstaller",
            targets: ["IridescenceInstaller"]
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
            name: "IridescenceInstaller",
            dependencies: ["IridescenceCore"],
            path: "Sources/IridescenceInstaller"
        ),
        .testTarget(
            name: "IridescenceCoreTests",
            dependencies: ["IridescenceCore"],
            path: "Tests/IridescenceCoreTests"
        )
    ]
)
