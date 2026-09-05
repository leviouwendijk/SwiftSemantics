import Foundation

public struct SwiftSemanticCallHierarchyItem:
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

public struct SwiftSemanticIncomingCall:
    Sendable,
    Codable,
    Hashable
{
    public let caller: SwiftSemanticCallHierarchyItem
    public let callRanges: [SwiftSemanticRange]

    public init(
        caller: SwiftSemanticCallHierarchyItem,
        callRanges: [SwiftSemanticRange]
    ) {
        self.caller = caller
        self.callRanges = callRanges
    }
}

public struct SwiftSemanticOutgoingCall:
    Sendable,
    Codable,
    Hashable
{
    public let callee: SwiftSemanticCallHierarchyItem
    public let callRanges: [SwiftSemanticRange]

    public init(
        callee: SwiftSemanticCallHierarchyItem,
        callRanges: [SwiftSemanticRange]
    ) {
        self.callee = callee
        self.callRanges = callRanges
    }
}
