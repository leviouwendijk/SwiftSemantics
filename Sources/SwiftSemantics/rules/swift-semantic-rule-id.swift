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
}
