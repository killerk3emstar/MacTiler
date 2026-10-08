// swift-tools-version: 6.0
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
        // Pure logic: snap states, transition table, geometry, animation math.
        // No AppKit, so everything here is unit-testable.
        .target(
            name: "MacTilerCore",
            path: "Sources/MacTilerCore"
        ),
        .executableTarget(
            name: "mactiler",
            dependencies: ["MacTilerCore", "KeyboardShortcuts"],
            path: "Sources/mactiler",
            exclude: ["App/Info.plist"]
        ),
        .testTarget(
            name: "MacTilerCoreTests",
            dependencies: ["MacTilerCore"],
            path: "Tests/MacTilerCoreTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
