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
        .executable(
            name: "semrules",
            targets: [
                "SwiftSemanticRuleCatalogGenerator",
            ]
        ),
        .executable(
            name: "semlint",
            targets: [
                "SwiftSemanticLintCLI",
            ]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/leviouwendijk/Executable.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Processes.git",
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
        .package(
            url: "https://github.com/leviouwendijk/Primitives.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Macros.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Arguments.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/ANSI.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Path.git",
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
                    name: "Processes",
                    package: "Processes"
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
                .product(
                    name: "Primitives",
                    package: "Primitives"
                ),
                .product(
                    name: "Macros",
                    package: "Macros"
                ),
            ]
        ),
        .executableTarget(
            name: "SwiftSemanticRuleCatalogGenerator",
            dependencies: [
                .product(
                    name: "Arguments",
                    package: "Arguments"
                ),
                .product(
                    name: "SwiftParser",
                    package: "swift-syntax"
                ),
                .product(
                    name: "SwiftSyntax",
                    package: "swift-syntax"
                ),
            ]
        ),
        .target(
            name: "SwiftSemanticLintPresentation",
            dependencies: [
                "SwiftSemantics",
                .product(
                    name: "ANSI",
                    package: "ANSI"
                ),
            ]
        ),
        .executableTarget(
            name: "SwiftSemanticLintCLI",
            dependencies: [
                "SwiftSemantics",
                "SwiftSemanticLintPresentation",
                .product(
                    name: "Arguments",
                    package: "Arguments"
                ),
                .product(
                    name: "Path",
                    package: "Path"
                ),
                .product(
                    name: "PathParsing",
                    package: "Path"
                ),
            ]
        ),
        .executableTarget(
            name: "SwiftSemanticsTestFlows",
            dependencies: [
                "SwiftSemantics",
                "SwiftSemanticLintPresentation",
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
