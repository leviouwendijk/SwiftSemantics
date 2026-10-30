import Foundation
import SwiftRefactoring
import SwiftRefactoringWriters
import SwiftSemantics
import TestFlows
import Writers

extension SwiftSemanticsFlowSuite {
    static var refactoringPublicationPreparationFlow: TestFlow {
        TestFlow("swift-refactoring-writers-preparation", tags: ["refactoring", "publication"]) {
            Step("capture selected sources via authorized Paths and Writers reader") {
                let fixture = try publicationFixture()
                defer { try? FileManager.default.removeItem(at: fixture.root) }
                let writer = try WorkspaceWriter(root: fixture.root)
                let sourceFiles = fixture.package.files.keys.filter {
                    $0.pathExtension == "swift"
                }
                let captured = try SwiftRefactoringWorkspaceSources().capture(
                    sourceFiles: sourceFiles,
                    in: writer
                )
                try Expect.equal(
                    captured.files,
                    fixture.package.files,
                    "captured exact package bytes through Writers"
                )
                let restored = SwiftRefactoringPublicationSnapshot(package: captured)
                try restored.requireCurrent(in: writer)
                try Data("public let stable = 2\n".utf8).write(
                    to: fixture.root.appendingPathComponent("Sources/Core/Stable.swift")
                )
                var rejected = false
                do {
                    try restored.requireCurrent(in: writer)
                } catch SwiftRefactoringPublicationError.staleSource {
                    rejected = true
                }
                try Expect.true(rejected, "capture freshness detects unrelated changes")
            }

            Step("prepare compiler-validated Writers changes without publishing") {
                let fixture = try publicationFixture()
                defer { try? FileManager.default.removeItem(at: fixture.root) }

                let plan = try publicationRenamePlan(fixture)
                let writer = try WorkspaceWriter(root: fixture.root)
                let preparation = try await SwiftRefactoringWritersAdapter().prepare(
                    plan,
                    package: fixture.package,
                    workspace: writer
                )

                try Expect.true(
                    preparation.validation.succeeded,
                    "renamed package compiles"
                )
                try Expect.equal(
                    preparation.mutationPlan.entries.count,
                    2,
                    "one Writers mutation per changed document"
                )
                try Expect.equal(
                    preparation.mutationPlan.report.updates,
                    2,
                    "both changes are existing-file replacements"
                )
                try Expect.equal(
                    preparation.mutationPlan.entries[0].after.textContent,
                    "public struct Beta { public init() {} }\n",
                    "planned declaration result"
                )
                try Expect.equal(
                    preparation.mutationPlan.entries[1].after.textContent,
                    "public func instance() -> Beta { Beta() }\n",
                    "planned usage result"
                )
                try Expect.equal(
                    String(contentsOf: fixture.declaration, encoding: .utf8),
                    "public struct Alpha { public init() {} }\n",
                    "declaration remains unchanged on disk"
                )
                try Expect.equal(
                    String(contentsOf: fixture.usage, encoding: .utf8),
                    "public func instance() -> Alpha { Alpha() }\n",
                    "reference remains unchanged on disk"
                )
                try Expect.equal(
                    FileManager.default.fileExists(atPath: preparation.validation.stagedDirectory.path),
                    false,
                    "compiler scratch workspace removed"
                )
            }

            Step("review draft preserves exact Writers plan without compiler execution") {
                let fixture = try publicationFixture()
                defer { try? FileManager.default.removeItem(at: fixture.root) }
                let writer = try WorkspaceWriter(root: fixture.root)
                let adapter = SwiftRefactoringWritersAdapter()
                let draft = try adapter.prepareReview(
                    publicationRenamePlan(fixture),
                    package: fixture.package,
                    workspace: writer
                )
                try Expect.equal(draft.mutationPlan.entries.count, 2, "two review edits")
                try Expect.equal(
                    String(contentsOf: fixture.declaration, encoding: .utf8),
                    "public struct Alpha { public init() {} }\n",
                    "preparation never publishes"
                )

                let serializedPlan = try JSONEncoder().encode(draft.mutationPlan)
                let restoredPlan = try JSONDecoder().decode(
                    StandardMutationPlan.self, from: serializedPlan
                )
                let serializedFiles = try JSONEncoder().encode(draft.snapshot.package.files)
                let restoredFiles = try JSONDecoder().decode(
                    [URL: String].self, from: serializedFiles
                )
                let restoredPackage = try SwiftRefactoringCompilerPackage(
                    root: fixture.root, files: restoredFiles
                )
                let restored = SwiftRefactoringPublicationDraft(
                    mutationPlan: restoredPlan,
                    snapshot: .init(package: restoredPackage)
                )
                let validated = try await adapter.validate(restored, workspace: writer)
                try Expect.true(validated.validation.succeeded, "approved edits compile")
                try Expect.equal(
                    validated.mutationPlan.id,
                    draft.mutationPlan.id,
                    "validation never replans the reviewed mutation"
                )
                try Expect.equal(
                    validated.mutationPlan.entries,
                    draft.mutationPlan.entries,
                    "validation retains the exact reviewed entries"
                )
            }

            Step("post-review drift blocks compiler execution and publication") {
                let fixture = try publicationFixture()
                defer { try? FileManager.default.removeItem(at: fixture.root) }
                let writer = try WorkspaceWriter(root: fixture.root)
                let adapter = SwiftRefactoringWritersAdapter()
                let draft = try adapter.prepareReview(
                    publicationRenamePlan(fixture),
                    package: fixture.package,
                    workspace: writer
                )
                let stable = fixture.root.appendingPathComponent("Sources/Core/Stable.swift")
                try Data("public let stable = 99\n".utf8).write(to: stable)
                var rejected = false
                do {
                    _ = try await adapter.validate(draft, workspace: writer)
                } catch SwiftRefactoringPublicationError.staleSource {
                    rejected = true
                }
                try Expect.true(rejected, "post-review source drift rejected")
                try Expect.equal(
                    String(contentsOf: fixture.declaration, encoding: .utf8),
                    "public struct Alpha { public init() {} }\n",
                    "failed validation never publishes"
                )
            }

            Step("reject disk drift before compiler validation") {
                let fixture = try publicationFixture()
                defer { try? FileManager.default.removeItem(at: fixture.root) }

                let plan = try publicationRenamePlan(fixture)
                try Data("public struct Changed {}\n".utf8).write(
                    to: fixture.declaration
                )

                var rejected = false
                do {
                    _ = try await SwiftRefactoringWritersAdapter().prepare(
                        plan,
                        package: fixture.package,
                        workspace: WorkspaceWriter(root: fixture.root)
                    )
                } catch SwiftRefactoringPublicationError.staleSource {
                    rejected = true
                }
                try Expect.true(rejected, "stale disk baseline is rejected")
                try Expect.equal(
                    String(contentsOf: fixture.declaration, encoding: .utf8),
                    "public struct Changed {}\n",
                    "adapter never overwrites external changes"
                )
            }
            Step("reject changed manifest and untouched Swift source before compiling") {
                let fixture = try publicationFixture()
                defer { try? FileManager.default.removeItem(at: fixture.root) }
                let manifest = fixture.root.appendingPathComponent("Package.swift")
                let originalManifest = try Data(contentsOf: manifest)
                let untouched = fixture.root.appendingPathComponent("Sources/Core/Stable.swift")
                let originalUntouched = try Data(contentsOf: untouched)
                let writer = try WorkspaceWriter(root: fixture.root)
                let plan = try publicationRenamePlan(fixture)

                try Data("// drift\n".utf8).write(to: manifest)
                var manifestRejected = false
                do {
                    _ = try await SwiftRefactoringWritersAdapter().prepare(
                        plan, package: fixture.package, workspace: writer
                    )
                } catch SwiftRefactoringPublicationError.staleSource {
                    manifestRejected = true
                }
                try Expect.true(manifestRejected, "changed Package.swift rejects preparation")
                try originalManifest.write(to: manifest)

                try Data("public let stable = 2\n".utf8).write(to: untouched)
                var sourceRejected = false
                do {
                    _ = try await SwiftRefactoringWritersAdapter().prepare(
                        plan, package: fixture.package, workspace: writer
                    )
                } catch SwiftRefactoringPublicationError.staleSource {
                    sourceRejected = true
                }
                try Expect.true(sourceRejected, "untouched source drift rejects preparation")
                try originalUntouched.write(to: untouched)
            }

            Step("reject an additional Swift source outside the compiled snapshot") {
                let fixture = try publicationFixture()
                defer { try? FileManager.default.removeItem(at: fixture.root) }
                let added = fixture.root.appendingPathComponent("Sources/Core/Extra.swift")
                try Data("public let extra = 1\n".utf8).write(to: added)

                var rejected = false
                do {
                    _ = try await SwiftRefactoringWritersAdapter().prepare(
                        publicationRenamePlan(fixture),
                        package: fixture.package,
                        workspace: WorkspaceWriter(root: fixture.root)
                    )
                } catch SwiftRefactoringPublicationError.unexpectedSource {
                    rejected = true
                }
                try Expect.true(rejected, "new Swift source rejects incomplete snapshot")
            }

            Step("retain package freshness checks across the approval interval") {
                let fixture = try publicationFixture()
                defer { try? FileManager.default.removeItem(at: fixture.root) }
                let writer = try WorkspaceWriter(root: fixture.root)
                let preparation = try await SwiftRefactoringWritersAdapter().prepare(
                    publicationRenamePlan(fixture),
                    package: fixture.package,
                    workspace: writer
                )
                let serializedFiles = try JSONEncoder().encode(
                    preparation.snapshot.package.files
                )
                let restoredFiles = try JSONDecoder().decode(
                    [URL: String].self,
                    from: serializedFiles
                )
                let restoredPackage = try SwiftRefactoringCompilerPackage(
                    root: fixture.root,
                    files: restoredFiles
                )
                let restoredSnapshot = SwiftRefactoringPublicationSnapshot(
                    package: restoredPackage
                )
                try restoredSnapshot.requireCurrent(in: writer)

                let serializedPlan = try JSONEncoder().encode(
                    preparation.mutationPlan
                )
                let restoredPlan = try JSONDecoder().decode(
                    StandardMutationPlan.self,
                    from: serializedPlan
                )
                try Expect.equal(
                    restoredPlan.id,
                    preparation.mutationPlan.id,
                    "serialized Writers plan preserves identity"
                )
                try Expect.equal(
                    restoredPlan.entries,
                    preparation.mutationPlan.entries,
                    "serialized Writers plan preserves exact entries"
                )

                let stable = fixture.root.appendingPathComponent("Sources/Core/Stable.swift")
                try Data("public let stable = 3\n".utf8).write(to: stable)
                var rejected = false
                do {
                    try restoredSnapshot.requireCurrent(in: writer)
                } catch SwiftRefactoringPublicationError.staleSource {
                    rejected = true
                }
                try Expect.true(rejected, "post-validation drift is detected")
                try Expect.equal(
                    String(contentsOf: fixture.declaration, encoding: .utf8),
                    "public struct Alpha { public init() {} }\n",
                    "freshness guard never publishes any changes"
                )
            }
        }
    }

