public protocol SwiftSemanticPackageRule:
    Sendable
{
    var id: SwiftSemanticRuleID { get }

    /// Analyze one SwiftPM package graph and return deterministic architecture
    /// violations as diagnostics.
    ///
    /// Throw only when rule execution itself cannot complete. A graph that
    /// violates the rule is a successful analysis containing diagnostics.
    func diagnostics(
        in graph: SwiftSemanticPackageGraph
    ) async throws -> [SwiftSemanticPackageRuleDiagnostic]
}
