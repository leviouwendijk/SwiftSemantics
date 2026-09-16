public struct SwiftSemanticRuleAnalysis:
    Sendable,
    Codable,
    Hashable
{
    public let diagnostics: [SwiftSemanticRuleDiagnostic]

    public init(
        diagnostics: [SwiftSemanticRuleDiagnostic]
    ) {
        self.diagnostics = diagnostics
    }

    public var hasErrors: Bool {
        diagnostics.contains { diagnostic in
            diagnostic.severity == .error
        }
    }
}
