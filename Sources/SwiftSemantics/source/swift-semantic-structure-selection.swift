import Foundation
import Position

/// One source region selected by structural SwiftSyntax semantics.
public struct SwiftSemanticStructureSelection:
    Sendable,
    Hashable
{
    public enum Kind:
        String,
        Sendable,
        Hashable
    {
        case declaration
        case type
        case member
        case imports
        case enclosing_scope
    }

    public let file: URL
    public let lineRange: LineRange
    public let kind: Kind
    public let symbolName: String?
    public let summary: String

    public init(
        file: URL,
        lineRange: LineRange,
        kind: Kind,
        symbolName: String? = nil,
        summary: String
    ) {
        self.file = file.standardizedFileURL
        self.lineRange = lineRange
        self.kind = kind
        self.symbolName = symbolName
        self.summary = summary
    }
}
