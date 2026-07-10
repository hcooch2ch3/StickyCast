// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "StickyCast",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.0")
    ],
    targets: [
        // 순수 로직 라이브러리 — 테스트는 이 타깃만 @testable import.
        // 실행 타깃(main.swift의 top-level 코드)을 직접 import하면 swift test가 깨지기 쉽다.
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
