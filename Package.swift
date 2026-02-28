// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LearningDomainKit",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "LearningDomainKit",
            targets: ["LearningDomainKit"]
        )
    ],
    targets: [
        .target(
            name: "LearningDomainKit"
        ),
        .testTarget(
            name: "LearningDomainKitTests",
            dependencies: ["LearningDomainKit"]
        )
    ]
)
