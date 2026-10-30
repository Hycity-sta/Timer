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
            exclude: [
                "Resources/Info.plist",
                "Resources/zh-Hans.lproj",
                "Resources/zh_CN.lproj"
            ],
            resources: [
                .process("Resources/AppIcon.icns")
            ],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]
        )
    ]
)
