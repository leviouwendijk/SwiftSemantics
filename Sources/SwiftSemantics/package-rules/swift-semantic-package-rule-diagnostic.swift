public struct SwiftSemanticPackageRuleDiagnostic:
    Sendable,
    Codable,
    Hashable
{
    public let ruleID: SwiftSemanticRuleID
    public let severity: SwiftSemanticRuleSeverity
    public let message: String
    public let subject: SwiftSemanticPackageRuleSubject

    public init(
        ruleID: SwiftSemanticRuleID,
        severity: SwiftSemanticRuleSeverity,
        message: String,
        subject: SwiftSemanticPackageRuleSubject
    ) {
        self.ruleID = ruleID
        self.severity = severity
        self.message = message
        self.subject = subject
    }
}
