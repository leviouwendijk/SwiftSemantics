public extension SwiftSemanticPackageRules.Dependencies {
    struct ForbiddenPackageDependency:
        SwiftSemanticPackageRule
    {
        public let id =
            SwiftSemanticRuleID.forbiddenPackageDependency

        public let identities: Set<String>

        public init(
            identities: [String]
        ) {
            self.identities = Set(
                identities
            )
        }

        public func diagnostics(
            in graph: SwiftSemanticPackageGraph
        ) async throws -> [SwiftSemanticPackageRuleDiagnostic] {
            graph.declaredPackageDependencies.compactMap { dependency in
                guard let identity = dependency.identity,
                    identities.contains(identity) else {
                    return nil
                }

                return .init(
                    ruleID: id,
                    severity: .error,
                    message:
                        "Package directly declares forbidden dependency '\(identity)'.",
                    subject: .declared_package_dependency(
                        identity: dependency.identity,
                        location: dependency.location
                    )
                )
            }
        }
    }
}
