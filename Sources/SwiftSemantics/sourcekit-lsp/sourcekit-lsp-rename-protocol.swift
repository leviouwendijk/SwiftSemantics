import Foundation

struct SourceKitLSPRenameParams:
    Encodable,
    Sendable
{
    let textDocument: SourceKitLSPTextDocumentIdentifier
    let position: SourceKitLSPPosition
    let newName: String
}

struct SourceKitLSPRenameTextEdit:
    Decodable,
    Sendable
{
    let range: SourceKitLSPRange
    let newText: String
    let annotationId: String?
}

struct SourceKitLSPRenameVersionedDocument:
    Decodable,
    Sendable
{
    let uri: String
    let version: Int?
}

/// Represents either a text-document edit or an unsupported resource operation.
/// A resource operation must never be silently discarded by the adapter.
struct SourceKitLSPRenameDocumentChange:
    Decodable,
    Sendable
{
    let kind: String?
    let textDocument: SourceKitLSPRenameVersionedDocument?
    let edits: [SourceKitLSPRenameTextEdit]?
}

struct SourceKitLSPRenameWorkspaceEdit:
    Decodable,
    Sendable
{
    let changes: [String: [SourceKitLSPRenameTextEdit]]?
    let documentChanges: [SourceKitLSPRenameDocumentChange]?
    let changeAnnotations: [String: SourceKitLSPOpaqueValue]?
}
