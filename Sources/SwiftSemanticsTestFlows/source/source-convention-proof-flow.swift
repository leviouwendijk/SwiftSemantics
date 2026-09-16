import SwiftSemantics
import TestFlows

extension SwiftSemanticsFlowSuite {
    static var sourceConventionProofFlow: TestFlow {
        TestFlow(
            "semantic-source-convention-proof-matrix",
            tags: [
                "boundaries",
                "fixtures",
                "formatting",
                "lint",
                "regression",
                "rules",
                "swift-semantics",
            ]
        ) {
            Step(
                "prove indentation boundaries"
            ) {
                let rule = SwiftSemanticRules.Formatting.Indentation()

                try await RuleFixture(
                    source: """
                    func run() {
                        if true {
                            print("value")
                        }
                    }
                    """,
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "zero four and eight space indentation"
                )

                try await RuleFixture(
                    source: "func run() {\n  let value = 1\n}",
                    expectedCount: 1,
                    expectedSeverity: .error
                ).assert(
                    rule,
                    label: "two-space indentation"
                )

                try await RuleFixture(
                    source: "func run() {\n      let value = 1\n}",
                    expectedCount: 1,
                    expectedSeverity: .error
                ).assert(
                    rule,
                    label: "six-space indentation"
                )

                try await RuleFixture(
                    source: "func run() {\n\tlet value = 1\n}",
                    expectedCount: 1,
                    expectedSeverity: .error
                ).assert(
                    rule,
                    label: "tab indentation"
                )

                try await RuleFixture(
                    source: "func run() {\n  // comment-only line\n    let value = 1\n}",
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "comment-only line is not token-bearing"
                )

                try await RuleFixture(
                    source: """
                    let value = foo(
                            first: 1,
                            second: 2
                    )
                    """,
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "multiline continuation using four-space multiples"
                )
            }

            Step(
                "prove vertical argument boundaries"
            ) {
                let rule = SwiftSemanticRules.Formatting.VerticalArguments()

                try await RuleFixture(
                    source: "foo(first: 1, second: 2)",
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "horizontal multiargument call"
                )

                try await RuleFixture(
                    source: "foo(\n    first: 1\n)",
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "single multiline argument"
                )

                try await RuleFixture(
                    source: """
                    foo(
                        first: 1,
                        second: 2
                    )
                    """,
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "fully vertical multiargument call"
                )

                try await RuleFixture(
                    source: """
                    foo(first: 1,
                        second: 2
                    )
                    """,
                    expectedCount: 1,
                    expectedSeverity: .warning
                ).assert(
                    rule,
                    label: "first argument remains on opening line"
                )

                try await RuleFixture(
                    source: """
                    foo(
                        first: 1, second: 2
                    )
                    """,
                    expectedCount: 1,
                    expectedSeverity: .warning
                ).assert(
                    rule,
                    label: "multiple arguments share multiline row"
                )

                try await RuleFixture(
                    source: """
                    foo(
                        first: 1,
                        second: 2)
                    """,
                    expectedCount: 1,
                    expectedSeverity: .warning
                ).assert(
                    rule,
                    label: "closing parenthesis shares final argument line"
                )
            }

            Step(
                "prove argument nesting boundaries"
            ) {
                let rule = SwiftSemanticRules.Formatting.ArgumentNesting()

                try await RuleFixture(
                    source: "foo(value: thing)",
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "label and expression begin together"
                )

                try await RuleFixture(
                    source: """
                    foo(
                        value:
                            thing
                    )
                    """,
                    expectedCount: 1,
                    expectedSeverity: .warning
                ).assert(
                    rule,
                    label: "expression detached below label"
                )

                try await RuleFixture(
                    source: """
                    foo(
                        value:
                            build(thing)
                    )
                    """,
                    expectedCount: 1,
                    expectedSeverity: .warning
                ).assert(
                    rule,
                    label: "single-line call detached below label"
                )

                try await RuleFixture(
                    source: """
                    foo(
                        value:
                            build(
                                thing
                            )
                    )
                    """,
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "multiline call may begin below label"
                )

                try await RuleFixture(
                    source: """
                    foo(
                        items: [
                            1,
                        ]
                    )
                    """,
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "array expression starts beside label"
                )

                try await RuleFixture(
                    source: """
                    foo(
                        value: .init(
                            x: 1
                        )
                    )
                    """,
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "initializer expression starts beside label"
                )

                try await RuleFixture(
                    source: """
                    foo(
                        action: {
                            print("value")
                        }
                    )
                    """,
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "closure expression starts beside label"
                )
            }

            Step(
                "prove closing delimiter boundaries"
            ) {
                let rule = SwiftSemanticRules.Formatting.ClosingDelimiter()

                try await RuleFixture(
                    source: """
                    func run() {
                        foo(
                            first: 1
                        )
                    }
                    """,
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "aligned call closing delimiter"
                )

                try await RuleFixture(
                    source: """
                    func run() {
                        foo(
                            first: 1
                            )
                    }
                    """,
                    expectedCount: 1,
                    expectedSeverity: .warning
                ).assert(
                    rule,
                    label: "misaligned call closing delimiter"
                )

                try await RuleFixture(
                    source: """
                    let values = [
                        1,
                    ]
                    """,
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "aligned array closing delimiter"
                )

                try await RuleFixture(
                    source: """
                    let values = [
                        1,
                        ]
                    """,
                    expectedCount: 1,
                    expectedSeverity: .warning
                ).assert(
                    rule,
                    label: "misaligned array closing delimiter"
                )

                try await RuleFixture(
                    source: """
                    let values = [
                        "key": 1,
                    ]
                    """,
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "aligned dictionary closing delimiter"
                )

                try await RuleFixture(
                    source: """
                    let values = [
                        "key": 1,
                        ]
                    """,
                    expectedCount: 1,
                    expectedSeverity: .warning
                ).assert(
                    rule,
                    label: "misaligned dictionary closing delimiter"
                )

                try await RuleFixture(
                    source: """
                    let value = (
                        1,
                        2
                    )
                    """,
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "aligned tuple closing delimiter"
                )

                try await RuleFixture(
                    source: """
                    let value = (
                        1,
                        2
                        )
                    """,
                    expectedCount: 1,
                    expectedSeverity: .warning
                ).assert(
                    rule,
                    label: "misaligned tuple closing delimiter"
                )

                try await RuleFixture(
                    source: "let values = [1, 2]",
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "single-line delimiter is outside multiline rule"
                )
            }

            Step(
                "prove emoji source boundaries"
            ) {
                let rule = SwiftSemanticRules.Source.NoEmoji()

                try await RuleFixture(
                    source: "let symbols = \"✓ → ─ ×\"",
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "ordinary Unicode symbols remain allowed"
                )

                try await RuleFixture(
                    source: "let dog = \"🐕\"",
                    expectedCount: 1,
                    expectedSeverity: .warning
                ).assert(
                    rule,
                    label: "emoji in string literal"
                )

                try await RuleFixture(
                    source: "// 🐕",
                    expectedCount: 1,
                    expectedSeverity: .warning
                ).assert(
                    rule,
                    label: "emoji in comment"
                )

                try await RuleFixture(
                    source: "let heart = \"♥️\"",
                    expectedCount: 1,
                    expectedSeverity: .warning
                ).assert(
                    rule,
                    label: "variation-selector emoji presentation"
                )

                try await RuleFixture(
                    source: """
                    // swift-semantic:disable-next-line no_emoji
                    let dog = "🐕"
                    """,
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "emoji rule source suppression"
                )
            }
        }
    }
}
