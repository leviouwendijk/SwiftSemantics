import Foundation
import SwiftRefactoring
import Writers

public enum SwiftRefactoringPublicationError: Error, Sendable {
    case missingPreview(URL)
    case invalidTarget(URL)
    case targetMappingMismatch(URL)
    case staleSource(URL)
    case unexpectedSource(URL)
    case noChanges
    case compilerRejected(String)
}

/// A compiler-validated Writers plan, prepared but not applied.
/// Approval and publication remain the responsibility of the host.
public struct SwiftRefactoringPublicationPreparation: Sendable {
    public let validation: SwiftRefactoringCompilerValidation
    public let mutationPlan: StandardMutationPlan
    public let snapshot: SwiftRefactoringPublicationSnapshot
}

/// Bridges read-only Swift refactoring into the existing Writers substrate.
/// No project source mutation occurs during preparation.
public struct SwiftRefactoringWritersAdapter: Sendable {
    public init() {}

    public func prepare(
        _ plan: SwiftRefactoringRenamePlan,
        package: SwiftRefactoringCompilerPackage,
        workspace: WorkspaceWriter
    ) async throws -> SwiftRefactoringPublicationPreparation {
        let snapshot = SwiftRefactoringPublicationSnapshot(package: package)
        try snapshot.requireCurrent(in: workspace)
        let preview = try plan.preview(sources: package.files)
        let root = package.root.standardizedFileURL
        let prefix = root.path + "/"

        let documents: [Document] = try plan.baselines.keys
            .sorted { $0.path < $1.path }
            .map { file in
                guard file.isFileURL,
                    file == file.standardizedFileURL,
                    file.path.hasPrefix(prefix),
                    file.pathExtension == "swift" else {
                    throw SwiftRefactoringPublicationError.invalidTarget(file)
                }
                guard let baseline = plan.baselines[file],
                    let revised = preview[file] else {
                    throw SwiftRefactoringPublicationError.missingPreview(file)
                }

                let relative = String(file.path.dropFirst(prefix.count))
                guard relative.hasPrefix("Sources/") else {
                    throw SwiftRefactoringPublicationError.invalidTarget(file)
                }

                let authorized = try workspace.authorize(relative)
                guard authorized.absoluteURL.resolvingSymlinksInPath()
                    == file.resolvingSymlinksInPath() else {
                    throw SwiftRefactoringPublicationError.targetMappingMismatch(file)
                }

                return Document(
                    file: file,
                    relative: relative,
                    baseline: baseline,
                    revised: revised
                )
            }

        let changes = documents.filter { $0.baseline != $0.revised }
        guard !changes.isEmpty else {
            throw SwiftRefactoringPublicationError.noChanges
        }

        let entries: [WorkspaceMutationEntry] = changes.map { document in
            .replaceText(
                at: document.relative,
                content: document.revised,
                policy: .existing
            )
        }

        let mutationPlan = try workspace.mutations.plan(
            entries,
            metadata: [
                "origin": "swift-refactoring",
                "operation": "rename",
                "verification": "swiftpm-build",
            ]
        )

        guard mutationPlan.entries.count == changes.count else {
            throw SwiftRefactoringPublicationError.noChanges
        }
        for (document, entry) in zip(changes, mutationPlan.entries) {
            guard entry.target == document.file,
                entry.before.textContent == document.baseline,
                entry.after.textContent == document.revised else {
                throw SwiftRefactoringPublicationError.staleSource(document.file)
            }
        }

        let validation = try await SwiftRefactoringCompilerValidator().validate(
            plan,
            package: package
        )
        guard validation.succeeded else {
            throw SwiftRefactoringPublicationError.compilerRejected(
                validation.stdout + "\n" + validation.stderr
            )
        }

        // Compilation may take time. Recheck the complete supplied package snapshot.
        try snapshot.requireCurrent(in: workspace)

        return .init(
            validation: validation,
            mutationPlan: mutationPlan,
            snapshot: snapshot
        )
    }
}

private struct Document: Sendable {
    let file: URL
    let relative: String
    let baseline: String
    let revised: String
}
