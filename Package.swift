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
    targets: [
        .target(name: "MontaMacCore"),
        .executableTarget(name: "MontaMac", dependencies: ["MontaMacCore"], resources: [.process("Resources")]),
        .testTarget(name: "MontaMacCoreTests", dependencies: ["MontaMacCore"]),
    ]
)
