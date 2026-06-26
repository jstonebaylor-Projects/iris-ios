// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "IrisKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "IrisKit",
            targets: ["IrisKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-testing.git", branch: "release/6.2")
    ],
    targets: [
        .target(
            name: "IrisKit",
            dependencies: []),
        .testTarget(
            name: "IrisKitTests",
            dependencies: [
                "IrisKit",
                .product(name: "Testing", package: "swift-testing")
            ])
    ]
)
