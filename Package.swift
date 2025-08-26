// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Kukulcan",
    platforms: [
        .macOS(.v13),
        .iOS(.v17)
    ],
    products: [
        .library(name: "Kukulcan", targets: ["Kukulcan"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.9.0")
    ],
    targets: [
        .target(
            name: "Kukulcan",
            path: "Kukulcan",
            sources: ["Placeholder.swift"]
        ),
        .testTarget(
            name: "KukulcanTests",
            dependencies: [
                "Kukulcan",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "KukulcanTests"
        )
    ]
)
