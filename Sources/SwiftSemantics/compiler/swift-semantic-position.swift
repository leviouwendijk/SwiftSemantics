import Foundation

/// A compiler-semantic source position.
///
/// Lines are one-based. `utf16Column` is a one-based UTF-16 code-unit column.
/// This coordinate system is explicit because SourceKit-LSP compiler-semantic
/// operations use UTF-16 positions by default. It is intentionally distinct
/// from structural `SwiftSemanticSourceLocation`, whose column follows
/// Position/Unicode-scalar semantics.
public struct SwiftSemanticPosition:
    Sendable,
    Codable,
    Hashable
{
    public let line: Int
    public let utf16Column: Int

    public init(
        line: Int,
        utf16Column: Int
    ) {
        self.line = line
        self.utf16Column = utf16Column
    }
}

/// One compiler-semantic source range.
public struct SwiftSemanticRange:
    Sendable,
    Codable,
    Hashable
{
    public let start: SwiftSemanticPosition
    public let end: SwiftSemanticPosition

    public init(
        start: SwiftSemanticPosition,
        end: SwiftSemanticPosition
    ) {
        self.start = start
        self.end = end
    }
}

/// A URI and range returned by a compiler-semantic operation.
///
/// URI is used instead of file URL because SourceKit-LSP may also return
/// generated interfaces using non-file schemes.
public struct SwiftSemanticLocation:
    Sendable,
    Codable,
    Hashable
{
    public let uri: URL
    public let range: SwiftSemanticRange

    public init(
        uri: URL,
        range: SwiftSemanticRange
    ) {
        self.uri = uri
        self.range = range
    }
}
