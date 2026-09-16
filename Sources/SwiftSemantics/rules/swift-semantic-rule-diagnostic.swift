import Foundation
import Position

/// One diagnostic produced by an authored Swift semantic rule.
///
/// This remains distinct from `SwiftSemanticDiagnostic`, which represents
/// compiler diagnostics projected from SourceKit-LSP.
public struct SwiftSemanticRuleDiagnostic:
    Sendable,
    Codable,
    Hashable
{
    public let ruleID: SwiftSemanticRuleID
    public let severity: SwiftSemanticRuleSeverity
    public let message: String
    public let file: URL?
    public let lineRange: LineRange?

    public init(
        ruleID: SwiftSemanticRuleID,
        severity: SwiftSemanticRuleSeverity,
        message: String,
        file: URL? = nil,
        lineRange: LineRange? = nil
    ) {
        self.ruleID = ruleID
        self.severity = severity
        self.message = message
        self.file = file?.standardizedFileURL
        self.lineRange = lineRange
    }
}
