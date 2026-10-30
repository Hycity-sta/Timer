// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TimerApp",
    platforms: [
        .macOS(.v14)
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
            path: "Sources/TimerApp",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]
        )
    ]
)
