// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "proxlock-ios",
    platforms: [.iOS(.v13), .macOS(.v10_15), .watchOS(.v6), .visionOS(.v1), .tvOS(.v13)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "proxlock-ios",
            targets: ["proxlock-ios"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "proxlock-ios"
        ),
    ]
)
