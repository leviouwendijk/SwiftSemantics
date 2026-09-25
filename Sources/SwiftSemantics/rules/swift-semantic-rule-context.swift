import Foundation

public struct SwiftSemanticRuleContext:
    Sendable
{
    public struct Configuration:
        Sendable,
        Codable,
        Hashable
    {
        public let maximumSymbolComponents: UInt
        public let maximumNestingLineage: UInt
        public let sharedPrefixFamilySize: UInt
        public let maximumParameterCount: UInt
        public let maximumLineLength: UInt
        public let primitiveParameterClusterSize: UInt
        public let booleanParameterClusterSize: UInt
        public let unrelatedPublicDeclarationCount: UInt
        public let requireSemicolons: Bool

        public init(
            maximumSymbolComponents: UInt = 3,
            maximumNestingLineage: UInt = 4,
            sharedPrefixFamilySize: UInt = 3,
            maximumParameterCount: UInt = 6,
            maximumLineLength: UInt = 120,
            primitiveParameterClusterSize: UInt = 3,
            booleanParameterClusterSize: UInt = 2,
            unrelatedPublicDeclarationCount: UInt = 3,
            requireSemicolons: Bool = false
        ) {
            self.maximumSymbolComponents = maximumSymbolComponents
            self.maximumNestingLineage = maximumNestingLineage
            self.sharedPrefixFamilySize = sharedPrefixFamilySize
            self.maximumParameterCount = maximumParameterCount
            self.maximumLineLength = maximumLineLength
            self.primitiveParameterClusterSize = primitiveParameterClusterSize
            self.booleanParameterClusterSize = booleanParameterClusterSize
            self.unrelatedPublicDeclarationCount = unrelatedPublicDeclarationCount
            self.requireSemicolons = requireSemicolons
        }
    }

    public enum SourceRole:
        String,
        Sendable,
        Codable,
        Hashable
    {
        case unspecified
        case library
        case executable
        case test
    }

    public struct ForbiddenAPI:
        Sendable,
        Codable,
        Hashable
    {
        public enum Identity:
            Sendable,
            Codable,
            Hashable
        {
            case usr(String)
            case system(
                module: String,
                name: String
            )
        }

        public let identity: Identity
        public let severity: SwiftSemanticRuleSeverity
        public let reason: String

        public init(
            identity: Identity,
            severity: SwiftSemanticRuleSeverity = .warning,
            reason: String
        ) {
            self.identity = identity
            self.severity = severity
            self.reason = reason
        }
    }

    public struct DependencySurface:
        Sendable,
        Codable,
        Hashable
    {
        public let forbiddenSymbolIdentifiers: Set<String>
        public let forbiddenSystemModules: Set<String>

        public init(
            forbiddenSymbolIdentifiers: Set<String> = [],
            forbiddenSystemModules: Set<String> = []
        ) {
            self.forbiddenSymbolIdentifiers = forbiddenSymbolIdentifiers
            self.forbiddenSystemModules = forbiddenSystemModules
        }

        public var isEmpty: Bool {
            forbiddenSymbolIdentifiers.isEmpty
                && forbiddenSystemModules.isEmpty
        }
    }

    public protocol SymbolResolving:
        Sendable
    {
        func symbols(
            in file: URL,
            at position: SwiftSemanticPosition
        ) async throws -> [SwiftSemanticCompilerSymbol]
    }

    public let configuration: Configuration
    public let sourceRole: SourceRole
    public let forbiddenAPIs: [ForbiddenAPI]
    public let dependencySurface: DependencySurface
    public let symbolResolver: (any SymbolResolving)?

    public init(
        configuration: Configuration = .init(),
        sourceRole: SourceRole = .unspecified,
        forbiddenAPIs: [ForbiddenAPI] = [],
        dependencySurface: DependencySurface = .init(),
        symbolResolver: (any SymbolResolving)? = nil
    ) {
        self.configuration = configuration
        self.sourceRole = sourceRole
        self.forbiddenAPIs = forbiddenAPIs
        self.dependencySurface = dependencySurface
        self.symbolResolver = symbolResolver
    }
}
