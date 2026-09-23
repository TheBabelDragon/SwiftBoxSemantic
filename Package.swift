// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SwiftBox",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "SwiftBoxSemantic", targets: ["SwiftBoxSemantic"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.0")
    ],
    targets: [
        .target(
            name: "SwiftBoxSemantic",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax")
            ]
        ),
        .testTarget(
            name: "SwiftBoxSemanticTests",
            dependencies: ["SwiftBoxSemantic"],
            resources: [.copy("Fixtures")]
        )
    ]
)
