public protocol SwiftSemanticRule:
    Sendable
{
    init()

    var id: SwiftSemanticRuleID { get }
    var suppression: SwiftSemanticRuleSuppression { get }

    /// Analyze source and return rule violations as diagnostics.
    ///
    /// Throw only when rule execution itself cannot complete. A source that
    /// violates the rule is a successful analysis containing diagnostics.
    func diagnostics(
        in source: SwiftSemanticSource,
        context: SwiftSemanticRuleContext
    ) async throws -> [SwiftSemanticRuleDiagnostic]
}

public extension SwiftSemanticRule {
    var suppression: SwiftSemanticRuleSuppression {
        .forbidden
    }
}
