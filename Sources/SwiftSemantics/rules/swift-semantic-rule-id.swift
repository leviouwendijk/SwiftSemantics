import Macros
import Primitives

public struct SwiftSemanticRuleID:
    StringIdentifier
{
    public let rawValue: String

    public init(
        rawValue: String
    ) {
        self.rawValue = rawValue
    }
}

@StringIdentifiers(casing: .snake)
public extension SwiftSemanticRuleID {
    static var forceUnwrap: Self
    static var forcedTry: Self
    static var redundantStringEnumRawValue: Self
    static var validateMethod: Self
    static var indentation: Self
    static var verticalArguments: Self
    static var argumentNesting: Self
    static var closingDelimiter: Self
    static var noEmoji: Self
    static var forbiddenTargetDependency: Self
    static var forbiddenPackageDependency: Self
    static var excessiveSymbolComponents: Self
    static var sharedSymbolPrefixFamily: Self
    static var redundantNestedTypePrefix: Self
    static var excessiveTypeNesting: Self
    static var publicTupleReturn: Self
    static var publicAnyType: Self
    static var primitiveParameterCluster: Self
    static var booleanParameterCluster: Self
    static var excessiveParameterCount: Self
    static var primaryDeclarationFilename: Self
    static var unrelatedPublicDeclarations: Self
    static var codableStringEnumCaseCasing: Self
    static var libraryPrint: Self
    static var forbiddenSemanticAPIUsage: Self
    static var publicDependencyTypeLeak: Self
    static var targetDependencyLayering: Self
    static var targetDependencyBudget: Self
}
