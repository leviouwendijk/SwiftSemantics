import Foundation

public enum SwiftSemanticWorkspaceSymbolKind:
    Sendable,
    Codable,
    Hashable
{
    case file
    case module
    case namespace
    case package
    case `class`
    case method
    case property
    case field
    case constructor
    case enumCase
    case interface
    case function
    case variable
    case constant
    case string
    case number
    case boolean
    case array
    case object
    case key
    case null
    case enumType
    case `struct`
    case event
    case `operator`
    case typeParameter
    case unknown
}

/// One symbol discovered by the compiler-semantic workspace index.
public struct SwiftSemanticWorkspaceSymbol:
    Sendable,
    Codable,
    Hashable
{
    public let name: String
    public let kind: SwiftSemanticWorkspaceSymbolKind
    public let containerName: String?
    public let location: SwiftSemanticLocation?

    public init(
        name: String,
        kind: SwiftSemanticWorkspaceSymbolKind,
        containerName: String? = nil,
        location: SwiftSemanticLocation? = nil
    ) {
        self.name = name
        self.kind = kind
        self.containerName = containerName
        self.location = location
    }
}
