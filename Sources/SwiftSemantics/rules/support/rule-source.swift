import Position
import SwiftSyntax

enum RuleSource {
    struct Indentation:
        Sendable
    {
        let spaces: Int
        let containsTab: Bool
    }

    struct Line:
        Sendable
    {
        let number: Int
        let text: String
        let startUTF8Offset: Int
        let endUTF8Offset: Int

        var indentation: Indentation {
            var spaces = 0
            var containsTab = false

            for character in text {
                switch character {
                case " ":
                    spaces += 1

                case "\t":
                    containsTab = true

                default:
                    return .init(
                        spaces: spaces,
                        containsTab: containsTab
                    )
                }
            }

            return .init(
                spaces: spaces,
                containsTab: containsTab
            )
        }
    }

    static func lines(
        in source: SwiftSemanticSource
    ) -> [Line] {
        let pieces = source.text.split(
            separator: "\n",
            omittingEmptySubsequences: false
        )

        var offset = 0
        var result: [Line] = []

        result.reserveCapacity(
            pieces.count
        )

        for (index, piece) in pieces.enumerated() {
            let text = String(piece)
            let end = offset + text.utf8.count

            result.append(
                .init(
                    number: index + 1,
                    text: text,
                    startUTF8Offset: offset,
                    endUTF8Offset: end
                )
            )

            offset = end + 1
        }

        return result
    }

    static func line(
        _ number: Int,
        in lines: [Line]
    ) -> Line? {
        guard number > 0,
              number <= lines.count else {
            return nil
        }

        return lines[number - 1]
    }

    static func lineRange(
        for line: Line,
        in source: SwiftSemanticSource
    ) -> LineRange? {
        guard line.endUTF8Offset > line.startUTF8Offset else {
            return nil
        }

        return source.mapper.lineRange(
            startUTF8Offset: line.startUTF8Offset,
            endUTF8Offset: line.endUTF8Offset
        )
    }

    static func tokenLines(
        in source: SwiftSemanticSource
    ) -> Set<Int> {
        Set(
            source.syntax
                .tokens(
                    viewMode: .sourceAccurate
                )
                .compactMap { token in
                    source.lineRange(
                        of: token
                    )?.start
                }
        )
    }
}
