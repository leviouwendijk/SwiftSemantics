import Foundation

/// Incrementally reconstructs Language Server Protocol messages from arbitrary
/// stdout byte chunks.
///
/// Process stdout chunk boundaries have no relationship to LSP packet
/// boundaries. The framer therefore buffers bytes until it has a complete
/// header and the exact Content-Length body declared by that header.
struct SourceKitLSPMessageFramer:
    Sendable
{
    private static let headerSeparator =
        Data(
            "\r\n\r\n".utf8
        )

    private static let maximumHeaderBytes =
        64 * 1024

    private static let maximumMessageBytes =
        64 * 1024 * 1024

    private var buffer = Data()

    mutating func append(
        _ chunk: Data
    ) throws -> [Data] {
        buffer.append(
            chunk
        )

        var messages: [Data] = []

        while true {
            guard let headerRange = buffer.range(
                of: Self.headerSeparator
            ) else {
                guard buffer.count <= Self.maximumHeaderBytes else {
                    throw SwiftSemanticCompilerError.protocolViolation(
                        "LSP header exceeded \(Self.maximumHeaderBytes) bytes."
                    )
                }

                break
            }

            let headerData = buffer.subdata(
                in: buffer.startIndex..<headerRange.lowerBound
            )

            let contentLength = try Self.contentLength(
                in: headerData
            )

            guard contentLength <= Self.maximumMessageBytes else {
                throw SwiftSemanticCompilerError.protocolViolation(
                    "LSP message declared \(contentLength) bytes, exceeding the \(Self.maximumMessageBytes)-byte safety limit."
                )
            }

            let bodyStartOffset = buffer.distance(
                from: buffer.startIndex,
                to: headerRange.upperBound
            )

            let availableBodyBytes = buffer.count
                - bodyStartOffset

            guard availableBodyBytes >= contentLength else {
                break
            }

            let bodyStart = buffer.index(
                buffer.startIndex,
                offsetBy: bodyStartOffset
            )
            let bodyEnd = buffer.index(
                bodyStart,
                offsetBy: contentLength
            )

            messages.append(
                buffer.subdata(
                    in: bodyStart..<bodyEnd
                )
            )

            buffer.removeSubrange(
                buffer.startIndex..<bodyEnd
            )
        }

        return messages
    }
}

private extension SourceKitLSPMessageFramer {
    static func contentLength(
        in headerData: Data
    ) throws -> Int {
        guard let header = String(
            data: headerData,
            encoding: .utf8
        ) else {
            throw SwiftSemanticCompilerError.protocolViolation(
                "LSP header was not valid UTF-8."
            )
        }

        for line in header.components(
            separatedBy: "\r\n"
        ) {
            let parts = line.split(
                separator: ":",
                maxSplits: 1,
                omittingEmptySubsequences: false
            )

            guard parts.count == 2 else {
                continue
            }

            let name = parts[0]
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .lowercased()

            guard name == "content-length" else {
                continue
            }

            let value = parts[1]
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

            guard
                let length = Int(
                    value
                ),
                length >= 0
            else {
                throw SwiftSemanticCompilerError.protocolViolation(
                    "Invalid LSP Content-Length header: \(value)"
                )
            }

            return length
        }

        throw SwiftSemanticCompilerError.protocolViolation(
            "LSP packet did not contain a Content-Length header."
        )
    }
}

enum SourceKitLSPMessageWriter {
    static func frame(
        _ body: Data
    ) -> Data {
        var message = Data(
            "Content-Length: \(body.count)\r\n\r\n".utf8
        )

        message.append(
            body
        )

        return message
    }
}
