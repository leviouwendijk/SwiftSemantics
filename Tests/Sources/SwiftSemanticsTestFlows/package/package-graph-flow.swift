import Foundation
import SwiftSemantics
import TestFlows

extension SwiftSemanticsFlowSuite {
    static var packageGraphFlow: TestFlow {
        TestFlow(
            "semantic-package-graph",
            tags: [
                "swift-semantics",
                "workspace",
                "swiftpm",
                "package",
                "graph",
            ]
        ) {
            let fixture = try SwiftSemanticPackageFixture()

            defer {
                fixture.remove()
            }

            let workspace = SwiftSemanticWorkspace(
                root: fixture.root
            )

            let graph = try await workspace.packageGraph()

            try Expect.equal(
                graph.rootName,
                "SemanticFixture",
                "semantic root package name"
            )

            try Expect.equal(
                graph.packages
                    .map(\.name)
                    .sorted(),
                [
                    "Leaf",
                    "SemanticFixture",
                ],
                "semantic resolved package names"
            )

            try Expect.equal(
                graph.declaredPackageDependencies.count,
                1,
                "semantic declared package dependency count"
            )

            try Expect.equal(
                graph.declaredPackageDependencies.first?.kind,
                Optional(
                    SwiftSemanticPackageGraph
                        .DeclaredPackageDependency
                        .Kind
                        .fileSystem
                ),
                "semantic declared local dependency kind"
            )

            let semanticCore = try Expect.notNil(
                graph.target(
                    named: "SemanticCore"
                ),
                "SemanticCore target"
            )

            let targetDependencies = semanticCore.dependencies
                .map { dependency in
                    [
                        dependency.kind.rawValue,
                        dependency.name,
                        dependency.package ?? "-",
                    ]
                        .joined(
                            separator: ":"
                        )
                }
                .sorted()

            try Expect.equal(
                targetDependencies,
                [
                    "byName:Helper:-",
                    "product:Leaf:Leaf",
                ],
                "semantic target dependency distinctions"
            )

            let product = try Expect.notNil(
                graph.product(
                    named: "SemanticCore"
                ),
                "SemanticCore product"
            )

            try Expect.equal(
                product.kind,
                SwiftSemanticPackageGraph
                    .Product
                    .Kind
                    .library,
                "semantic product kind"
            )

            let namesByIdentity = Dictionary(
                uniqueKeysWithValues:
                    graph.packages.map {
                        (
                            $0.identity,
                            $0.name
                        )
                    }
            )

            let packageEdges = graph.packageDependencies
                .compactMap { dependency -> String? in
                    guard
                        let source = namesByIdentity[
                            dependency.sourceIdentity
                        ],
                        let target = namesByIdentity[
                            dependency.targetIdentity
                        ]
                    else {
                        return nil
                    }

                    return source
                        + "->"
                        + target
                }

            try Expect.equal(
                packageEdges,
                [
                    "SemanticFixture->Leaf",
                ],
                "semantic resolved package edge"
            )

            try Expect.equal(
                graph.packageDependencies(
                    from: graph.rootIdentity
                ).count,
                1,
                "root dependency lookup"
            )

            try Expect.equal(
                graph.rootPackage?.name,
                Optional(
                    "SemanticFixture"
                ),
                "semantic root package lookup"
            )

            return [
                .field(
                    "root",
                    graph.rootName
                ),
                .field(
                    "packages",
                    String(
                        graph.packages.count
                    )
                ),
                .field(
                    "targets",
                    String(
                        graph.targets.count
                    )
                ),
            ]
        }
    }
}
