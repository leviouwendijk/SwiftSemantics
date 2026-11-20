import SwiftSemantics
import TestFlows

extension SwiftSemanticsFlowSuite {
    static var architectureProofFlow: TestFlow {
        TestFlow(
            "semantic-architecture-proof-matrix",
            tags: [
                "architecture",
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
                "prove target dependency layering direction boundaries"
            ) {
                let ranks = [
                    "Core": 0,
                    "Interface": 1,
                    "Peer": 1,
                    "Application": 2,
                ]
                let rule = SwiftSemanticPackageRules.Architecture.TargetDependencyLayering(
                    ranks: ranks
                )

                try await PackageRuleFixture(
                    graph: architectureGraph(
                        source: "Core",
                        dependency: "Interface"
                    ),
                    expectedCount: 1,
                    expectedSeverity: .error
                ).assert(
                    rule,
                    label: "lower rank depending upward"
                )

                try await PackageRuleFixture(
                    graph: architectureGraph(
                        source: "Application",
                        dependency: "Interface"
                    ),
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "higher rank depending downward"
                )

                try await PackageRuleFixture(
                    graph: architectureGraph(
                        source: "Interface",
                        dependency: "Peer"
                    ),
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "same-rank dependency"
                )

                try await PackageRuleFixture(
                    graph: architectureGraph(
                        source: "Core",
                        dependency: "Unranked"
                    ),
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "unranked dependency is outside configured layering policy"
                )
            }

            Step(
                "prove direct dependency budget boundaries and filtering"
            ) {
                let graph = dependencyBudgetGraph()

                try await PackageRuleFixture(
                    graph: graph,
                    expectedCount: 0
                ).assert(
                    SwiftSemanticPackageRules.Architecture.TargetDependencyBudget(
                        maximumDirectDependencies: 2,
                        targets: [
                            "Core",
                        ]
                    ),
                    label: "exact dependency budget remains clean"
                )

                try await PackageRuleFixture(
                    graph: graph,
                    expectedCount: 1,
                    expectedSeverity: .hint
                ).assert(
                    SwiftSemanticPackageRules.Architecture.TargetDependencyBudget(
                        maximumDirectDependencies: 1,
                        targets: [
                            "Core",
                        ]
                    ),
                    label: "budget plus one emits default hint"
                )

                try await PackageRuleFixture(
                    graph: graph,
                    expectedCount: 0
                ).assert(
                    SwiftSemanticPackageRules.Architecture.TargetDependencyBudget(
                        maximumDirectDependencies: 1,
                        targets: [
                            "Application",
                        ]
                    ),
                    label: "target filter excludes Core"
                )

                try await PackageRuleFixture(
                    graph: graph,
                    expectedCount: 1,
                    expectedSeverity: .warning
                ).assert(
                    SwiftSemanticPackageRules.Architecture.TargetDependencyBudget(
                        maximumDirectDependencies: 1,
                        targets: [
                            "Core",
                        ],
                        severity: .warning
                    ),
                    label: "dependency budget severity is configurable"
                )
            }
        }
    }
}

private func architectureGraph(
    source: String,
    dependency: String
) -> SwiftSemanticPackageGraph {
    let names = Set(
        [
            source,
            dependency,
        ]
    )

    return .init(
        rootIdentity: "architecture-proof",
        rootName: "ArchitectureProof",
        packages: [],
        packageDependencies: [],
        products: [],
        targets: names.sorted().map { name in
            .init(
                name: name,
                type: "regular",
                dependencies:
                    name == source
                    ? [
                        .init(
                            kind: .target,
                            name: dependency
                        ),
                    ]
                    : []
            )
        }
    )
}

private func dependencyBudgetGraph() -> SwiftSemanticPackageGraph {
    .init(
        rootIdentity: "dependency-budget-proof",
        rootName: "DependencyBudgetProof",
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
                        name: "Storage"
                    ),
                    .init(
                        kind: .product,
                        name: "Logging",
                        package: "logging"
                    ),
                ]
            ),
            .init(
                name: "Storage",
                type: "regular",
                dependencies: []
            ),
            .init(
                name: "Application",
                type: "executable",
                dependencies: []
            ),
        ]
    )
}
