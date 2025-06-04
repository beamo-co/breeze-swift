// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "breeze-iap-swift",
    platforms: [
        .iOS(.v15), // min IOS15
        .macOS(.v12)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "breeze-iap-swift",
            targets: ["breeze-iap-swift"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "breeze-iap-swift"),
        .testTarget(
            name: "breeze-iap-swiftTests",
            dependencies: ["breeze-iap-swift"]
        ),
    ]
)
