import Foundation

public enum SwiftSemanticDiagnosticSeverity:
    Sendable,
    Codable,
    Hashable
{
    case error
    case warning
    case information
    case hint
    case unspecified
}

/// One compiler diagnostic projected out of SourceKit-LSP.
public struct SwiftSemanticDiagnostic:
    Sendable,
    Codable,
    Hashable
{
    public let uri: URL
    public let range: SwiftSemanticRange
    public let severity: SwiftSemanticDiagnosticSeverity
    public let message: String
    public let source: String?

    public init(
        uri: URL,
        range: SwiftSemanticRange,
        severity: SwiftSemanticDiagnosticSeverity,
        message: String,
        source: String? = nil
    ) {
        self.uri = uri
        self.range = range
        self.severity = severity
        self.message = message
        self.source = source
    }
}
