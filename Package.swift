// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Pulse",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Pulse", targets: ["Pulse"])
    ],
    targets: [
        .executableTarget(
            name: "Pulse",
            path: "Pulse",
            exclude: [
                "Resources/Info.plist",
                "Resources/Assets.xcassets"
            ],
            resources: [
                .copy("Resources/AppIcon.icns"),
                .copy("Resources/PulseLogo.png")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("Metal"),
                .linkedFramework("UserNotifications"),
                .linkedLibrary("sqlite3")
            ]
        ),
        .testTarget(
            name: "PulseTests",
            dependencies: ["Pulse"],
            path: "Tests/PulseTests",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
