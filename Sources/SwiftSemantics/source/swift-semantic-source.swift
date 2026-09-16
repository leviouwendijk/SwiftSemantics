import Foundation
import Position
import SwiftParser
import SwiftSyntax

/// One parsed Swift source representation shared by structural semantic operations.
///
/// `file` is source provenance. Callers may associate prospective source text with
/// a file without requiring that the text has already been written to disk.
public struct SwiftSemanticSource:
    Sendable
{
    public let file: URL?
    public let text: String
    public let syntax: SourceFileSyntax

    let mapper: SwiftSourceLineMapper

    public init(
        source: String
    ) {
        file = nil
        text = source
        syntax = Parser.parse(
            source: source
        )
        mapper = SwiftSourceLineMapper(
            source: source
        )
    }

    public init(
        file: URL,
        source: String
    ) throws {
        let file = file.standardizedFileURL

        guard file.pathExtension == "swift" else {
            throw SwiftSemanticSourceInspectionError.unsupportedFile(
                file.path
            )
        }

        self.file = file
        text = source
        syntax = Parser.parse(
            source: source
        )
        mapper = SwiftSourceLineMapper(
            source: source
        )
    }

    public init(
        file: URL
    ) throws {
        let file = file.standardizedFileURL

        guard file.pathExtension == "swift" else {
            throw SwiftSemanticSourceInspectionError.unsupportedFile(
                file.path
            )
        }

        let source = try String(
            contentsOf: file,
            encoding: .utf8
        )

        try self.init(
            file: file,
            source: source
        )
    }

    public func lineRange(
        of node: some SyntaxProtocol
    ) -> LineRange? {
        mapper.lineRange(
            startUTF8Offset: node
                .positionAfterSkippingLeadingTrivia
                .utf8Offset,
            endUTF8Offset: node
                .endPositionBeforeTrailingTrivia
                .utf8Offset
        )
    }

    public func compilerPosition(
        of node: some SyntaxProtocol
    ) -> SwiftSemanticPosition? {
        let offset = node
            .positionAfterSkippingLeadingTrivia
            .utf8Offset
        let utf8 = text.utf8

        guard offset >= 0,
              offset <= utf8.count else {
            return nil
        }

        let utf8Index = utf8.index(
            utf8.startIndex,
            offsetBy: offset
        )

        guard let index = String.Index(
            utf8Index,
            within: text
        ) else {
            return nil
        }

        let prefix = text[..<index]
        let line = prefix.reduce(1) { partial, character in
            character == "\n"
                ? partial + 1
                : partial
        }
        let lineStart = prefix.lastIndex(
            of: "\n"
        ).map { newline in
            text.index(
                after: newline
            )
        } ?? text.startIndex
        let utf16Column = text[lineStart..<index]
            .utf16
            .count + 1

        return .init(
            line: line,
            utf16Column: utf16Column
        )
    }
}
