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
    public let line: Int
    public let column: Int?

    public init(
        line: Int,
        column: Int? = nil
    ) {
        self.line = line
        self.column = column
    }
}
