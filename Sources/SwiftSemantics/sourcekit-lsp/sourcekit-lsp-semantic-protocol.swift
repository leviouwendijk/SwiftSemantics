import Foundation

struct SourceKitLSPPosition:
    Codable,
    Sendable,
    Hashable
{
    let line: Int
    let character: Int
}

struct SourceKitLSPRange:
    Codable,
    Sendable,
    Hashable
{
    let start: SourceKitLSPPosition
    let end: SourceKitLSPPosition
}

struct SourceKitLSPLocation:
    Codable,
    Sendable,
    Hashable
{
    let uri: String
    let range: SourceKitLSPRange
}

struct SourceKitLSPLocationLink:
    Decodable,
    Sendable
{
    let targetUri: String
    let targetRange: SourceKitLSPRange
    let targetSelectionRange: SourceKitLSPRange
}

struct SourceKitLSPLocationResult:
    Decodable,
    Sendable
{
    let locations: [SourceKitLSPLocation]

    init(
        from decoder: Decoder
    ) throws {
        let container = try decoder.singleValueContainer()

        if let values = try? container.decode(
            [SourceKitLSPLocation].self
        ) {
            locations = values
            return
        }

        if let value = try? container.decode(
            SourceKitLSPLocation.self
        ) {
            locations = [
                value,
            ]
            return
        }

        if let links = try? container.decode(
            [SourceKitLSPLocationLink].self
        ) {
            locations = links.map { link in
                .init(
                    uri: link.targetUri,
                    range: link.targetSelectionRange
                )
            }
            return
        }

        if let link = try? container.decode(
            SourceKitLSPLocationLink.self
        ) {
            locations = [
                .init(
                    uri: link.targetUri,
                    range: link.targetSelectionRange
                ),
            ]
            return
        }

        throw DecodingError.typeMismatch(
            SourceKitLSPLocationResult.self,
            .init(
                codingPath: decoder.codingPath,
                debugDescription: "Expected an LSP Location, Location array, LocationLink, or LocationLink array."
            )
        )
    }
}

struct SourceKitLSPTextDocumentIdentifier:
    Encodable,
    Sendable
{
    let uri: String
}

struct SourceKitLSPTextDocumentPositionParams:
    Encodable,
    Sendable
{
    let textDocument: SourceKitLSPTextDocumentIdentifier
    let position: SourceKitLSPPosition
}

struct SourceKitLSPReferencesParams:
    Encodable,
    Sendable
{
    struct Context:
        Encodable,
        Sendable
    {
        let includeDeclaration: Bool
    }

    let textDocument: SourceKitLSPTextDocumentIdentifier
    let position: SourceKitLSPPosition
    let context: Context
}

struct SourceKitLSPDidOpenParams:
    Encodable,
    Sendable
{
    struct TextDocument:
        Encodable,
        Sendable
    {
        let uri: String
        let languageId: String
        let version: Int
        let text: String
    }

    let textDocument: TextDocument
}

struct SourceKitLSPDidChangeParams:
    Encodable,
    Sendable
{
    struct TextDocument:
        Encodable,
        Sendable
    {
        let uri: String
        let version: Int
    }

    struct ContentChange:
        Encodable,
        Sendable
    {
        let text: String
    }

    let textDocument: TextDocument
    let contentChanges: [ContentChange]
}

struct SourceKitLSPDocumentDiagnosticParams:
    Encodable,
    Sendable
{
    let textDocument: SourceKitLSPTextDocumentIdentifier
}

struct SourceKitLSPDocumentDiagnosticReport:
    Decodable,
    Sendable
{
    let kind: String
    let items: [SourceKitLSPDiagnostic]?
}

struct SourceKitLSPDiagnostic:
    Decodable,
    Sendable
{
    let range: SourceKitLSPRange
    let severity: Int?
    let message: String
    let source: String?
}

struct SourceKitLSPWorkspaceSymbolParams:
    Encodable,
    Sendable
{
    let query: String
}

struct SourceKitLSPWorkspaceSymbolItem:
    Decodable,
    Sendable
{
    struct URIOnlyLocation:
        Decodable,
        Sendable
    {
        let uri: String
    }

    enum Location:
        Sendable
    {
        case full(SourceKitLSPLocation)
        case uri(String)
    }

    let name: String
    let kind: Int
    let containerName: String?
    let location: Location

    enum CodingKeys:
        String,
        CodingKey
    {
        case name
        case kind
        case containerName
        case location
    }

    init(
        from decoder: Decoder
    ) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )

        name = try container.decode(
            String.self,
            forKey: .name
        )
        kind = try container.decode(
            Int.self,
            forKey: .kind
        )
        containerName = try container.decodeIfPresent(
            String.self,
            forKey: .containerName
        )

        if let full = try? container.decode(
            SourceKitLSPLocation.self,
            forKey: .location
        ) {
            location = .full(
                full
            )
            return
        }

        let uriOnly = try container.decode(
            URIOnlyLocation.self,
            forKey: .location
        )

        location = .uri(
            uriOnly.uri
        )
    }
}
