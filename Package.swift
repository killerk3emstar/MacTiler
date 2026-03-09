// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "mactiler",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "mactiler",
            dependencies: ["KeyboardShortcuts"],
            path: "Sources/mactiler",
            exclude: ["App/Info.plist"]
        )
    ]
)
