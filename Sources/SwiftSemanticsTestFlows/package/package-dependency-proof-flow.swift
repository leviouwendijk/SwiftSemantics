import SwiftSemantics
import TestFlows

extension SwiftSemanticsFlowSuite {
    static var packageDependencyProofFlow: TestFlow {
        TestFlow(
            "semantic-package-dependency-proof-matrix",
            tags: [
                "boundaries",
                "dependencies",
                "fixtures",
                "package",
                "regression",
                "rules",
                "swift-semantics",
            ]
        ) {
            Step(
                "prove forbidden target dependency boundaries"
            ) {
                let qualified = SwiftSemanticPackageRules.Dependencies.ForbiddenTargetDependency(
                    forbidden: [
                        .init(
                            sourceTarget: "Core",
                            dependencyName: "Forbidden",
                            dependencyPackage: "forbidden-package"
                        ),
                    ]
                )

                try await PackageRuleFixture(
                    graph: targetDependencyGraph(
                        source: "Core",
                        dependency: .init(
                            kind: .product,
                            name: "Forbidden",
                            package: "forbidden-package"
                        )
                    ),
                    expectedCount: 1,
                    expectedSeverity: .error
                ).assert(
                    qualified,
                    label: "exact qualified direct dependency"
                )

                try await PackageRuleFixture(
                    graph: targetDependencyGraph(
                        source: "Other",
                        dependency: .init(
                            kind: .product,
                            name: "Forbidden",
                            package: "forbidden-package"
                        )
                    ),
                    expectedCount: 0
                ).assert(
                    qualified,
                    label: "wrong source target"
                )

                try await PackageRuleFixture(
                    graph: targetDependencyGraph(
                        source: "Core",
                        dependency: .init(
                            kind: .product,
                            name: "Allowed",
                            package: "forbidden-package"
                        )
                    ),
                    expectedCount: 0
                ).assert(
                    qualified,
                    label: "wrong dependency name"
                )

                try await PackageRuleFixture(
                    graph: targetDependencyGraph(
                        source: "Core",
                        dependency: .init(
                            kind: .product,
                            name: "Forbidden",
                            package: "other-package"
                        )
                    ),
                    expectedCount: 0
                ).assert(
                    qualified,
                    label: "package qualifier mismatch"
                )

                let unqualified = SwiftSemanticPackageRules.Dependencies.ForbiddenTargetDependency(
                    forbidden: [
                        .init(
                            sourceTarget: "Core",
                            dependencyName: "Forbidden"
                        ),
                    ]
                )

                try await PackageRuleFixture(
                    graph: targetDependencyGraph(
                        source: "Core",
                        dependency: .init(
                            kind: .target,
                            name: "Forbidden"
                        )
                    ),
                    expectedCount: 1,
                    expectedSeverity: .error
                ).assert(
                    unqualified,
                    label: "unqualified direct target dependency"
                )

                try await PackageRuleFixture(
                    graph: transitiveTargetDependencyGraph(),
                    expectedCount: 0
                ).assert(
                    unqualified,
                    label: "transitive target dependency is not inferred"
                )
            }

            Step(
                "prove forbidden declared package dependency boundaries"
            ) {
                let rule = SwiftSemanticPackageRules.Dependencies.ForbiddenPackageDependency(
                    identities: [
                        "forbidden-package",
                    ]
                )

                try await PackageRuleFixture(
                    graph: packageDependencyGraph(
                        declared: [
                            .init(
                                kind: .sourceControl,
                                identity: "forbidden-package",
                                location: "https://example.com/forbidden-package.git"
                            ),
                        ]
                    ),
                    expectedCount: 1,
                    expectedSeverity: .error
                ).assert(
                    rule,
                    label: "exact directly declared package identity"
                )

                try await PackageRuleFixture(
                    graph: packageDependencyGraph(
                        declared: [
                            .init(
                                kind: .sourceControl,
                                identity: "allowed-package",
                                location: "https://example.com/allowed-package.git"
                            ),
                        ]
                    ),
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "allowed declared package identity"
                )

                try await PackageRuleFixture(
                    graph: packageDependencyGraph(
                        declared: [
                            .init(
                                kind: .sourceControl,
                                identity: nil,
                                location: "https://example.com/forbidden-package.git"
                            ),
                        ]
                    ),
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "nil identity is not inferred from repository location"
                )

                try await PackageRuleFixture(
                    graph: packageDependencyGraph(
                        resolved: [
                            .init(
                                sourceIdentity: "root",
                                targetIdentity: "middle"
                            ),
                            .init(
                                sourceIdentity: "middle",
                                targetIdentity: "forbidden-package"
                            ),
                        ]
                    ),
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "resolved transitive package edge is not treated as root declaration"
                )
            }
        }
    }
}

private func targetDependencyGraph(
    source: String,
    dependency: SwiftSemanticPackageGraph.Target.Dependency
) -> SwiftSemanticPackageGraph {
    .init(
        rootIdentity: "root",
        rootName: "Root",
        packages: [],
        packageDependencies: [],
        products: [],
        targets: [
            .init(
                name: source,
                type: "regular",
                dependencies: [
                    dependency,
                ]
            ),
        ]
    )
}

private func transitiveTargetDependencyGraph() -> SwiftSemanticPackageGraph {
    .init(
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
                        kind: .target,
                        name: "Middle"
                    ),
                ]
            ),
            .init(
                name: "Middle",
                type: "regular",
                dependencies: [
                    .init(
                        kind: .target,
                        name: "Forbidden"
                    ),
                ]
            ),
            .init(
                name: "Forbidden",
                type: "regular"
            ),
        ]
    )
}

private func packageDependencyGraph(
    declared: [SwiftSemanticPackageGraph.DeclaredPackageDependency] = [],
    resolved: [SwiftSemanticPackageGraph.PackageDependency] = []
) -> SwiftSemanticPackageGraph {
    .init(
        rootIdentity: "root",
        rootName: "Root",
        packages: [],
        packageDependencies: resolved,
        declaredPackageDependencies: declared,
        products: [],
        targets: []
    )
}
