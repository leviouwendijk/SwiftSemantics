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
    ],
    targets: [
        .target(
            name: "SwiftSemantics",
            dependencies: [
                .product(
                    name: "Executable",
                    package: "Executable"
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
