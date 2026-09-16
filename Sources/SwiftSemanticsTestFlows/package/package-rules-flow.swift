import SwiftSemantics
import TestFlows

extension SwiftSemanticsFlowSuite {
    static var packageRulesFlow: TestFlow {
        TestFlow(
            "semantic-package-rules",
            tags: [
                "architecture",
                "dependencies",
                "lint",
                "package",
                "rules",
                "swift-semantics",
                "swiftpm",
            ]
        ) {
            Step(
                "package rule IDs use macro-generated snake-case strings"
            ) {
                try Expect.equal(
                    SwiftSemanticRuleID
                        .forbiddenTargetDependency
                        .rawValue,
                    "forbidden_target_dependency",
                    "forbidden target dependency rule ID"
                )
                try Expect.equal(
                    SwiftSemanticRuleID
                        .forbiddenPackageDependency
                        .rawValue,
                    "forbidden_package_dependency",
                    "forbidden package dependency rule ID"
                )
            }

            Step(
                "reject duplicate package rule identifiers"
            ) {
                do {
                    _ = try SwiftSemanticPackageRuleSet(
                        rules: [
                            SwiftSemanticPackageRules.Dependencies
                                .ForbiddenPackageDependency(
                                    identities: [
                                        "first",
                                    ]
                                ),
                            SwiftSemanticPackageRules.Dependencies
                                .ForbiddenPackageDependency(
                                    identities: [
                                        "second",
                                    ]
                                ),
                        ]
                    )

                    try Expect.equal(
                        true,
                        false,
                        "duplicate package rule IDs must fail construction"
                    )
                } catch let error as SwiftSemanticPackageRuleSetError {
                    try Expect.equal(
                        error,
                        .duplicateRuleID(
                            .forbiddenPackageDependency
                        ),
                        "duplicate package rule ID error"
                    )
                }
            }

            Step(
                "detect exact direct target and package dependency violations"
            ) {
                let graph = SwiftSemanticPackageGraph(
                    rootIdentity: "root",
                    rootName: "Root",
                    packages: [],
                    packageDependencies: [],
                    declaredPackageDependencies: [
                        .init(
                            kind: .sourceControl,
                            identity: "forbidden-package",
                            location:
                                "https://example.com/forbidden-package.git"
                        ),
                        .init(
                            kind: .sourceControl,
                            identity: "allowed-package",
                            location:
                                "https://example.com/allowed-package.git"
                        ),
                    ],
                    products: [],
                    targets: [
                        .init(
                            name: "Core",
                            type: "regular",
                            dependencies: [
                                .init(
                                    kind: .target,
                                    name: "ForbiddenLayer"
                                ),
                                .init(
                                    kind: .product,
                                    name: "AllowedProduct",
                                    package: "allowed-package"
                                ),
                            ]
                        ),
                        .init(
                            name: "ForbiddenLayer",
                            type: "regular"
                        ),
                    ]
                )

                let analyzer = SwiftSemanticPackageRuleAnalyzer(
                    ruleSet: try SwiftSemanticPackageRuleSet(
                        rules: [
                            SwiftSemanticPackageRules.Dependencies
                                .ForbiddenTargetDependency(
                                    forbidden: [
                                        .init(
                                            sourceTarget: "Core",
                                            dependencyName: "ForbiddenLayer"
                                        ),
                                        .init(
                                            sourceTarget: "OtherTarget",
                                            dependencyName: "AllowedProduct",
                                            dependencyPackage: "allowed-package"
                                        ),
                                    ]
                                ),
                            SwiftSemanticPackageRules.Dependencies
                                .ForbiddenPackageDependency(
                                    identities: [
                                        "forbidden-package",
                                    ]
                                ),
                        ]
                    )
                )

                let analysis = try await analyzer.analyze(
                    graph
                )
                let identifiers = analysis.diagnostics
                    .map(\.ruleID.rawValue)
                    .sorted()

                try Expect.equal(
                    identifiers,
                    [
                        "forbidden_package_dependency",
                        "forbidden_target_dependency",
                    ],
                    "exact direct dependency rules"
                )
                try Expect.equal(
                    analysis.diagnostics.count,
                    2,
                    "one package and one target dependency diagnostic"
                )
                try Expect.equal(
                    analysis.hasErrors,
                    true,
                    "package rule analysis reports errors"
                )
            }

            Step(
                "do not treat transitive package edges as direct declarations"
            ) {
                let graph = SwiftSemanticPackageGraph(
                    rootIdentity: "root",
                    rootName: "Root",
                    packages: [],
                    packageDependencies: [
                        .init(
                            sourceIdentity: "allowed-package",
                            targetIdentity: "transitive-forbidden"
                        ),
                    ],
                    declaredPackageDependencies: [
                        .init(
                            kind: .sourceControl,
                            identity: "allowed-package",
                            location:
                                "https://example.com/allowed-package.git"
                        ),
                    ],
                    products: [],
                    targets: []
                )

                let analysis = try await SwiftSemanticPackageRuleAnalyzer(
                    ruleSet: try SwiftSemanticPackageRuleSet(
                        rules: [
                            SwiftSemanticPackageRules.Dependencies
                                .ForbiddenPackageDependency(
                                    identities: [
                                        "transitive-forbidden",
                                    ]
                                ),
                        ]
                    )
                )
                .analyze(
                    graph
                )

                try Expect.equal(
                    analysis.diagnostics.count,
                    0,
                    "transitive package dependencies are not direct-declaration violations"
                )
            }

            Step(
                "package-qualified target policy matches the exact package"
            ) {
                let graph = SwiftSemanticPackageGraph(
                    rootIdentity: "root",
                    rootName: "Root",
                    packages: [],
                    packageDependencies: [],
                    products: [],
                    targets: [
                        .init(
                            name: "Core",
                            type: "regular",
                            dependencies: [
                                .init(
                                    kind: .product,
                                    name: "Transport",
                                    package: "allowed-package"
                                ),
                            ]
                        ),
                    ]
                )

                let analysis = try await SwiftSemanticPackageRuleAnalyzer(
                    ruleSet: try SwiftSemanticPackageRuleSet(
                        rules: [
                            SwiftSemanticPackageRules.Dependencies
                                .ForbiddenTargetDependency(
                                    forbidden: [
                                        .init(
                                            sourceTarget: "Core",
                                            dependencyName: "Transport",
                                            dependencyPackage: "different-package"
                                        ),
                                    ]
                                ),
                        ]
                    )
                )
                .analyze(
                    graph
                )

                try Expect.equal(
                    analysis.diagnostics.count,
                    0,
                    "package-qualified target dependency policy does not overmatch"
                )
            }
        }
    }
}
