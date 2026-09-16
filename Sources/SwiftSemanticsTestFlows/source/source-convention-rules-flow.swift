import SwiftSemantics
import TestFlows

extension SwiftSemanticsFlowSuite {
    static var sourceConventionRulesFlow: TestFlow {
        TestFlow(
            "source-convention-rules",
            tags: [
                "formatting",
                "guidelines",
                "lint",
                "rules",
                "source",
                "swift-semantics",
            ]
        ) {
            Step(
                "source convention rule IDs use macro-generated snake-case strings"
            ) {
                try Expect.equal(
                    SwiftSemanticRuleID.indentation.rawValue,
                    "indentation",
                    "indentation rule ID"
                )
                try Expect.equal(
                    SwiftSemanticRuleID.verticalArguments.rawValue,
                    "vertical_arguments",
                    "vertical arguments rule ID"
                )
                try Expect.equal(
                    SwiftSemanticRuleID.argumentNesting.rawValue,
                    "argument_nesting",
                    "argument nesting rule ID"
                )
                try Expect.equal(
                    SwiftSemanticRuleID.closingDelimiter.rawValue,
                    "closing_delimiter",
                    "closing delimiter rule ID"
                )
                try Expect.equal(
                    SwiftSemanticRuleID.noEmoji.rawValue,
                    "no_emoji",
                    "no emoji rule ID"
                )
            }

            Step(
                "enforce four-space token indentation"
            ) {
                let source = SwiftSemanticSource(
                    source: """
                    struct Example {
                      let twoSpaces = 2
                    \tlet tabbed = 3
                        let fourSpaces = 4
                    }
                    """
                )

                let analysis = try await analyzeSourceConventions(
                    source,
                    rules: [
                        SwiftSemanticRules.Formatting.Indentation(),
                    ]
                )

                let found = sourceConventionDiagnostics(
                    in: analysis,
                    ruleID: .indentation
                )

                try Expect.equal(
                    found.count,
                    2,
                    "two-space and tab indentation are rejected"
                )

                try Expect.true(
                    found.allSatisfy { diagnostic in
                        diagnostic.severity == .error
                    },
                    "indentation diagnostics are errors"
                )
            }

            Step(
                "distinguish emoji presentation from ordinary Unicode symbols"
            ) {
                let source = SwiftSemanticSource(
                    source: """
                    let ordinary = "✓ → ─ ×"
                    let dog = "🐕"
                    let heart = "❤️"
                    """
                )

                let analysis = try await analyzeSourceConventions(
                    source,
                    rules: [
                        SwiftSemanticRules.Source.NoEmoji(),
                    ]
                )

                let found = sourceConventionDiagnostics(
                    in: analysis,
                    ruleID: .noEmoji
                )

                try Expect.equal(
                    found.count,
                    2,
                    "emoji presentation is diagnosed while ordinary symbols remain valid"
                )
            }

            Step(
                "reject partially verticalized call arguments"
            ) {
                let source = SwiftSemanticSource(
                    source: """
                    func consume(first: Int, second: Int, third: Int) {}

                    consume(
                        first: 1, second: 2,
                        third: 3
                    )

                    consume(
                        first: 1,
                        second: 2,
                        third: 3
                    )
                    """
                )

                let analysis = try await analyzeSourceConventions(
                    source,
                    rules: [
                        SwiftSemanticRules.Formatting.VerticalArguments(),
                    ]
                )

                try Expect.equal(
                    sourceConventionDiagnostics(
                        in: analysis,
                        ruleID: .verticalArguments
                    ).count,
                    1,
                    "only the partially wrapped call is diagnosed"
                )
            }

            Step(
                "keep argument labels attached to their values"
            ) {
                let source = SwiftSemanticSource(
                    source: """
                    func consume(options: Int, output: Int) {}

                    consume(
                        options:
                            1,
                        output: 2
                    )
                    """
                )

                let analysis = try await analyzeSourceConventions(
                    source,
                    rules: [
                        SwiftSemanticRules.Formatting.ArgumentNesting(),
                    ]
                )

                try Expect.equal(
                    sourceConventionDiagnostics(
                        in: analysis,
                        ruleID: .argumentNesting
                    ).count,
                    1,
                    "the separated label and value are diagnosed"
                )
            }

            Step(
                "align closing delimiters with their opening delimiters"
            ) {
                let invalid = SwiftSemanticSource(
                    source: """
                    func inner(one: Int) -> Int { one }
                    func outer(first: Int, second: Int) -> Int { first + second }

                    let value = outer(
                        first: inner(
                            one: 1
                            ),
                        second: 2
                        )
                    """
                )
                let invalidAnalysis = try await analyzeSourceConventions(
                    invalid,
                    rules: [
                        SwiftSemanticRules.Formatting.ClosingDelimiter(),
                    ]
                )

                try Expect.equal(
                    sourceConventionDiagnostics(
                        in: invalidAnalysis,
                        ruleID: .closingDelimiter
                    ).count,
                    2,
                    "both misaligned closing delimiters are diagnosed"
                )

                let chained = SwiftSemanticSource(
                    source: """
                    let value = source
                        .map(
                            transform
                        )
                    """
                )
                let chainedAnalysis = try await analyzeSourceConventions(
                    chained,
                    rules: [
                        SwiftSemanticRules.Formatting.ClosingDelimiter(),
                    ]
                )

                try Expect.equal(
                    sourceConventionDiagnostics(
                        in: chainedAnalysis,
                        ruleID: .closingDelimiter
                    ).count,
                    0,
                    "a chained call uses the opening parenthesis line rather than the called-expression start"
                )
            }

            Step(
                "source convention warnings remain explicitly suppressible"
            ) {
                let source = SwiftSemanticSource(
                    source: """
                    // swift-semantic:disable-next-line no_emoji
                    let allowedFixture = "🐕"
                    let diagnosed = "🐕"
                    """
                )

                let analysis = try await analyzeSourceConventions(
                    source,
                    rules: [
                        SwiftSemanticRules.Source.NoEmoji(),
                    ]
                )

                try Expect.equal(
                    sourceConventionDiagnostics(
                        in: analysis,
                        ruleID: .noEmoji
                    ).count,
                    1,
                    "only the unsuppressed emoji diagnostic remains"
                )
            }
        }
    }
}

private func analyzeSourceConventions(
    _ source: SwiftSemanticSource,
    rules: [any SwiftSemanticRule]
) async throws -> SwiftSemanticRuleAnalysis {
    let ruleSet = try SwiftSemanticRuleSet(
        rules: rules
    )

    return try await SwiftSemanticRuleAnalyzer(
        ruleSet: ruleSet
    )
    .analyze(
        source
    )
}

private func sourceConventionDiagnostics(
    in analysis: SwiftSemanticRuleAnalysis,
    ruleID: SwiftSemanticRuleID
) -> [SwiftSemanticRuleDiagnostic] {
    analysis.diagnostics.filter { diagnostic in
        diagnostic.ruleID == ruleID
    }
}
