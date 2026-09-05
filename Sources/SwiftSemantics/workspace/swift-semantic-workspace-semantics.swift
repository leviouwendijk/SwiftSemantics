import Foundation

public extension SwiftSemanticWorkspace {
    /// Resolve the compiler-semantic definition at a source position.
    func definition(
        in file: URL,
        at position: SwiftSemanticPosition
    ) async throws -> [SwiftSemanticLocation] {
        let provider = try await compilerProvider()

        return try await provider.definition(
            in: file,
            at: position
        )
    }

    /// Find compiler-semantic references to the symbol at a source position.
    func references(
        in file: URL,
        at position: SwiftSemanticPosition,
        includeDeclaration: Bool = true
    ) async throws -> [SwiftSemanticLocation] {
        let provider = try await compilerProvider()

        return try await provider.references(
            in: file,
            at: position,
            includeDeclaration: includeDeclaration
        )
    }

    /// Find compiler-semantic implementations of the declaration at a source
    /// position, such as concrete conforming declarations for protocols.
    func implementations(
        in file: URL,
        at position: SwiftSemanticPosition
    ) async throws -> [SwiftSemanticLocation] {
        let provider = try await compilerProvider()

        return try await provider.implementations(
            in: file,
            at: position
        )
    }

    /// Pull current compiler diagnostics for one source file.
    func diagnostics(
        for file: URL
    ) async throws -> [SwiftSemanticDiagnostic] {
        let provider = try await compilerProvider()

        return try await provider.diagnostics(
            for: file
        )
    }

    /// Search the compiler-semantic workspace index for symbols.
    func workspaceSymbols(
        matching query: String
    ) async throws -> [SwiftSemanticWorkspaceSymbol] {
        let provider = try await compilerProvider()

        return try await provider.workspaceSymbols(
            matching: query
        )
    }
}
