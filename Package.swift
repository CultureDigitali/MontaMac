// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MontaMac",
    defaultLocalization: "en",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "MontaMacCore", targets: ["MontaMacCore"]),
        .executable(name: "MontaMac", targets: ["MontaMac"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.2"),
    ],
    targets: [
        .target(name: "MontaMacCore"),
        .executableTarget(
            name: "MontaMac",
            dependencies: ["MontaMacCore", .product(name: "Sparkle", package: "Sparkle")],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "MontaMacCoreTests", dependencies: ["MontaMacCore"]),
    ]
)
