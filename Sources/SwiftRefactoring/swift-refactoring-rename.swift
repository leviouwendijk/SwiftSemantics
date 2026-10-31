import Foundation
import SwiftSemantics
import Position

public enum SwiftRefactoringRenameError: Error, Sendable {
    case emptyProposal
    case unsupportedDocument(URL)
    case missingSnapshot(URL)
    case versionMismatch(URL)
    case inconsistentVersions(URL)
    case invalidPosition(URL)
    case reversedRange(URL)
}

/// An LSP TextDocumentEdit group. The group's UTF-8 offsets refer to the
/// document state at this point in the ordered WorkspaceEdit sequence.
public struct SwiftRefactoringRenameGroup: Sendable {
    public let file: URL
    public let version: Int?
    public let edits: [SwiftRefactoringEdit]
}

/// Read-only, ordered rename. Baselines are the caller-provided exact source
/// snapshots, not files subsequently read or written by this plan.
public struct SwiftRefactoringRenamePlan: Sendable {
    public let groups: [SwiftRefactoringRenameGroup]
    public let baselines: [URL: String]

    public func preview(sources: [URL: String]) throws -> [URL: String] {
        for (file, baseline) in baselines {
            guard sources[file] == baseline else {
                throw SwiftRefactoringError.staleSource(file)
            }
        }

        var staged = baselines
        for group in groups {
            guard let current = staged[group.file] else {
                throw SwiftRefactoringRenameError.missingSnapshot(group.file)
            }
            staged[group.file] = try SwiftRefactoringEditApplicator.apply(
                group.edits,
                to: current,
                in: group.file
            )
        }
        return staged
    }
}

/// Converts a compiler rename proposal to guarded UTF-8 edits without I/O.
/// `sources` is an explicit per-file allowlist and snapshot. Callers must
/// authorize that allowlist before planning or publishing any changes.
public struct SwiftRefactoringRenamePlanner: Sendable {
    public init() {}

    public func plan(
        _ proposal: SwiftSemanticRenameResult,
        sources: [URL: String],
        versions: [URL: Int] = [:]
    ) throws -> SwiftRefactoringRenamePlan {
        guard proposal.documents.contains(where: { !$0.edits.isEmpty }) else {
            throw SwiftRefactoringRenameError.emptyProposal
        }

        var groups: [SwiftRefactoringRenameGroup] = []
        var staged: [URL: String] = [:]
        var baselines: [URL: String] = [:]
        var seen: Set<URL> = []
        var seenVersions: [URL: Int] = [:]

        for document in proposal.documents {
            guard document.uri.isFileURL,
                document.uri.pathExtension == "swift" else {
                throw SwiftRefactoringRenameError.unsupportedDocument(document.uri)
            }
            let file = document.uri.standardizedFileURL
            guard let baseline = sources[file] else {
                throw SwiftRefactoringRenameError.missingSnapshot(file)
            }
            if seen.contains(file) {
                guard seenVersions[file] == document.version else {
                    throw SwiftRefactoringRenameError.inconsistentVersions(file)
                }
            } else {
                seen.insert(file)
                seenVersions[file] = document.version
                baselines[file] = baseline
            }
            if let version = document.version {
                guard versions[file] == version else {
                    throw SwiftRefactoringRenameError.versionMismatch(file)
                }
            }

            let current = staged[file] ?? baseline
            let map = Position.TextMap(source: current)
            let original = Data(current.utf8)
            let edits: [SwiftRefactoringEdit] = try document.edits.map { edit in
                guard let start = try? Position.Coordinate<Position.Unit.UTF16>(
                    line: edit.range.start.line,
                    column: edit.range.start.utf16Column
                ), let end = try? Position.Coordinate<Position.Unit.UTF16>(
                    line: edit.range.end.line,
                    column: edit.range.end.utf16Column
                ) else {
                    throw SwiftRefactoringRenameError.invalidPosition(file)
                }
                guard start <= end else {
                    throw SwiftRefactoringRenameError.reversedRange(file)
                }
                guard let coordinates = try? Position.CoordinateRange(start: start, end: end),
                    let range = try? map.utf8Range(of: coordinates) else {
                    throw SwiftRefactoringRenameError.invalidPosition(file)
                }
                guard let expected = String(
                    data: original.subdata(in: range),
                    encoding: .utf8
                ) else {
                    throw SwiftRefactoringError.invalidUTF8(file)
                }
                return SwiftRefactoringEdit(
                    file: file,
                    utf8Range: range,
                    expected: expected,
                    replacement: edit.newText
                )
            }
            staged[file] = try SwiftRefactoringEditApplicator.apply(
                edits,
                to: current,
                in: file
            )
            groups.append(.init(file: file, version: document.version, edits: edits))
        }

        return SwiftRefactoringRenamePlan(groups: groups, baselines: baselines)
    }

}
