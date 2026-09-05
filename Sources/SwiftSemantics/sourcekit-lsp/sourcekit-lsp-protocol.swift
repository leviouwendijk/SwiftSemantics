import Foundation

/// JSON-RPC request identifiers used internally by the SourceKit-LSP adapter.
enum SourceKitLSPMessageID:
    Sendable,
    Hashable,
    Codable
{
    case integer(Int)
    case string(String)

    init(
        from decoder: Decoder
    ) throws {
        let container = try decoder.singleValueContainer()

        if let value = try? container.decode(
            Int.self
        ) {
            self = .integer(
                value
            )
            return
        }

        if let value = try? container.decode(
            String.self
        ) {
            self = .string(
                value
            )
            return
        }

        throw DecodingError.typeMismatch(
            SourceKitLSPMessageID.self,
            .init(
                codingPath: decoder.codingPath,
                debugDescription: "JSON-RPC id must be an integer or string."
            )
        )
    }

    func encode(
        to encoder: Encoder
    ) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .integer(let value):
            try container.encode(
                value
            )

        case .string(let value):
            try container.encode(
                value
            )
        }
    }
}

struct SourceKitLSPRequest<Params: Encodable>:
    Encodable
{
    let jsonrpc = "2.0"
    let id: SourceKitLSPMessageID
    let method: String
    let params: Params
}

struct SourceKitLSPRequestWithoutParams:
    Encodable
{
    let jsonrpc = "2.0"
    let id: SourceKitLSPMessageID
    let method: String
}

struct SourceKitLSPNotification<Params: Encodable>:
    Encodable
{
    let jsonrpc = "2.0"
    let method: String
    let params: Params
}

struct SourceKitLSPNotificationWithoutParams:
    Encodable
{
    let jsonrpc = "2.0"
    let method: String
}

struct SourceKitLSPIncomingEnvelope:
    Decodable,
    Sendable
{
    let id: SourceKitLSPMessageID?
    let method: String?
}

struct SourceKitLSPResponseError:
    Decodable,
    Sendable
{
    let code: Int
    let message: String
}

struct SourceKitLSPResponse<Result: Decodable>:
    Decodable
{
    let result: Result?
    let error: SourceKitLSPResponseError?
}

struct SourceKitLSPResponseStatus:
    Decodable
{
    let error: SourceKitLSPResponseError?
}

struct SourceKitLSPServerErrorResponse:
    Encodable
{
    struct Payload:
        Encodable
    {
        let code: Int
        let message: String
    }

    let jsonrpc = "2.0"
    let id: SourceKitLSPMessageID
    let error: Payload
}

struct SourceKitLSPInitializeParams:
    Encodable,
    Sendable
{
    struct ClientInfo:
        Encodable,
        Sendable
    {
        let name: String
        let version: String?
    }

    struct WorkspaceFolder:
        Encodable,
        Sendable
    {
        let uri: String
        let name: String
    }

    let processId: Int32
    let clientInfo: ClientInfo
    let rootUri: String
    let capabilities: [String: String]
    let workspaceFolders: [WorkspaceFolder]
}

struct SourceKitLSPInitializeResult:
    Decodable,
    Sendable
{
    struct ServerInfo:
        Decodable,
        Sendable
    {
        let name: String
        let version: String?
    }

    let serverInfo: ServerInfo?
}
