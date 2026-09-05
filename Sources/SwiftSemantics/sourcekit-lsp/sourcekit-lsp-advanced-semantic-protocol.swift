import Foundation

indirect enum SourceKitLSPOpaqueValue:
    Codable,
    Sendable
{
    case null
    case bool(Bool)
    case integer(Int)
    case number(Double)
    case string(String)
    case array([SourceKitLSPOpaqueValue])
    case object([String: SourceKitLSPOpaqueValue])

    init(
        from decoder: Decoder
    ) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
            return
        }

        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
            return
        }

        if let value = try? container.decode(Int.self) {
            self = .integer(value)
            return
        }

        if let value = try? container.decode(Double.self) {
            self = .number(value)
            return
        }

        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }

        if let value = try? container.decode(
            [SourceKitLSPOpaqueValue].self
        ) {
            self = .array(value)
            return
        }

        if let value = try? container.decode(
            [String: SourceKitLSPOpaqueValue].self
        ) {
            self = .object(value)
            return
        }

        throw DecodingError.typeMismatch(
            SourceKitLSPOpaqueValue.self,
            .init(
                codingPath: decoder.codingPath,
                debugDescription: "Unsupported opaque LSP JSON value."
            )
        )
    }

    func encode(
        to encoder: Encoder
    ) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .null:
            try container.encodeNil()

        case .bool(let value):
            try container.encode(value)

        case .integer(let value):
            try container.encode(value)

        case .number(let value):
            try container.encode(value)

        case .string(let value):
            try container.encode(value)

        case .array(let value):
            try container.encode(value)

        case .object(let value):
            try container.encode(value)
        }
    }
}

struct SourceKitLSPSymbolDetails:
    Decodable,
    Sendable
{
    struct ModuleInfo:
        Decodable,
        Sendable
    {
        let moduleName: String
        let groupName: String?
    }

    let name: String?
    let containerName: String?
    let usr: String?
    let bestLocalDeclaration: SourceKitLSPLocation?
    let kind: Int?
    let isDynamic: Bool?
    let isSystem: Bool?
    let receiverUsrs: [String]?
    let systemModule: ModuleInfo?
}

struct SourceKitLSPMarkupContent:
    Decodable,
    Sendable
{
    let kind: String
    let value: String
}

struct SourceKitLSPMarkedString:
    Decodable,
    Sendable
{
    let value: String
    let language: String?

    enum CodingKeys:
        String,
        CodingKey
    {
        case language
        case value
    }

    init(
        from decoder: Decoder
    ) throws {
        let single = try decoder.singleValueContainer()

        if let value = try? single.decode(String.self) {
            self.value = value
            language = nil
            return
        }

        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )

        value = try container.decode(
            String.self,
            forKey: .value
        )
        language = try container.decodeIfPresent(
            String.self,
            forKey: .language
        )
    }
}

struct SourceKitLSPHoverContents:
    Decodable,
    Sendable
{
    let text: String
    let kind: String?

    init(
        from decoder: Decoder
    ) throws {
        let container = try decoder.singleValueContainer()

        if let markup = try? container.decode(
            SourceKitLSPMarkupContent.self
        ) {
            text = markup.value
            kind = markup.kind
            return
        }

        if let value = try? container.decode(String.self) {
            text = value
            kind = nil
            return
        }

        if let values = try? container.decode(
            [SourceKitLSPMarkedString].self
        ) {
            text = values
                .map(\.value)
                .joined(
                    separator: "\n\n"
                )
            kind = values.contains { $0.language != nil }
                ? "markdown"
                : nil
            return
        }

        throw DecodingError.typeMismatch(
            SourceKitLSPHoverContents.self,
            .init(
                codingPath: decoder.codingPath,
                debugDescription: "Unsupported LSP hover contents."
            )
        )
    }
}

struct SourceKitLSPHover:
    Decodable,
    Sendable
{
    let contents: SourceKitLSPHoverContents
    let range: SourceKitLSPRange?
}

struct SourceKitLSPDocumentSymbolParams:
    Encodable,
    Sendable
{
    let textDocument: SourceKitLSPTextDocumentIdentifier
}

struct SourceKitLSPDocumentSymbol:
    Decodable,
    Sendable
{
    let name: String
    let detail: String?
    let kind: Int
    let range: SourceKitLSPRange
    let selectionRange: SourceKitLSPRange
    let children: [SourceKitLSPDocumentSymbol]?
}

struct SourceKitLSPSymbolInformation:
    Decodable,
    Sendable
{
    let name: String
    let kind: Int
    let location: SourceKitLSPLocation
    let containerName: String?
}

struct SourceKitLSPDocumentSymbolResult:
    Decodable,
    Sendable
{
    enum Entry:
        Sendable
    {
        case document(SourceKitLSPDocumentSymbol)
        case information(SourceKitLSPSymbolInformation)
    }

    let entries: [Entry]

    init(
        from decoder: Decoder
    ) throws {
        let container = try decoder.singleValueContainer()

        if let values = try? container.decode(
            [SourceKitLSPDocumentSymbol].self
        ) {
            entries = values.map {
                .document($0)
            }
            return
        }

        let values = try container.decode(
            [SourceKitLSPSymbolInformation].self
        )

        entries = values.map {
            .information($0)
        }
    }
}

struct SourceKitLSPCallHierarchyItem:
    Codable,
    Sendable
{
    let name: String
    let kind: Int
    let detail: String?
    let uri: String
    let range: SourceKitLSPRange
    let selectionRange: SourceKitLSPRange
    let data: SourceKitLSPOpaqueValue?
}

struct SourceKitLSPCallHierarchyIncomingParams:
    Encodable,
    Sendable
{
    let item: SourceKitLSPCallHierarchyItem
}

struct SourceKitLSPCallHierarchyOutgoingParams:
    Encodable,
    Sendable
{
    let item: SourceKitLSPCallHierarchyItem
}

struct SourceKitLSPIncomingCall:
    Decodable,
    Sendable
{
    let from: SourceKitLSPCallHierarchyItem
    let fromRanges: [SourceKitLSPRange]
}

struct SourceKitLSPOutgoingCall:
    Decodable,
    Sendable
{
    let to: SourceKitLSPCallHierarchyItem
    let fromRanges: [SourceKitLSPRange]
}

struct SourceKitLSPTypeHierarchyItem:
    Codable,
    Sendable
{
    let name: String
    let kind: Int
    let detail: String?
    let uri: String
    let range: SourceKitLSPRange
    let selectionRange: SourceKitLSPRange
    let data: SourceKitLSPOpaqueValue?
}

struct SourceKitLSPTypeHierarchyParams:
    Encodable,
    Sendable
{
    let item: SourceKitLSPTypeHierarchyItem
}
