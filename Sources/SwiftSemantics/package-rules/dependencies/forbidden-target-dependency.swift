public extension SwiftSemanticPackageRules.Dependencies {
    struct ForbiddenTargetDependency:
        SwiftSemanticPackageRule
    {
        public let id =
            SwiftSemanticRuleID.forbiddenTargetDependency

        public let forbidden:
            Set<SwiftSemanticForbiddenTargetDependency>

        public init(
            forbidden: [SwiftSemanticForbiddenTargetDependency]
        ) {
            self.forbidden = Set(
                forbidden
            )
        }

        public func diagnostics(
            in graph: SwiftSemanticPackageGraph
        ) async throws -> [SwiftSemanticPackageRuleDiagnostic] {
            var diagnostics: [SwiftSemanticPackageRuleDiagnostic] = []

            for target in graph.targets {
                for dependency in target.dependencies {
                    guard isForbidden(
                        target: target.name,
                        dependency: dependency
                    ) else {
                        continue
                    }

                    diagnostics.append(
                        .init(
                            ruleID: id,
                            severity: .error,
                            message:
                                "Target '\(target.name)' directly depends on forbidden dependency '\(dependency.name)'.",
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

        private func isForbidden(
            target: String,
            dependency: SwiftSemanticPackageGraph.Target.Dependency
        ) -> Bool {
            forbidden.contains { relation in
                guard relation.sourceTarget == target,
                      relation.dependencyName == dependency.name else {
                    return false
                }

                guard let expectedPackage =
                    relation.dependencyPackage else {
                    return true
                }

                return dependency.package == expectedPackage
            }
        }
    }
}
