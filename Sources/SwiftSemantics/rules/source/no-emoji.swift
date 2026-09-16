public extension SwiftSemanticRules.Source {
    struct NoEmoji:
        SwiftSemanticRule
    {
        public let id = SwiftSemanticRuleID.noEmoji

        public let suppression:
            SwiftSemanticRuleSuppression = .source_directive

        public init() {}

        public func diagnostics(
            in source: SwiftSemanticSource,
            context: SwiftSemanticRuleContext
        ) async throws -> [SwiftSemanticRuleDiagnostic] {
            _ = context

            return RuleSource.lines(
                in: source
            )
            .compactMap { line in
                guard containsEmojiPresentation(
                    line.text
                ) else {
                    return nil
                }

                return .init(
                    ruleID: id,
                    severity: .warning,
                    message:
                        "Do not use emoji characters in source; prefer text or ordinary Unicode symbols.",
                    file: source.file,
                    lineRange: RuleSource.lineRange(
                        for: line,
                        in: source
                    )
                )
            }
        }

        private func containsEmojiPresentation(
            _ text: String
        ) -> Bool {
            text.unicodeScalars.contains { scalar in
                scalar.value == 0xFE0F
                    || scalar.properties.isEmojiPresentation
            }
        }
    }
}
