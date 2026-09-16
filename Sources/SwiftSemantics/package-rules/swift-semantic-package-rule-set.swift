public enum SwiftSemanticPackageRuleSetError:
    Error,
    Sendable,
    Equatable
{
    case duplicateRuleID(SwiftSemanticRuleID)
}

public struct SwiftSemanticPackageRuleSet:
    Sendable
{
    public let rules: [any SwiftSemanticPackageRule]

    public init() {
        rules = []
    }

    public init(
        rules: [any SwiftSemanticPackageRule]
    ) throws {
        var identifiers: Set<SwiftSemanticRuleID> = []

        for rule in rules {
            guard identifiers.insert(rule.id).inserted else {
                throw SwiftSemanticPackageRuleSetError.duplicateRuleID(
                    rule.id
                )
            }
        }

        self.rules = rules
    }

    public static let empty = Self()
}
