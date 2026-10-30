import Foundation

public extension SwiftSemanticWorkspace {
    /// Request a compiler-resolved rename from the persistent SourceKit-LSP
    /// session. Returns a proposal only; no edits are applied to source files.
    /// A subsequent refactoring layer must validate baselines, ranges, scope,
    /// completeness policy, and the transformed package before publication.
    func rename(
        in file: URL,
        at position: SwiftSemanticPosition,
        to newName: String
    ) async throws -> SwiftSemanticRenameResult {
        let provider = try await compilerProvider()
        return try await provider.rename(
            in: file,
            at: position,
            to: newName
        )
    }
}
