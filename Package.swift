// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TimerApp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "TimerApp",
            targets: ["TimerApp"]
        )
    ],
    targets: [
        .executableTarget(
            name: "TimerApp",
            path: "Sources/TimerApp"
        )
    ]
)
