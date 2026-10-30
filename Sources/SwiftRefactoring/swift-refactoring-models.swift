import Foundation

/// An exact source declaration captured without rewriting its implementation.
public struct SwiftRefactoringDeclaration: Sendable {
    public let file: URL
    public let name: String
    public let extendedType: String
    public let utf8Range: Range<Int>
    public let text: String

    public init(
        file: URL,
        name: String,
        extendedType: String,
        utf8Range: Range<Int>,
        text: String
    ) {
        self.file = file.standardizedFileURL
        self.name = name
        self.extendedType = extendedType
        self.utf8Range = utf8Range
        self.text = text
    }
}

/// A baseline-relative UTF-8 source edit. No file I/O occurs here.
public struct SwiftRefactoringEdit: Sendable {
    public let file: URL
    public let utf8Range: Range<Int>
    public let expected: String
    public let replacement: String

    public init(
        file: URL,
        utf8Range: Range<Int>,
        expected: String,
        replacement: String
    ) {
        self.file = file.standardizedFileURL
        self.utf8Range = utf8Range
        self.expected = expected
        self.replacement = replacement
    }
}

public enum SwiftRefactoringError: Error, Sendable {
    case sourceFileRequired
    case missingDeclaration
    case ambiguousDeclaration
    case missingDestination
    case conflictingMember
    case sameContainer
    case conditionalOrConformingExtension
    case fileScopedAccess
    case inconsistentSnapshots
    case staleSource(URL)
    case invalidEdit(URL)
    case overlappingEdits(URL)
    case invalidUTF8(URL)
    case invalidSyntax(URL)
}

/// A read-only source transformation plan. Publication belongs to the caller.
/// A successful preview proves baseline consistency and edit applicability,
/// not semantic equivalence or successful compilation. Consumers must validate
/// the transformed package before publishing mutations.
public struct SwiftRefactoringPlan: Sendable {
    public let declaration: SwiftRefactoringDeclaration
    public let destination: URL
    public let edits: [SwiftRefactoringEdit]
    public let baselines: [URL: String]

    public init(
        declaration: SwiftRefactoringDeclaration,
        destination: URL,
        edits: [SwiftRefactoringEdit],
        baselines: [URL: String]
    ) {
        self.declaration = declaration
        self.destination = destination.standardizedFileURL
        self.edits = edits
        self.baselines = baselines
    }

    /// Preview exact source changes only if every affected document still matches its baseline.
    public func preview(sources: [URL: String]) throws -> [URL: String] {
        var output: [URL: String] = [:]
        let groups = Dictionary(grouping: edits, by: \.file)

        for (file, entries) in groups {
            guard let baseline = baselines[file], sources[file] == baseline else {
                throw SwiftRefactoringError.staleSource(file)
            }

            output[file] = try SwiftRefactoringEditApplicator.apply(
                entries,
                to: baseline,
                in: file
            )
        }

        return output
    }
}
