// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "SwiftSemantics",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "SwiftSemantics",
            targets: [
                "SwiftSemantics",
            ]
        ),
        .executable(
            name: "semtest",
            targets: [
                "SwiftSemanticsTestFlows",
            ]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/leviouwendijk/Executable.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/TestFlows.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/swiftlang/swift-syntax.git",
            from: "603.0.1"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Position.git",
            branch: "master"
        ),
    ],
    targets: [
        .target(
            name: "SwiftSemantics",
            dependencies: [
                .product(
                    name: "Executable",
                    package: "Executable"
                ),
                .product(
                    name: "SwiftParser",
                    package: "swift-syntax"
                ),
                .product(
                    name: "SwiftSyntax",
                    package: "swift-syntax"
                ),
                .product(
                    name: "Position",
                    package: "Position"
                ),
            ]
        ),
        .executableTarget(
            name: "SwiftSemanticsTestFlows",
            dependencies: [
                "SwiftSemantics",
                .product(
                    name: "TestFlows",
                    package: "TestFlows"
                ),
            ]
        ),
    ],
    swiftLanguageModes: [
        .v6,
    ]
)
