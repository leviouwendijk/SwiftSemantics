import Foundation
import SwiftSemantics

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
            let original = Data(current.utf8)
            let edits: [SwiftRefactoringEdit] = try document.edits.map { edit in
                let start = try offset(edit.range.start, in: current, file: file)
                let end = try offset(edit.range.end, in: current, file: file)
                guard start <= end else {
                    throw SwiftRefactoringRenameError.reversedRange(file)
                }
                let range = start..<end
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

    private func offset(
        _ position: SwiftSemanticPosition,
        in source: String,
        file: URL
    ) throws -> Int {
        let lines = source.components(separatedBy: "\n")
        guard position.line > 0,
            position.utf16Column > 0,
            lines.indices.contains(position.line - 1) else {
            throw SwiftRefactoringRenameError.invalidPosition(file)
        }
        let line = lines[position.line - 1]
        let units = line.utf16
        let column = position.utf16Column - 1
        guard column <= units.count else {
            throw SwiftRefactoringRenameError.invalidPosition(file)
        }
        let utf16Index = units.index(units.startIndex, offsetBy: column)
        guard let index = String.Index(utf16Index, within: line) else {
            throw SwiftRefactoringRenameError.invalidPosition(file)
        }
        let preceding = lines.prefix(position.line - 1)
            .reduce(0) { $0 + $1.utf8.count + 1 }
        return preceding + line[..<index].utf8.count
    }
}
