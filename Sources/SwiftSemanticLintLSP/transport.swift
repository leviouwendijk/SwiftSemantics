import Foundation

/// Stdio JSON-RPC framing. Never write anything but LSP packets to stdout.
struct LSPTransport {
    private let input: FileHandle
    private let output: FileHandle

    init(
        input: FileHandle = .standardInput,
        output: FileHandle = .standardOutput
    ) {
        self.input = input
        self.output = output
    }

    func receive() throws -> [String: Any]? {
        let delimiter = Data("\r\n\r\n".utf8)
        var header = Data()
        while !header.suffix(delimiter.count).elementsEqual(delimiter) {
            let byte = input.readData(ofLength: 1)
            if byte.isEmpty {
                if header.isEmpty { return nil }
                throw TransportError.incompleteMessage
            }
            header.append(byte)
            guard header.count <= 16_384 else {
                throw TransportError.headerTooLarge
            }
        }
        header.removeLast(delimiter.count)

        guard let text = String(data: header, encoding: .utf8) else {
            throw TransportError.invalidHeader
        }
        let length = text.components(separatedBy: "\r\n")
            .compactMap { line -> Int? in
                let fields = line.split(separator: ":", maxSplits: 1)
                guard fields.count == 2,
                      fields[0].trimmingCharacters(in: .whitespaces)
                        .lowercased() == "content-length" else { return nil }
                return Int(fields[1].trimmingCharacters(in: .whitespaces))
            }
            .first
        guard let length, length >= 0, length <= 16 * 1024 * 1024 else {
            throw TransportError.invalidLength
        }

        var body = Data()
        while body.count < length {
            let chunk = input.readData(ofLength: min(length - body.count, 64 * 1024))
            guard !chunk.isEmpty else { throw TransportError.incompleteMessage }
            body.append(chunk)
        }
        guard let message = try JSONSerialization.jsonObject(with: body)
            as? [String: Any] else {
            throw TransportError.invalidBody
        }
        return message
    }

    func send(_ message: [String: Any]) throws {
        let body = try JSONSerialization.data(withJSONObject: message)
        let header = Data("Content-Length: \(body.count)\r\n\r\n".utf8)
        output.write(header)
        output.write(body)
    }
}

enum TransportError: Error {
    case incompleteMessage
    case headerTooLarge
    case invalidHeader
    case invalidLength
    case invalidBody
}
