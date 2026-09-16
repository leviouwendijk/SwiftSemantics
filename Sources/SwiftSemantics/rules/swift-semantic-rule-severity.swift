public enum SwiftSemanticRuleSeverity:
    String,
    Sendable,
    Codable,
    Hashable,
    CaseIterable
{
    case error
    case warning
    case information
    case hint
}
