public struct SwiftSemanticPackageRuleAnalysis:
    Sendable,
    Codable,
    Hashable
{
    public let diagnostics: [SwiftSemanticPackageRuleDiagnostic]

    public init(
        diagnostics: [SwiftSemanticPackageRuleDiagnostic]
    ) {
        self.diagnostics = diagnostics
    }

    public var hasErrors: Bool {
        diagnostics.contains { diagnostic in
            diagnostic.severity == .error
        }
    }
}
