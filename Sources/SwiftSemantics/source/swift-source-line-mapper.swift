import Position

/// Source-backed SwiftSyntax UTF-8 and semantic coordinate projection.
/// All boundaries are validated against the original source.
struct SwiftSourceLineMapper: Sendable {
    private let map: Position.TextMap

    init(source: String) {
        map = Position.TextMap(source: source)
    }

    /// Structural queries express one-based Unicode-scalar columns.
    func utf8Offset(line: Int, column: Int) -> Int? {
        guard let coordinate = try? Position.Coordinate<Position.Unit.UTF32>(
            line: line,
            column: column
        ), let scalarOffset = try? map.offset(at: coordinate),
            let byteOffset = try? map.convert(scalarOffset, to: Position.Unit.UTF8.self) else {
            return nil
        }
        return byteOffset.offset
    }

    func compilerPosition(atUTF8Offset rawOffset: Int) -> SwiftSemanticPosition? {
        guard let byteOffset = try? Position.Offset<Position.Unit.UTF8>(rawOffset),
            let byteCoordinate: Position.Coordinate<Position.Unit.UTF8> = try? map.coordinate(at: byteOffset),
            let utf16 = try? map.convert(byteCoordinate, to: Position.Unit.UTF16.self) else {
            return nil
        }
        return SwiftSemanticPosition(line: utf16.line, utf16Column: utf16.column)
    }

    func lineRange(startUTF8Offset: Int, endUTF8Offset: Int) -> LineRange? {
        guard endUTF8Offset >= startUTF8Offset,
            let startOffset = try? Position.Offset<Position.Unit.UTF8>(startUTF8Offset),
            let endOffset = try? Position.Offset<Position.Unit.UTF8>(endUTF8Offset),
            let start: Position.Coordinate<Position.Unit.UTF8> = try? map.coordinate(at: startOffset),
            let end: Position.Coordinate<Position.Unit.UTF8> = try? map.coordinate(at: endOffset) else {
            return nil
        }
        // A nonempty half-open range ending at the next line's first column
        // belongs to the preceding line, not the following one.
        let finalLine = endUTF8Offset > startUTF8Offset && end.column == 1
            ? end.line - 1
            : end.line
        return try? LineRange(start: start.line, end: finalLine)
    }
}