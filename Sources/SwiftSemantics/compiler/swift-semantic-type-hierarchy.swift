import Foundation

public struct SwiftSemanticTypeHierarchyItem:
    Sendable,
    Codable,
    Hashable
{
    public let name: String
    public let detail: String?
    public let kind: SwiftSemanticCompilerSymbolKind
    public let location: SwiftSemanticLocation
    public let selectionRange: SwiftSemanticRange

    public init(
        name: String,
        detail: String? = nil,
        kind: SwiftSemanticCompilerSymbolKind,
        location: SwiftSemanticLocation,
        selectionRange: SwiftSemanticRange
    ) {
        self.name = name
        self.detail = detail
        self.kind = kind
        self.location = location
        self.selectionRange = selectionRange
    }
}
