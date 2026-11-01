// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SakuraSwitch",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        // Core logic: permissions, window enumeration, AX actions, MRU,
        // search, thumbnails, hotkeys, settings persistence, logging.
        .target(
            name: "SakuraSwitchCore",
            path: "Sources/SakuraSwitchCore"
        ),
        // Executable: SwiftUI/AppKit entry point only.
        .executableTarget(
            name: "SakuraSwitch",
            dependencies: ["SakuraSwitchCore"],
            path: "Sources/SakuraSwitch"
        ),
        // Tests cover the core library only, so no AppKit side effects.
        .testTarget(
            name: "SakuraSwitchCoreTests",
            dependencies: ["SakuraSwitchCore"],
            path: "Tests/SakuraSwitchCoreTests"
        )
    ]
)
