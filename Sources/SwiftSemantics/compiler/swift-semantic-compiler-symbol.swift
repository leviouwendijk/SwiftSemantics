import Foundation

/// Compiler-resolved symbol kind.
///
/// This aliases the existing LSP SymbolKind projection used by workspace symbol
/// search while giving cursor-resolved compiler symbols a semantic name that is
/// not tied to the workspace-search operation.
public typealias SwiftSemanticCompilerSymbolKind =
    SwiftSemanticWorkspaceSymbolKind

/// Compiler-resolved identity for a Swift symbol at a source position.
///
/// Unlike `SwiftSemanticSymbol.id`, which is deliberately structural and
/// source-derived, `identifier` is the compiler USR returned by SourceKit-LSP
/// when one is available.
public struct SwiftSemanticCompilerSymbol:
    Sendable,
    Codable,
    Hashable
{
    public let name: String?
    public let containerName: String?
    public let identifier: String?
    public let kind: SwiftSemanticCompilerSymbolKind?
    public let bestLocalDeclaration: SwiftSemanticLocation?
    public let isDynamic: Bool?
    public let isSystem: Bool?
    public let receiverIdentifiers: [String]
    public let systemModuleName: String?
    public let systemModuleGroupName: String?

    public init(
        name: String? = nil,
        containerName: String? = nil,
        identifier: String? = nil,
        kind: SwiftSemanticCompilerSymbolKind? = nil,
        bestLocalDeclaration: SwiftSemanticLocation? = nil,
        isDynamic: Bool? = nil,
        isSystem: Bool? = nil,
        receiverIdentifiers: [String] = [],
        systemModuleName: String? = nil,
        systemModuleGroupName: String? = nil
    ) {
        self.name = name
        self.containerName = containerName
        self.identifier = identifier
        self.kind = kind
        self.bestLocalDeclaration = bestLocalDeclaration
        self.isDynamic = isDynamic
        self.isSystem = isSystem
        self.receiverIdentifiers = receiverIdentifiers
        self.systemModuleName = systemModuleName
        self.systemModuleGroupName = systemModuleGroupName
    }
}
