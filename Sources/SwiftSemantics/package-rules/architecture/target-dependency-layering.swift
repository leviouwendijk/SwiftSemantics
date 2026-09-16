public extension SwiftSemanticPackageRules.Architecture {
    struct TargetDependencyLayering:
        SwiftSemanticPackageRule
    {
        public let id = SwiftSemanticRuleID.targetDependencyLayering
        public let ranks: [String: Int]

        public init(
            ranks: [String: Int]
        ) {
            self.ranks = ranks
        }

        public func diagnostics(
            in graph: SwiftSemanticPackageGraph
        ) async throws -> [SwiftSemanticPackageRuleDiagnostic] {
            var diagnostics: [SwiftSemanticPackageRuleDiagnostic] = []

            for target in graph.targets {
                guard let sourceRank = ranks[target.name] else {
                    continue
                }

                for dependency in target.dependencies {
                    guard graph.target(
                        named: dependency.name
                    ) != nil,
                    let dependencyRank = ranks[dependency.name],
                    dependencyRank > sourceRank else {
                        continue
                    }

                    diagnostics.append(
                        .init(
                            ruleID: id,
                            severity: .error,
                            message: "Target '\(target.name)' at architecture rank \(sourceRank) depends upward on '\(dependency.name)' at rank \(dependencyRank).",
                            subject: .target_dependency(
                                target: target.name,
                                dependency: dependency.name,
                                package: dependency.package
                            )
                        )
                    )
                }
            }

            return diagnostics
        }
    }
}
