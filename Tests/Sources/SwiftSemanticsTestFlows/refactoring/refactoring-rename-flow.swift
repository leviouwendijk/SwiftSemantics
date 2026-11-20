import Foundation
import SwiftRefactoring
import SwiftSemantics
import Schema
import TestFlows

extension SwiftSemanticsFlowSuite {
    static var refactoringRenameFlow: TestFlow {
        TestFlow("swift-refactoring-rename-plan", tags: ["refactoring", "rename"]) {
            Step("native rename result retains ordered typed schema and transport") {
                let file = URL(fileURLWithPath: "/tmp/rename-schema.swift")
                let proposal = SwiftSemanticRenameResult(documents: [
                    .init(uri: file, version: 7, edits: [
                        .init(range: span(1, 1, 6), newText: "`switch`"),
                    ]),
                    .init(uri: file, version: 7, edits: [
                        .init(range: span(1, 1, 9), newText: "Done"),
                    ]),
                ])
                let restored = try JSONDecoder().decode(
                    SwiftSemanticRenameResult.self,
                    from: JSONEncoder().encode(proposal)
                )
                try Expect.equal(restored, proposal, "native proposal round-trips unchanged")
                try Expect.equal(restored.documents.count, 2, "ordered groups preserved")
                try Expect.equal(restored.documents[0].version, 7, "document version retained")

                func requireSchema<T: JSONSchemaProviding>(_: T.Type) {}
                requireSchema(SwiftSemanticRenameEdit.self)
                requireSchema(SwiftSemanticRenameDocument.self)
                requireSchema(SwiftSemanticRenameResult.self)
            }

            Step("preview cross-file rename without writing files") {
                let declaration = URL(fileURLWithPath: "/tmp/r5b-declaration.swift")
                let usage = URL(fileURLWithPath: "/tmp/r5b-usage.swift")
                let baselines = [
                    declaration: "struct Alpha {}\n",
                    usage: "let value = Alpha()\n",
                ]
                let proposal = SwiftSemanticRenameResult(documents: [
                    .init(uri: declaration, version: nil, edits: [
                        .init(range: span(1, 8, 13), newText: "Beta"),
                    ]),
                    .init(uri: usage, version: nil, edits: [
                        .init(range: span(1, 13, 18), newText: "Beta"),
                    ]),
                ])
                let plan = try SwiftRefactoringRenamePlanner().plan(
                    proposal,
                    sources: baselines
                )
                let preview = try plan.preview(sources: baselines)
                try Expect.equal(preview[declaration], "struct Beta {}\n", "declaration")
                try Expect.equal(preview[usage], "let value = Beta()\n", "usage")
                try Expect.equal(plan.groups.count, 2, "ordered document groups")
            }

            Step("UTF-16 emoji columns convert into exact UTF-8 offsets") {
                let file = URL(fileURLWithPath: "/tmp/r5b-unicode.swift")
                let text = "let a = \"😀\"; Alpha()\n"
                let proposal = SwiftSemanticRenameResult(documents: [
                    .init(uri: file, version: nil, edits: [
                        .init(range: span(1, 15, 20), newText: "Beta"),
                    ]),
                ])
                let plan = try SwiftRefactoringRenamePlanner().plan(
                    proposal,
                    sources: [file: text]
                )
                let preview = try plan.preview(sources: [file: text])
                try Expect.equal(preview[file], "let a = \"😀\"; Beta()\n", "Unicode preview")
                try Expect.equal(plan.groups[0].edits[0].expected, "Alpha", "exact token")
            }

            Step("reject UTF-16 offsets inside surrogate pairs") {
                let file = URL(fileURLWithPath: "/tmp/r5b-surrogate.swift")
                let text = "let a = \"😀\"\n"
                let proposal = SwiftSemanticRenameResult(documents: [
                    .init(uri: file, version: nil, edits: [
                        .init(range: span(1, 11, 12), newText: "X"),
                    ]),
                ])
                var rejected = false
                do {
                    _ = try SwiftRefactoringRenamePlanner().plan(proposal, sources: [file: text])
                } catch SwiftRefactoringRenameError.invalidPosition {
                    rejected = true
                }
                try Expect.true(rejected, "surrogate splitting is rejected")
            }

            Step("preserve CRLF while using LSP line coordinates") {
                let file = URL(fileURLWithPath: "/tmp/r5b-crlf.swift")
                let text = "let x = 0\r\nlet y = Alpha()\r\n"
                let proposal = SwiftSemanticRenameResult(documents: [
                    .init(uri: file, version: nil, edits: [
                        .init(range: span(2, 9, 14), newText: "Beta"),
                    ]),
                ])
                let plan = try SwiftRefactoringRenamePlanner().plan(proposal, sources: [file: text])
                let preview = try plan.preview(sources: [file: text])
                try Expect.equal(preview[file], "let x = 0\r\nlet y = Beta()\r\n", "CRLF")
            }

            Step("preserve standalone CR and reject invalid CRLF interior positions") {
                let file = URL(fileURLWithPath: "/tmp/r5b-cr-standalone.swift")
                let text = "let x = 0\rlet y = Alpha()\r"
                let proposal = SwiftSemanticRenameResult(documents: [
                    .init(uri: file, version: nil, edits: [
                        .init(range: span(2, 9, 14), newText: "Beta"),
                    ]),
                ])
                let plan = try SwiftRefactoringRenamePlanner().plan(proposal, sources: [file: text])
                let preview = try plan.preview(sources: [file: text])
                try Expect.equal(preview[file], "let x = 0\rlet y = Beta()\r", "CR-only line boundaries")

                let crlf = "let x = 0\r\nlet y = Alpha()\r\n"
                let invalid = SwiftSemanticRenameResult(documents: [
                    .init(uri: file, version: nil, edits: [
                        .init(range: span(1, 10, 11), newText: "X"),
                    ]),
                ])
                var rejected = false
                do {
                    _ = try SwiftRefactoringRenamePlanner().plan(invalid, sources: [file: crlf])
                } catch SwiftRefactoringRenameError.invalidPosition {
                    rejected = true
                }
                try Expect.true(rejected, "CRLF terminator interior is not a logical column")
            }

            Step("compiler edit ranges avoid unrelated textual matches after complex Unicode") {
                let file = URL(fileURLWithPath: "/tmp/r5b-semantic-only.swift")
                let prefix = "let glyph = \"👩‍💻\"; "
                let text = prefix + "Alpha()\n// Alpha must stay unchanged\n"
                let start = prefix.utf16.count + 1
                let proposal = SwiftSemanticRenameResult(documents: [
                    .init(uri: file, version: nil, edits: [
                        .init(range: span(1, start, start + 5), newText: "Beta"),
                    ]),
                ])
                let plan = try SwiftRefactoringRenamePlanner().plan(proposal, sources: [file: text])
                let preview = try plan.preview(sources: [file: text])
                try Expect.equal(
                    preview[file],
                    prefix + "Beta()\n// Alpha must stay unchanged\n",
                    "Only compiler-proposed occurrence changes"
                )
                try Expect.equal(
                    plan.groups[0].edits[0].utf8Range.lowerBound,
                    prefix.utf8.count,
                    "Typed UTF-16 position converts to exact UTF-8 byte offset"
                )
            }

            Step("reject zero and out-of-range compiler coordinates") {
                let file = URL(fileURLWithPath: "/tmp/r5b-invalid-coordinates.swift")
                for invalidRange in [span(1, 0, 1), span(2, 1, 2), span(1, 1, 100)] {
                    let proposal = SwiftSemanticRenameResult(documents: [
                        .init(uri: file, version: nil, edits: [
                            .init(range: invalidRange, newText: "Beta"),
                        ]),
                    ])
                    var rejected = false
                    do {
                        _ = try SwiftRefactoringRenamePlanner().plan(
                            proposal,
                            sources: [file: "Alpha\n"]
                        )
                    } catch SwiftRefactoringRenameError.invalidPosition {
                        rejected = true
                    }
                    try Expect.true(rejected, "Invalid UTF-16 coordinate must fail closed")
                }
            }

            Step("preserve repeated document groups and their successive coordinate bases") {
                let file = URL(fileURLWithPath: "/tmp/r5b-sequential.swift")
                let text = "let name = Alpha()\n"
                let proposal = SwiftSemanticRenameResult(documents: [
                    .init(uri: file, version: 5, edits: [
                        .init(range: span(1, 12, 17), newText: "BetaBeta"),
                    ]),
                    .init(uri: file, version: 5, edits: [
                        .init(range: span(1, 12, 20), newText: "Final"),
                    ]),
                ])
                let plan = try SwiftRefactoringRenamePlanner().plan(
                    proposal,
                    sources: [file: text],
                    versions: [file: 5]
                )
                try Expect.equal(plan.groups.count, 2, "groups retained")
                let sequentialPreview = try plan.preview(sources: [file: text])
                try Expect.equal(sequentialPreview[file], "let name = Final()\n", "ordered application")

                var staleRejected = false
                do {
                    _ = try plan.preview(sources: [file: "// changed\n" + text])
                } catch SwiftRefactoringError.staleSource {
                    staleRejected = true
                }
                try Expect.true(staleRejected, "stale baseline rejected")
            }

            Step("reject incompatible version constraints") {
                let file = URL(fileURLWithPath: "/tmp/r5b-version.swift")
                let text = "Alpha\n"
                let proposal = SwiftSemanticRenameResult(documents: [
                    .init(uri: file, version: 2, edits: [
                        .init(range: span(1, 1, 6), newText: "Beta"),
                    ]),
                ])
                var rejected = false
                do {
                    _ = try SwiftRefactoringRenamePlanner().plan(
                        proposal, sources: [file: text], versions: [file: 1]
                    )
                } catch SwiftRefactoringRenameError.versionMismatch {
                    rejected = true
                }
                try Expect.true(rejected, "mismatched document version rejected")
            }

            Step("reject overlapping edits and unknown source documents") {
                let file = URL(fileURLWithPath: "/tmp/r5b-overlap.swift")
                let text = "Alpha Alpha\n"
                let proposal = SwiftSemanticRenameResult(documents: [
                    .init(uri: file, version: nil, edits: [
                        .init(range: span(1, 1, 6), newText: "Beta"),
                        .init(range: span(1, 3, 8), newText: "Beta"),
                    ]),
                ])
                var overlapRejected = false
                do {
                    _ = try SwiftRefactoringRenamePlanner().plan(proposal, sources: [file: text])
                } catch SwiftRefactoringError.overlappingEdits {
                    overlapRejected = true
                }
                try Expect.true(overlapRejected, "overlapping UTF-8 edits rejected")

                var unknownRejected = false
                do {
                    _ = try SwiftRefactoringRenamePlanner().plan(proposal, sources: [:])
                } catch SwiftRefactoringRenameError.missingSnapshot {
                    unknownRejected = true
                }
                try Expect.true(unknownRejected, "proposal cannot extend the supplied source allowlist")
            }
        }
    }

    private static func span(
        _ line: Int,
        _ start: Int,
        _ end: Int
    ) -> SwiftSemanticRange {
        .init(
            start: .init(line: line, utf16Column: start),
            end: .init(line: line, utf16Column: end)
        )
    }
}
