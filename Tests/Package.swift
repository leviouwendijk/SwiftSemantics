// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "SwiftSemanticsTests",
    platforms: [
        .macOS(.v13),
    ],
    products: [
    ],
    dependencies: [
        .package(
            url: "https://github.com/leviouwendijk/Writers.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/TestFlows.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Difference.git",
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
