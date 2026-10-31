import Foundation

public extension SwiftSemanticWorkspace {
    /// Wait for pending SourceKit-LSP index work. This is an opt-in, bounded
    /// preparation operation, not proof that all references were discovered.
    func synchronizeIndex(timeoutSeconds: Int = 30) async throws {
        guard (1...120).contains(timeoutSeconds) else {
            throw SwiftSemanticCompilerError.protocolViolation(
                "Index synchronization timeout must be between 1 and 120 seconds."
            )
        }
        let provider = try await compilerProvider()
        try await provider.synchronizeIndex(timeout: .seconds(timeoutSeconds))
    }
}
