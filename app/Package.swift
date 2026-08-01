// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "StickyCast",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.0")
    ],
    targets: [
        // Pure logic library. Tests @testable import only this target.
        // Importing the executable target (top-level code in main.swift) directly tends to break swift test.
        .target(
            name: "StickyCastCore",
            path: "Sources/StickyCastCore"
        ),
        .executableTarget(
            name: "StickyCast",
            dependencies: [
                "StickyCastCore",
                .product(name: "MarkdownUI", package: "swift-markdown-ui")
            ],
            path: "Sources/StickyCast"
        ),
        .testTarget(
            name: "StickyCastTests",
            dependencies: ["StickyCastCore"],
            path: "Tests/StickyCastTests"
        )
    ]
)
