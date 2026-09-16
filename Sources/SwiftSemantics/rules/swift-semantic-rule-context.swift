/// Additional semantic context available to authored rules.
///
/// The foundation intentionally starts empty. Package and compiler-semantic
/// context should be added only when concrete rules require those capabilities.
public struct SwiftSemanticRuleContext:
    Sendable,
    Hashable
{
    public init() {}
}
