/// Source-level structural query independent of any Agentic tool contract.
public enum SwiftSemanticStructureQuery:
    Sendable,
    Hashable
{
    case declaration(
        named: String
    )
    case type(
        named: String
    )
    case member(
        named: String,
        parentType: String? = nil
    )
    case imports
    case enclosingScope(
        location: SwiftSemanticSourceLocation
    )
}

public struct SwiftSemanticSourceLocation:
    Sendable,
    Hashable
{
    /// One-based source line.
    public let line: Int

    /// Optional one-based Unicode-scalar column using Position semantics.
    ///
    /// When omitted, structural containment is line-based. When supplied,
    /// SwiftSemantics resolves this coordinate into SwiftSyntax's UTF-8 offset
    /// space before testing containment.
    public let column: Int?

    public init(
        line: Int,
        column: Int? = nil
    ) {
        self.line = line
        self.column = column
    }
}
