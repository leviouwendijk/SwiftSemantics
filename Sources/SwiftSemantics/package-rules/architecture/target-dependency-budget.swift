public extension SwiftSemanticPackageRules.Architecture {
    struct TargetDependencyBudget:
        SwiftSemanticPackageRule
    {
        public let id = SwiftSemanticRuleID.targetDependencyBudget
        public let maximumDirectDependencies: UInt
        public let targets: Set<String>?
        public let severity: SwiftSemanticRuleSeverity

        public init(
            maximumDirectDependencies: UInt,
            targets: Set<String>? = nil,
            severity: SwiftSemanticRuleSeverity = .hint
        ) {
            self.maximumDirectDependencies = maximumDirectDependencies
            self.targets = targets
            self.severity = severity
        }

        public func diagnostics(
            in graph: SwiftSemanticPackageGraph
        ) async throws -> [SwiftSemanticPackageRuleDiagnostic] {
            graph.targets.compactMap { target in
                if let targets,
                   !targets.contains(target.name) {
                    return nil
                }

                let maximum = Int(
                    maximumDirectDependencies
                )

                guard target.dependencies.count > maximum else {
                    return nil
                }

                return .init(
                    ruleID: id,
                    severity: severity,
                    message: "Target '\(target.name)' has \(target.dependencies.count) direct dependencies; the configured budget is \(maximum). Consider splitting responsibilities or introducing a narrower boundary.",
                    subject: .target(
                        target.name
                    )
                )
            }
        }
    }
}
