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
        .library(
            name: "SwiftRefactoring",
            targets: [
                "SwiftRefactoring",
            ]
        ),
        .executable(
            name: "t_semantics",
            targets: [
                "SwiftSemanticsAllTestCLI",
            ]
        ),
        .executable(
            name: "t_semantics_fast",
            targets: [
                "SwiftSemanticsFastTestCLI",
            ]
        ),
        .executable(
            name: "t_semantics_lsp",
            targets: [
                "SwiftSemanticsCompilerTestCLI",
            ]
        ),
        .executable(
            name: "t_semantics_rename",
            targets: [
                "SwiftSemanticsRenameTestCLI",
            ]
        ),
        .executable(
            name: "t_semantics_validate",
            targets: [
                "SwiftSemanticsValidateTestCLI",
            ]
        ),
        .library(
            name: "SwiftRefactoringWriters",
            targets: [
                "SwiftRefactoringWriters",
            ]
        ),
        .executable(
            name: "t_semantics_prepare",
            targets: [
                "SwiftSemanticsPrepareTestCLI",
            ]
        ),
        .executable(
            name: "t_semantics_publish",
            targets: [
                "SwiftSemanticsPublishTestCLI",
            ]
        ),
        .executable(
            name: "semrules",
            targets: [
                "SwiftSemanticRuleCatalogGenerator",
            ]
        ),
        .executable(
            name: "semlsp",
            targets: [
                "SwiftSemanticLintLSP",
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
            url: "https://github.com/leviouwendijk/Writers.git",
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
            url: "https://github.com/leviouwendijk/Difference.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Schema.git",
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
            url: "https://github.com/leviouwendijk/Excerpt.git",
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
                    name: "Schema",
                    package: "Schema"
                ),
                .product(
                    name: "Macros",
                    package: "Macros"
                ),
                .product(
                    name: "Excerpt",
                    package: "Excerpt"
                ),
            ]
        ),
        .target(
            name: "SwiftRefactoring",
            dependencies: [
                "SwiftSemantics",
                .product(
                    name: "SwiftSyntax",
                    package: "swift-syntax"
                ),
                .product(
                    name: "Processes",
                    package: "Processes"
                ),
            ]
        ),
        .target(
            name: "SwiftRefactoringWriters",
            dependencies: [
                "SwiftRefactoring",
                .product(
                    name: "Path",
                    package: "Path"
                ),
                .product(
                    name: "Writers",
                    package: "Writers"
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
                .product(
                    name: "ExcerptPresentation",
                    package: "Excerpt"
                ),
            ]
        ),
        .executableTarget(
            name: "SwiftSemanticLintLSP",
            dependencies: [
                "SwiftSemantics",
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
        .target(
            name: "SwiftSemanticsTestFlows",
            dependencies: [
                "SwiftSemantics",
                "SwiftRefactoring",
                "SwiftRefactoringWriters",
                "SwiftSemanticLintPresentation",
                .product(
                    name: "Writers",
                    package: "Writers"
                ),
                .product(
                    name: "Difference",
                    package: "Difference"
                ),
                .product(
                    name: "TestFlows",
                    package: "TestFlows"
                ),
            ]
        ),
        .executableTarget(
            name: "SwiftSemanticsAllTestCLI",
            dependencies: ["SwiftSemanticsTestFlows"]
        ),
        .executableTarget(
            name: "SwiftSemanticsFastTestCLI",
            dependencies: ["SwiftSemanticsTestFlows"]
        ),
        .executableTarget(
            name: "SwiftSemanticsCompilerTestCLI",
            dependencies: ["SwiftSemanticsTestFlows"]
        ),
        .executableTarget(
            name: "SwiftSemanticsRenameTestCLI",
            dependencies: ["SwiftSemanticsTestFlows"]
        ),
        .executableTarget(
            name: "SwiftSemanticsValidateTestCLI",
            dependencies: ["SwiftSemanticsTestFlows"]
        ),
        .executableTarget(
            name: "SwiftSemanticsPrepareTestCLI",
            dependencies: ["SwiftSemanticsTestFlows"]
        ),
        .executableTarget(
            name: "SwiftSemanticsPublishTestCLI",
            dependencies: ["SwiftSemanticsTestFlows"]
        ),
    ],
    swiftLanguageModes: [
        .v6,
    ]
)

for target in package.targets {
    switch target.type {
    case .regular, .executable, .test, .macro:
        var settings = target.swiftSettings ?? []

        settings.append(
            .treatAllWarnings(as: .error)
        )

        target.swiftSettings = settings

    case .plugin, .system, .binary:
        break

    @unknown default:
        break
    }
}
