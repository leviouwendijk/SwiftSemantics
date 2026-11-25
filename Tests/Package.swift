// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "SwiftSemanticsTests",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "t_semantics", targets: ["SwiftSemanticsAllTestCLI"]),
        .executable(name: "t_semantics_fast", targets: ["SwiftSemanticsFastTestCLI"]),
        .executable(name: "t_semantics_lsp", targets: ["SwiftSemanticsCompilerTestCLI"]),
        .executable(name: "t_semantics_rename", targets: ["SwiftSemanticsRenameTestCLI"]),
        .executable(name: "t_semantics_validate", targets: ["SwiftSemanticsValidateTestCLI"]),
        .executable(name: "t_semantics_prepare", targets: ["SwiftSemanticsPrepareTestCLI"]),
        .executable(name: "t_semantics_publish", targets: ["SwiftSemanticsPublishTestCLI"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/swift-lco/Writers.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/swift-tooling/TestFlows.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/swift-lco/Difference.git",
            branch: "master"
        ),
        .package(path: ".."),
    ],
    targets: [
        .target(
            name: "SwiftSemanticsTestFlows",
            dependencies: [
                .product(name: "SwiftSemantics", package: "SwiftSemantics"),
                .product(name: "SwiftRefactoring", package: "SwiftSemantics"),
                .product(name: "SwiftRefactoringWriters", package: "SwiftSemantics"),
                .product(name: "SwiftSemanticLintPresentation", package: "SwiftSemantics"),
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
        .executableTarget(name: "SwiftSemanticsAllTestCLI", dependencies: ["SwiftSemanticsTestFlows"]),
        .executableTarget(name: "SwiftSemanticsFastTestCLI", dependencies: ["SwiftSemanticsTestFlows"]),
        .executableTarget(name: "SwiftSemanticsCompilerTestCLI", dependencies: ["SwiftSemanticsTestFlows"]),
        .executableTarget(name: "SwiftSemanticsRenameTestCLI", dependencies: ["SwiftSemanticsTestFlows"]),
        .executableTarget(name: "SwiftSemanticsValidateTestCLI", dependencies: ["SwiftSemanticsTestFlows"]),
        .executableTarget(name: "SwiftSemanticsPrepareTestCLI", dependencies: ["SwiftSemanticsTestFlows"]),
        .executableTarget(name: "SwiftSemanticsPublishTestCLI", dependencies: ["SwiftSemanticsTestFlows"]),
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