    static var refactoringPublicationExecutionFlow: TestFlow {
        TestFlow("swift-refactoring-coordinated-publication", tags: ["refactoring", "publication", "rollback"]) {
            Step("publish the exact prepared plan and roll it back") {
                let fixture = try publicationFixture()
                defer { try? FileManager.default.removeItem(at: fixture.root) }

                let writer = try WorkspaceWriter(root: fixture.root)
                let plan = try publicationRenamePlan(fixture)
                let preparation = try await SwiftRefactoringWritersAdapter().prepare(
                    plan,
                    package: fixture.package,
                    workspace: writer
                )

                let coordinator = StandardMutationCoordinator()
                let participant = await coordinator.participant(name: "swift-refactoring")
                let submission = try await participant.submit(preparation.mutationPlan)
                try Expect.equal(
                    submission.plan.id,
                    preparation.mutationPlan.id,
                    "prepared plan identity preserved"
                )

                let candidate = try await coordinator.publish()
                let publication = try Expect.notNil(candidate, "publication exists")
                try Expect.equal(publication.result.status, .applied, "publication applied")
                try Expect.equal(
                    publication.result.plan.id,
                    preparation.mutationPlan.id,
                    "publication uses approved plan unchanged"
                )
                try Expect.equal(publication.result.records.count, 2, "two mutation records")
                try Expect.equal(
                    String(contentsOf: fixture.declaration, encoding: .utf8),
                    "public struct Beta { public init() {} }\n",
                    "declaration published"
                )
                try Expect.equal(
                    String(contentsOf: fixture.usage, encoding: .utf8),
                    "public func instance() -> Beta { Beta() }\n",
                    "reference published"
                )

                let recorded = await coordinator.publication(publication.result.id)
                let journalEntry = try Expect.notNil(recorded, "publication retained in journal")
                try Expect.equal(
                    journalEntry.result.plan.id,
                    preparation.mutationPlan.id,
                    "journal preserves original plan"
                )
                try Expect.equal(journalEntry.contributions.count, 1, "source attribution retained")

                let rollback = try await coordinator.rollback(
                    publication_id: publication.result.id
                )
                try Expect.equal(rollback.status, .applied, "rollback applied")
                try Expect.equal(
                    String(contentsOf: fixture.declaration, encoding: .utf8),
                    "public struct Alpha { public init() {} }\n",
                    "declaration restored"
                )
                try Expect.equal(
                    String(contentsOf: fixture.usage, encoding: .utf8),
                    "public func instance() -> Alpha { Alpha() }\n",
                    "reference restored"
                )
                let rollbackJournal = await coordinator.rollback_journal()
                try Expect.equal(rollbackJournal.count, 1, "rollback journal retained")
            }

            Step("reject drift between preparation and publication") {
                let fixture = try publicationFixture()
                defer { try? FileManager.default.removeItem(at: fixture.root) }

                let writer = try WorkspaceWriter(root: fixture.root)
                let preparation = try await SwiftRefactoringWritersAdapter().prepare(
                    publicationRenamePlan(fixture),
                    package: fixture.package,
                    workspace: writer
                )
                let coordinator = StandardMutationCoordinator()
                let participant = await coordinator.participant(name: "swift-refactoring")
                _ = try await participant.submit(preparation.mutationPlan)

                try Data("public struct External {}\n".utf8).write(
                    to: fixture.declaration
                )
                var rejected = false
                do {
                    _ = try await coordinator.publish()
                } catch StandardMutationError.drift_detected {
                    rejected = true
                }
                try Expect.true(rejected, "publication rejects stale approved plan")
                try Expect.equal(
                    String(contentsOf: fixture.declaration, encoding: .utf8),
                    "public struct External {}\n",
                    "external change preserved"
                )
                try Expect.equal(
                    String(contentsOf: fixture.usage, encoding: .utf8),
                    "public func instance() -> Alpha { Alpha() }\n",
                    "other document not published"
                )
            }

            Step("reject rollback over later external changes") {
                let fixture = try publicationFixture()
                defer { try? FileManager.default.removeItem(at: fixture.root) }

                let writer = try WorkspaceWriter(root: fixture.root)
                let preparation = try await SwiftRefactoringWritersAdapter().prepare(
                    publicationRenamePlan(fixture),
                    package: fixture.package,
                    workspace: writer
                )
                let coordinator = StandardMutationCoordinator()
                let participant = await coordinator.participant(name: "swift-refactoring")
                _ = try await participant.submit(preparation.mutationPlan)
                let candidate = try await coordinator.publish()
                let publication = try Expect.notNil(candidate, "publication exists")
                try Expect.equal(publication.result.status, .applied, "publication succeeded")

                try Data("public func external() {}\n".utf8).write(
                    to: fixture.usage
                )
                let rollback = try await coordinator.rollback(
                    publication_id: publication.result.id
                )
                try Expect.equal(rollback.status, .failed, "stale rollback rejected")
                try Expect.true(await coordinator.requires_recovery(), "coordinator blocks further publication")
                try Expect.equal(
                    String(contentsOf: fixture.usage, encoding: .utf8),
                    "public func external() {}\n",
                    "external change preserved"
                )
                try Expect.equal(
                    String(contentsOf: fixture.declaration, encoding: .utf8),
                    "public struct Beta { public init() {} }\n",
                    "unrecovered declaration remains visible for reconciliation"
                )
            }
        }
    }

