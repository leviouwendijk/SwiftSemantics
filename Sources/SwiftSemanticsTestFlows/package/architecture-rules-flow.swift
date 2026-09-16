import SwiftSemantics
import TestFlows

extension SwiftSemanticsFlowSuite {
    static var architectureRulesFlow: TestFlow {
        TestFlow(
            "semantic-architecture-rules",
            tags: [
                "architecture",
                "dependencies",
                "package",
                "rules",
                "swift-semantics",
            ]
        ) {
            Step(
                "dependency layering rejects upward target edges"
            ) {
                let graph = architectureFixtureGraph()
                let analyzer = SwiftSemanticPackageRuleAnalyzer(
                    ruleSet: try .init(
                        rules: [
                            SwiftSemanticPackageRules.Architecture.TargetDependencyLayering(
                                ranks: [
                                    "Core": 0,
                                    "Interface": 1,
                                    "Application": 2,
                                ]
                            ),
                        ]
                    )
                )
                let analysis = try await analyzer.analyze(
                    graph
                )

                try Expect.equal(
                    analysis.diagnostics.count,
                    1,
                    "upward dependency count"
                )
                try Expect.equal(
                    analysis.diagnostics.first?.ruleID,
                    .targetDependencyLayering,
                    "layering rule ID"
                )
            }

            Step(
                "dependency budgets report excessive direct fan out"
            ) {
                let graph = architectureFixtureGraph()
                let analyzer = SwiftSemanticPackageRuleAnalyzer(
                    ruleSet: try .init(
                        rules: [
                            SwiftSemanticPackageRules.Architecture.TargetDependencyBudget(
                                maximumDirectDependencies: 1,
                                targets: [
                                    "Core",
                                ]
                            ),
                        ]
                    )
                )
                let analysis = try await analyzer.analyze(
                    graph
                )

                try Expect.equal(
                    analysis.diagnostics.count,
                    1,
                    "dependency budget count"
                )
                try Expect.equal(
                    analysis.diagnostics.first?.severity,
                    .hint,
                    "dependency budget default severity"
                )
            }
        }
    }
}

private func architectureFixtureGraph() -> SwiftSemanticPackageGraph {
    .init(
        rootIdentity: "architecture-fixture",
        rootName: "ArchitectureFixture",
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
                        name: "Interface"
                    ),
                    .init(
                        kind: .product,
                        name: "Logging",
                        package: "logging"
                    ),
                ]
            ),
            .init(
                name: "Interface",
                type: "regular",
                dependencies: []
            ),
            .init(
                name: "Application",
                type: "executable",
                dependencies: [
                    .init(
                        kind: .target,
                        name: "Interface"
                    ),
                ]
            ),
        ]
    )
}
