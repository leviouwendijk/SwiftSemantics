public struct SwiftSemanticRuleAnalyzer:
    Sendable
{
    public let ruleSet: SwiftSemanticRuleSet

    public init(
        ruleSet: SwiftSemanticRuleSet
    ) {
        self.ruleSet = ruleSet
    }

    public func analyze(
        _ source: SwiftSemanticSource,
        context: SwiftSemanticRuleContext = .init()
    ) async throws -> SwiftSemanticRuleAnalysis {
        let suppressions = RuleSuppressionIndex(
            source: source
        )

        var diagnostics: [SwiftSemanticRuleDiagnostic] = []

        for rule in ruleSet.rules {
            let emitted = try await rule.diagnostics(
                in: source,
                context: context
            )

            switch rule.suppression {
            case .forbidden:
                diagnostics.append(
                    contentsOf: emitted
                )

            case .source_directive:
                diagnostics.append(
                    contentsOf: emitted.filter { diagnostic in
                        !suppressions.suppresses(
                            diagnostic
                        )
                    }
                )
            }
        }

        return .init(
            diagnostics: diagnostics
        )
    }
}
