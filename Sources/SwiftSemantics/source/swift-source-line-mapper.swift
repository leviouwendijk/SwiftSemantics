import Position

/// Shared UTF-8 offset to source-line mapping for SwiftSyntax-backed semantic
/// projections.
///
/// SwiftSyntax positions are UTF-8 offsets. Higher semantic APIs intentionally
/// expose stable line ranges rather than leaking syntax-tree positions.
struct SwiftSourceLineMapper:
    Sendable
{
    private let source: String
    let utf8LineStarts: [Int]

    init(
        source: String
    ) {
        self.source = source

        var starts: [Int] = [
            0,
        ]
        var offset = 0

        for scalar in source.unicodeScalars {
            offset += scalar.utf8.count

            if scalar == "\n" {
                starts.append(
                    offset
                )
            }
        }

        utf8LineStarts = starts
    }

    func lineNumber(
        atUTF8Offset offset: Int
    ) -> Int {
        guard !utf8LineStarts.isEmpty else {
            return 1
        }

        var low = 0
        var high = utf8LineStarts.count - 1
        var best = 0

        while low <= high {
            let mid = (low + high) / 2
            let value = utf8LineStarts[mid]

            if value == offset {
                return mid + 1
            }

            if value < offset {
                best = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        return best + 1
    }

    /// Resolve Position-style source coordinates into SwiftSyntax's absolute
    /// UTF-8 offset space.
    ///
    /// Lines and columns are one-based. Columns advance by Unicode scalar,
    /// matching `Position.LineColumnTracker`; the returned offset advances by
    /// each scalar's UTF-8 byte count.
    func utf8Offset(
        line: Int,
        column: Int
    ) -> Int? {
        guard
            line > 0,
            column > 0
        else {
            return nil
        }

        var tracker = LineColumnTracker()
        var utf8Offset = 0

        if tracker.line == line,
           tracker.column == column
        {
            return utf8Offset
        }

        for scalar in source.unicodeScalars {
            utf8Offset += scalar.utf8.count

            tracker.advance(
                over: scalar
            )

            if tracker.line == line,
               tracker.column == column
            {
                return utf8Offset
            }
        }

        return nil
    }

    func lineRange(
        startUTF8Offset: Int,
        endUTF8Offset: Int
    ) -> LineRange? {
        let normalizedEnd = max(
            startUTF8Offset,
            endUTF8Offset - 1
        )

        let startLine = lineNumber(
            atUTF8Offset: startUTF8Offset
        )
        let endLine = lineNumber(
            atUTF8Offset: normalizedEnd
        )

        return try? .init(
            start: startLine,
            end: endLine
        )
    }
}
