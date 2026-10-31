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

/// Review-only draft. Construction and serialization never perform a build.
/// Compiler validation is available separately; publication policy belongs to the caller.
public struct SwiftRefactoringPublicationDraft: Sendable {
    public let mutationPlan: StandardMutationPlan
    public let snapshot: SwiftRefactoringPublicationSnapshot

    public init(
        mutationPlan: StandardMutationPlan,
        snapshot: SwiftRefactoringPublicationSnapshot
    ) {
        self.mutationPlan = mutationPlan
        self.snapshot = snapshot
    }
}

/// Compiler-validated Writers plan, still not applied. The host must approve
/// and then apply the *same* mutationPlan through its governed execution path.
public struct SwiftRefactoringPublicationPreparation: Sendable {
    public let validation: SwiftRefactoringCompilerValidation
    public let mutationPlan: StandardMutationPlan
    public let snapshot: SwiftRefactoringPublicationSnapshot
}

/// Bridges read-only Swift refactoring into the existing Writers substrate.
/// No project source mutation occurs during preparation.
public struct SwiftRefactoringWritersAdapter: Sendable {
    public init() {}

    /// Creates an authorized Writers review plan without running SwiftPM.
    public func prepareReview(
        _ plan: SwiftRefactoringRenamePlan,
        package: SwiftRefactoringCompilerPackage,
        workspace: WorkspaceWriter
    ) throws -> SwiftRefactoringPublicationDraft {
        let snapshot = SwiftRefactoringPublicationSnapshot(package: package)
        try snapshot.requireCurrent(in: workspace)
        let preview = try plan.preview(sources: package.files)
        let root = package.root.standardizedFileURL

        let documents: [Document] = try plan.baselines.keys
            .sorted { $0.path < $1.path }
            .map { file in
                guard file.pathExtension == "swift" else {
                    throw SwiftRefactoringPublicationError.invalidTarget(file)
                }
                guard let baseline = plan.baselines[file],
                    let revised = preview[file] else {
                    throw SwiftRefactoringPublicationError.missingPreview(file)
                }
                let authorized = try SwiftRefactoringWorkspaceSources.authorize(
                    file,
                    packageRoot: root,
                    in: workspace
                )
                let relative = authorized.presentationPath
                guard relative.hasPrefix("Sources/") else {
                    throw SwiftRefactoringPublicationError.invalidTarget(file)
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
                policy: .existing,
                options: .overwriteWithoutBackup
            )
        }

        let mutationPlan = try workspace.mutations.plan(
            entries,
            metadata: [
                "origin": "swift-refactoring",
                "operation": "rename",
                "verification": "source-snapshot-and-writers",
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

        try snapshot.requireCurrent(in: workspace)
        return .init(mutationPlan: mutationPlan, snapshot: snapshot)
    }

    /// Validate the exact reviewed mutation after human approval.
    public func validate(
        _ draft: SwiftRefactoringPublicationDraft,
        workspace: WorkspaceWriter
    ) async throws -> SwiftRefactoringPublicationPreparation {
        try draft.snapshot.requireCurrent(in: workspace)
        let package = draft.snapshot.package
        var replacements: [URL: String] = [:]

        for planned in draft.mutationPlan.entries {
            guard case .replace_text(let entry) = planned.entry,
                planned.resource == .update,
                entry.target == planned.target,
                entry.policy == .existing,
                entry.content == planned.after.textContent,
                planned.target.pathExtension == "swift" else {
                throw SwiftRefactoringPublicationError.invalidTarget(planned.target)
            }
            let authorized = try SwiftRefactoringWorkspaceSources.authorize(
                planned.target,
                packageRoot: package.root,
                in: workspace
            )
            guard authorized.presentationPath.hasPrefix("Sources/"),
                let baseline = package.files[planned.target],
                planned.before.textContent == baseline,
                replacements[planned.target] == nil else {
                throw SwiftRefactoringPublicationError.staleSource(planned.target)
            }
            replacements[planned.target] = entry.content
        }
        guard !replacements.isEmpty else {
            throw SwiftRefactoringPublicationError.noChanges
        }
        let validation = try await SwiftRefactoringCompilerValidator().validate(
            package: package,
            replacements: replacements
        )
        guard validation.succeeded else {
            throw SwiftRefactoringPublicationError.compilerRejected(
                validation.stdout + "\n" + validation.stderr
            )
        }
        try draft.snapshot.requireCurrent(in: workspace)
        return .init(
            validation: validation,
            mutationPlan: draft.mutationPlan,
            snapshot: draft.snapshot
        )
    }

    /// Compatibility for trusted direct callers; still invokes compiler.
    public func prepare(
        _ plan: SwiftRefactoringRenamePlan,
        package: SwiftRefactoringCompilerPackage,
        workspace: WorkspaceWriter
    ) async throws -> SwiftRefactoringPublicationPreparation {
        let draft = try prepareReview(plan, package: package, workspace: workspace)
        return try await validate(draft, workspace: workspace)
    }
}

private struct Document: Sendable {
    let file: URL
    let relative: String
    let baseline: String
    let revised: String
}
