public struct SwiftSemanticPackageRuleAnalyzer:
    Sendable
{
    public let ruleSet: SwiftSemanticPackageRuleSet

    public init(
        ruleSet: SwiftSemanticPackageRuleSet
    ) {
        self.ruleSet = ruleSet
    }

    public func analyze(
        _ graph: SwiftSemanticPackageGraph
    ) async throws -> SwiftSemanticPackageRuleAnalysis {
        var diagnostics: [SwiftSemanticPackageRuleDiagnostic] = []

        for rule in ruleSet.rules {
            diagnostics.append(
                contentsOf: try await rule.diagnostics(
                    in: graph
                )
            )
        }

        return .init(
            diagnostics: diagnostics
        )
    }
}
