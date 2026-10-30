import Foundation
import Macros
import Schema

/// One compiler-proposed replacement in one source document.
/// Positions are one-based UTF-16 coordinates, not UTF-8 offsets.
@JSONSchema
public struct SwiftSemanticRenameEdit:
    Codable,
    Sendable,
    Hashable
{
    public let range: SwiftSemanticRange
    public let newText: String

    public init(
        range: SwiftSemanticRange,
        newText: String
    ) {
        self.range = range
        self.newText = newText
    }
}

/// Edits for one document, preserving the LSP version constraint when provided.
@JSONSchema
public struct SwiftSemanticRenameDocument:
    Codable,
    Sendable,
    Hashable
{
    public let uri: URL
    public let version: Int?
    public let edits: [SwiftSemanticRenameEdit]

    public init(
        uri: URL,
        version: Int?,
        edits: [SwiftSemanticRenameEdit]
    ) {
        self.uri = uri
        self.version = version
        self.edits = edits
    }
}

/// A compiler-produced rename proposal. This does not mutate source files.
/// Documents preserve the server's edit-group order and may repeat a URI.
/// Repeated groups must not be flattened without verifying their versions,
/// coordinate bases, ordering dependencies, and overlapping edits.
/// Consumers must validate all target paths, source baselines, edit ranges,
/// and compilation before publication. Index completeness is not guaranteed.
@JSONSchema
public struct SwiftSemanticRenameResult:
    Codable,
    Sendable,
    Hashable
{
    public let documents: [SwiftSemanticRenameDocument]

    public init(documents: [SwiftSemanticRenameDocument]) {
        self.documents = documents
    }
}