    private static func publicationFixture() throws -> (
        root: URL,
        package: SwiftRefactoringCompilerPackage,
        declaration: URL,
        usage: URL
    ) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("r5d-publication-\(UUID().uuidString)", isDirectory: true)
            .resolvingSymlinksInPath()
            .standardizedFileURL
        let manifest = root.appendingPathComponent("Package.swift")
        let declaration = root.appendingPathComponent("Sources/Core/Declaration.swift")
        let usage = root.appendingPathComponent("Sources/Core/Use.swift")
        let stable = root.appendingPathComponent("Sources/Core/Stable.swift")

        let files: [URL: String] = [
            manifest: """
            // swift-tools-version: 6.0
            import PackageDescription
            let package = Package(
                name: "RenamePublication",
                products: [.library(name: "Core", targets: ["Core"])],
                targets: [.target(name: "Core")]
            )
            """,
            declaration: "public struct Alpha { public init() {} }\n",
            usage: "public func instance() -> Alpha { Alpha() }\n",
            stable: "public let stable = 1\n",
        ]

        try FileManager.default.createDirectory(
            at: declaration.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        for (file, contents) in files {
            try Data(contents.utf8).write(to: file)
        }
        let package = try SwiftRefactoringCompilerPackage(
            root: root,
            files: files
        )
        return (root, package, declaration, usage)
    }

    private static func publicationRenamePlan(
        _ fixture: (
            root: URL,
            package: SwiftRefactoringCompilerPackage,
            declaration: URL,
            usage: URL
        )
    ) throws -> SwiftRefactoringRenamePlan {
        let proposal = SwiftSemanticRenameResult(documents: [
            .init(uri: fixture.declaration, version: nil, edits: [
                .init(range: publicationSpan(15, 20), newText: "Beta"),
            ]),
            .init(uri: fixture.usage, version: nil, edits: [
                .init(range: publicationSpan(27, 32), newText: "Beta"),
                .init(range: publicationSpan(35, 40), newText: "Beta"),
            ]),
        ])
        return try SwiftRefactoringRenamePlanner().plan(
            proposal,
            sources: fixture.package.files
        )
    }

    private static func publicationSpan(_ start: Int, _ end: Int) -> SwiftSemanticRange {
        .init(
            start: .init(line: 1, utf16Column: start),
            end: .init(line: 1, utf16Column: end)
        )
    }
}
