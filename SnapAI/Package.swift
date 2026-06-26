// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SnapAI",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.0")
    ],
    targets: [
        .executableTarget(
            name: "SnapAI",
            dependencies: [
                .product(name: "MarkdownUI", package: "swift-markdown-ui")
            ]
        ),
        .testTarget(
            name: "SnapAITests",
            dependencies: ["SnapAI"]
        ),
    ]
)
