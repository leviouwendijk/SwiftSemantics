import Foundation

extension SwiftSemanticWorkspace:
    SwiftSemanticRuleContext.SymbolResolving
{
    public func symbols(
        in file: URL,
        at position: SwiftSemanticPosition
    ) async throws -> [SwiftSemanticCompilerSymbol] {
        try await symbolInfo(
            in: file,
            at: position
        )
    }
}
