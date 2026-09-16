import SwiftSemantics
import TestFlows

extension SwiftSemanticsFlowSuite {
    static var authoredRuleProofFlow: TestFlow {
        TestFlow(
            "semantic-authored-rule-proof-matrix",
            tags: [
                "boundaries",
                "fixtures",
                "lint",
                "regression",
                "rules",
                "swift-semantics",
            ]
        ) {
            Step(
                "prove force unwrap syntax boundaries"
            ) {
                let rule = SwiftSemanticRules.Traps.ForceUnwrap()

                try await RuleFixture(
                    source: "let value: Int? = 1\nlet output = value!",
                    expectedCount: 1,
                    expectedSeverity: .error
                ).assert(
                    rule,
                    label: "postfix optional force unwrap"
                )

                try await RuleFixture(
                    source: "let flag = true\nlet output = !flag",
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "logical negation"
                )

                try await RuleFixture(
                    source: "let value: Int? = nil\nlet output = value != nil",
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "inequality operator"
                )
            }

            Step(
                "prove forced try syntax boundaries"
            ) {
                let rule = SwiftSemanticRules.Traps.ForceTry()
                let declaration = "func load() throws -> Int { 1 }\n"

                try await RuleFixture(
                    source: declaration + "let value = try! load()",
                    expectedCount: 1,
                    expectedSeverity: .error
                ).assert(
                    rule,
                    label: "forced try"
                )

                try await RuleFixture(
                    source: declaration + "let value = try? load()",
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "optional try"
                )

                try await RuleFixture(
                    source: declaration + "let value = try load()",
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "ordinary try"
                )
            }

            Step(
                "prove trap rules cannot be source-suppressed"
            ) {
                try await RuleFixture(
                    source: """
                    let value: Int? = 1
                    // swift-semantic:disable-next-line force_unwrap
                    let output = value!
                    """,
                    expectedCount: 1,
                    expectedSeverity: .error
                ).assert(
                    SwiftSemanticRules.Traps.ForceUnwrap(),
                    label: "force unwrap suppression forbidden"
                )

                try await RuleFixture(
                    source: """
                    func load() throws -> Int { 1 }
                    // swift-semantic:disable-next-line forced_try
                    let value = try! load()
                    """,
                    expectedCount: 1,
                    expectedSeverity: .error
                ).assert(
                    SwiftSemanticRules.Traps.ForceTry(),
                    label: "forced try suppression forbidden"
                )
            }

            Step(
                "prove redundant String enum raw-value boundaries"
            ) {
                let rule = SwiftSemanticRules.Enums.RedundantStringRawValue()

                try await RuleFixture(
                    source: "enum Mode: String { case active = \"active\" }",
                    expectedCount: 1,
                    expectedSeverity: .warning
                ).assert(
                    rule,
                    label: "identical String raw value"
                )

                try await RuleFixture(
                    source: "enum Mode: String { case source_kit = \"sourceKit\" }",
                    expectedCount: 1,
                    expectedSeverity: .warning
                ).assert(
                    rule,
                    label: "casing-equivalent String raw value"
                )

                try await RuleFixture(
                    source: "enum Method: String { case get = \"GET\" }",
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "external uppercase acronym exemption"
                )

                try await RuleFixture(
                    source: "enum Mode: String { case active = \"enabled\" }",
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "semantically distinct String raw value"
                )

                try await RuleFixture(
                    source: "enum Letter: Character { case a = \"a\" }",
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "Character raw enum is not a String enum"
                )

                try await RuleFixture(
                    source: "enum Code: Int { case one = 1 }",
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "integer raw enum"
                )
            }

            Step(
                "prove validate lexical boundaries"
            ) {
                let rule = SwiftSemanticRules.API.ValidateMethod()

                try await RuleFixture(
                    source: "func validate() {}",
                    expectedCount: 1,
                    expectedSeverity: .warning
                ).assert(
                    rule,
                    label: "validate exact"
                )

                try await RuleFixture(
                    source: "func validateInput() {}",
                    expectedCount: 1,
                    expectedSeverity: .warning
                ).assert(
                    rule,
                    label: "validate lexical component"
                )

                try await RuleFixture(
                    source: "func preValidateValue() {}",
                    expectedCount: 1,
                    expectedSeverity: .warning
                ).assert(
                    rule,
                    label: "validate internal lexical component"
                )

                try await RuleFixture(
                    source: "func validatedInput() {}",
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "validated is not validate"
                )

                try await RuleFixture(
                    source: "func invalidValue() {}",
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "invalid does not contain validate component"
                )
            }

            Step(
                "prove source suppression boundaries"
            ) {
                let rule = SwiftSemanticRules.API.ValidateMethod()

                try await RuleFixture(
                    source: """
                    // swift-semantic:disable-next-line validate_method
                    func validateInput() {}
                    """,
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "disable next line"
                )

                try await RuleFixture(
                    source: """
                    // swift-semantic:disable-next-line no_emoji
                    func validateInput() {}
                    """,
                    expectedCount: 1,
                    expectedSeverity: .warning
                ).assert(
                    rule,
                    label: "unrelated rule ID does not suppress"
                )

                try await RuleFixture(
                    source: """
                    // swift-semantic:ignore validate_method
                    func validateInput() {}
                    """,
                    expectedCount: 1,
                    expectedSeverity: .warning
                ).assert(
                    rule,
                    label: "unknown suppression command ignored"
                )

                try await RuleFixture(
                    source: """
                    // swift-semantic:disable validate_method
                    func validateFirst() {}
                    // swift-semantic:enable validate_method
                    func validateSecond() {}
                    """,
                    expectedCount: 1,
                    expectedSeverity: .warning
                ).assert(
                    rule,
                    label: "disable enable range"
                )

                try await RuleFixture(
                    source: """
                    // swift-semantic:disable-next-line no_emoji,validate_method
                    func validateInput() {}
                    """,
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "comma-separated suppression IDs"
                )
            }
        }
    }
}
