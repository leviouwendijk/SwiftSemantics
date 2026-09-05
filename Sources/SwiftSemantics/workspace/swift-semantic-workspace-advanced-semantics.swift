import Foundation

public extension SwiftSemanticWorkspace {
    /// Resolve compiler identity, including a USR when SourceKit-LSP provides
    /// one, for the symbol at a source position.
    func symbolInfo(
        in file: URL,
        at position: SwiftSemanticPosition
    ) async throws -> [SwiftSemanticCompilerSymbol] {
        let provider = try await compilerProvider()

        return try await provider.symbolInfo(
            in: file,
            at: position
        )
    }

    /// Retrieve compiler-generated hover/type/documentation information.
    func hover(
        in file: URL,
        at position: SwiftSemanticPosition
    ) async throws -> SwiftSemanticHover? {
        let provider = try await compilerProvider()

        return try await provider.hover(
            in: file,
            at: position
        )
    }

    /// Retrieve compiler-aware document symbols, preserving hierarchy when the
    /// provider supplies it.
    func documentSymbols(
        for file: URL
    ) async throws -> [SwiftSemanticDocumentSymbol] {
        let provider = try await compilerProvider()

        return try await provider.documentSymbols(
            for: file
        )
    }

    /// Find callers of the callable declaration at a source position.
    func incomingCalls(
        in file: URL,
        at position: SwiftSemanticPosition
    ) async throws -> [SwiftSemanticIncomingCall] {
        let provider = try await compilerProvider()

        return try await provider.incomingCalls(
            in: file,
            at: position
        )
    }

    /// Find callees referenced by the callable declaration at a source
    /// position.
    func outgoingCalls(
        in file: URL,
        at position: SwiftSemanticPosition
    ) async throws -> [SwiftSemanticOutgoingCall] {
        let provider = try await compilerProvider()

        return try await provider.outgoingCalls(
            in: file,
            at: position
        )
    }

    /// Find direct compiler-semantic supertypes of the type at a position.
    func supertypes(
        in file: URL,
        at position: SwiftSemanticPosition
    ) async throws -> [SwiftSemanticTypeHierarchyItem] {
        let provider = try await compilerProvider()

        return try await provider.supertypes(
            in: file,
            at: position
        )
    }

    /// Find direct compiler-semantic subtypes of the type at a position.
    func subtypes(
        in file: URL,
        at position: SwiftSemanticPosition
    ) async throws -> [SwiftSemanticTypeHierarchyItem] {
        let provider = try await compilerProvider()

        return try await provider.subtypes(
            in: file,
            at: position
        )
    }
}
