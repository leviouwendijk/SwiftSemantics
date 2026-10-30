import Foundation

/// Applies one simultaneous, baseline-relative set of UTF-8 edits in memory.
/// Later edit groups must use the preceding group's output as their input.
enum SwiftRefactoringEditApplicator {
    static func apply(
        _ edits: [SwiftRefactoringEdit],
        to source: String,
        in file: URL
    ) throws -> String {
        let original = Data(source.utf8)
        let sorted = edits.sorted {
            $0.utf8Range.lowerBound < $1.utf8Range.lowerBound
        }
        var lastEnd = 0
        var lastStart: Int?

        for edit in sorted {
            let range = edit.utf8Range
            guard edit.file == file,
                range.lowerBound >= lastEnd,
                range.lowerBound >= 0,
                range.upperBound <= original.count,
                lastStart != range.lowerBound else {
                throw SwiftRefactoringError.overlappingEdits(file)
            }
            guard original.subdata(in: range) == Data(edit.expected.utf8) else {
                throw SwiftRefactoringError.invalidEdit(file)
            }
            lastStart = range.lowerBound
            lastEnd = range.upperBound
        }

        var updated = original
        for edit in sorted.reversed() {
            updated.replaceSubrange(
                edit.utf8Range,
                with: Data(edit.replacement.utf8)
            )
        }
        guard let result = String(data: updated, encoding: .utf8) else {
            throw SwiftRefactoringError.invalidUTF8(file)
        }
        return result
    }
}
