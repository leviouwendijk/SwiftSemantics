import Foundation

/// One compiler-aware symbol in a document outline.
///
/// Children preserve the hierarchy supplied by SourceKit-LSP when the server
/// returns DocumentSymbol values. Flat SymbolInformation responses are
/// projected as top-level values with no children.
public struct SwiftSemanticDocumentSymbol:
    Sendable,
    Codable,
    Hashable
{
    public let name: String
    public let detail: String?
    public let kind: SwiftSemanticCompilerSymbolKind
    public let location: SwiftSemanticLocation
    public let selectionRange: SwiftSemanticRange
    public let children: [SwiftSemanticDocumentSymbol]

    public init(
        name: String,
        detail: String? = nil,
        kind: SwiftSemanticCompilerSymbolKind,
        location: SwiftSemanticLocation,
        selectionRange: SwiftSemanticRange,
        children: [SwiftSemanticDocumentSymbol] = []
    ) {
        self.name = name
        self.detail = detail
        self.kind = kind
        self.location = location
        self.selectionRange = selectionRange
        self.children = children
    }
}
