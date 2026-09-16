public extension SwiftSemanticRules.Formatting {
    struct Indentation:
        SwiftSemanticRule
    {
        public let id = SwiftSemanticRuleID.indentation

        public init() {}

        public func diagnostics(
            in source: SwiftSemanticSource,
            context: SwiftSemanticRuleContext
        ) async throws -> [SwiftSemanticRuleDiagnostic] {
            _ = context

            let tokenLines = RuleSource.tokenLines(
                in: source
            )

            return RuleSource.lines(
                in: source
            )
            .compactMap { line in
                guard tokenLines.contains(line.number) else {
                    return nil
                }

                let indentation = line.indentation

                let message: String

                if indentation.containsTab {
                    message =
                        "Use spaces rather than tabs for Swift source indentation."
                } else if !indentation.spaces.isMultiple(of: 4) {
                    message =
                        "Use four spaces for each Swift source indentation level."
                } else {
                    return nil
                }

                return .init(
                    ruleID: id,
                    severity: .error,
                    message: message,
                    file: source.file,
                    lineRange: RuleSource.lineRange(
                        for: line,
                        in: source
                    )
                )
            }
        }
    }
}
