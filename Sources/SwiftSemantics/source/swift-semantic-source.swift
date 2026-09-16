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
}
