import Position

/// One declaration discovered from Swift source structure.
///
/// This is syntactic semantic data. `id` is deterministic within the inspected
/// source representation but is not a compiler USR. SourceKit-LSP will later
/// contribute compiler-stable semantic identities separately.
public struct SwiftSemanticSymbol:
    Sendable,
    Codable,
    Hashable,
    Identifiable
{
    public let id: String
    public let kind: SwiftSemanticSymbolKind
    public let name: String
    public let displayName: String
    public let parentType: String?
    public let lineRange: LineRange
    public let summary: String

    public init(
        kind: SwiftSemanticSymbolKind,
        name: String,
        displayName: String? = nil,
        parentType: String? = nil,
        lineRange: LineRange,
        summary: String
    ) {
        let displayName = displayName
            ?? name

        id = Self.makeIdentifier(
            kind: kind,
            displayName: displayName,
            parentType: parentType,
            lineRange: lineRange
        )
        self.kind = kind
        self.name = name
        self.displayName = displayName
        self.parentType = parentType
        self.lineRange = lineRange
        self.summary = summary
    }
}

private extension SwiftSemanticSymbol {
    static func makeIdentifier(
        kind: SwiftSemanticSymbolKind,
        displayName: String,
        parentType: String?,
        lineRange: LineRange
    ) -> String {
        let parent = parentType
            ?? "_"

        return "\(kind.rawValue):\(parent):\(displayName):\(lineRange.start)-\(lineRange.end)"
    }
}
