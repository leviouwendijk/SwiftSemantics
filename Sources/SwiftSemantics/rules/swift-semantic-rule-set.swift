public enum SwiftSemanticRuleSetError:
    Error,
    Sendable,
    Equatable
{
    case duplicateRuleID(SwiftSemanticRuleID)
}

public struct SwiftSemanticRuleSet:
    Sendable
{
    public let rules: [any SwiftSemanticRule]

    public init() {
        rules = []
    }

    public init(
        rules: [any SwiftSemanticRule]
    ) throws {
        var identifiers: Set<SwiftSemanticRuleID> = []

        for rule in rules {
            guard identifiers.insert(rule.id).inserted else {
                throw SwiftSemanticRuleSetError.duplicateRuleID(
                    rule.id
                )
            }
        }

        self.rules = rules
    }

    public static let empty = Self()
}
