import SwiftSemantics
import TestFlows

extension SwiftSemanticsFlowSuite {
    static var generatedRuleCatalogFlow: TestFlow {
        TestFlow(
            "generated-rule-catalog",
            tags: [
                "catalog",
                "generation",
                "lint",
                "rules",
                "swift-semantics",
            ]
        ) {
            Step(
                "generated all rule set is available"
            ) {
                let ruleSet = try SwiftSemanticRuleSet.all

                try Expect.true(
                    !ruleSet.rules.isEmpty,
                    "generated rule catalog contains authored rules"
                )
            }

            Step(
                "generated all rule set runs independent rule namespaces"
            ) {
                let source = SwiftSemanticSource(
                    source: """
                    struct Example {
                      func validateInput() {
                            let dog = "🐕"
                            let value: Int? = 1
                            _ = value!
                        }
                    }
                    """
                )

                let analysis = try await SwiftSemanticRuleAnalyzer(
                    ruleSet: SwiftSemanticRuleSet.all
                )
                .analyze(
                    source
                )

                let identifiers = Set(
                    analysis.diagnostics.map(\.ruleID)
                )

                try Expect.true(
                    identifiers.contains(.indentation),
                    "generated catalog contains Formatting.Indentation"
                )

                try Expect.true(
                    identifiers.contains(.validateMethod),
                    "generated catalog contains API.ValidateMethod"
                )

                try Expect.true(
                    identifiers.contains(.noEmoji),
                    "generated catalog contains Source.NoEmoji"
                )

                try Expect.true(
                    identifiers.contains(.forceUnwrap),
                    "generated catalog contains Traps.ForceUnwrap"
                )
            }
        }
    }
}
