import SwiftSemantics
import TestFlows

extension SwiftSemanticsFlowSuite {
    static var authoredRulesFlow: TestFlow {
        TestFlow(
            "authored-rules",
            tags: [
                "swift-semantics",
                "rules",
                "lint",
                "regression",
            ]
        ) {
            Step(
                "rule IDs use macro-generated snake-case strings"
            ) {
                try Expect.equal(
                    SwiftSemanticRuleID.forceUnwrap.rawValue,
                    "force_unwrap",
                    "force unwrap rule ID"
                )
                try Expect.equal(
                    SwiftSemanticRuleID.forcedTry.rawValue,
                    "forced_try",
                    "forced try rule ID"
                )
                try Expect.equal(
                    SwiftSemanticRuleID.redundantStringEnumRawValue.rawValue,
                    "redundant_string_enum_raw_value",
                    "redundant String enum raw-value rule ID"
                )
                try Expect.equal(
                    SwiftSemanticRuleID.validateMethod.rawValue,
                    "validate_method",
                    "validate method rule ID"
                )
            }

            Step(
                "detect force unwrap and forced try"
            ) {
                let source = SwiftSemanticSource(
                    source: """
                    let optional: Int? = 1
                    let value = optional!

                    func operation() throws {}
                    try! operation()
                    """
                )

                let analysis = try await analyze(
                    source,
                    rules: [
                        SwiftSemanticRules.Traps.ForceUnwrap(),
                        SwiftSemanticRules.Traps.ForceTry(),
                    ]
                )

                try Expect.equal(
                    diagnostics(
                        in: analysis,
                        ruleID: .forceUnwrap
                    ).count,
                    1,
                    "force unwrap diagnostic count"
                )

                try Expect.equal(
                    diagnostics(
                        in: analysis,
                        ruleID: .forcedTry
                    ).count,
                    1,
                    "forced try diagnostic count"
                )

                try Expect.true(
                    analysis.hasErrors,
                    "trap rules emit errors"
                )
            }

            Step(
                "detect redundant String enum raw values"
            ) {
                let source = SwiftSemanticSource(
                    source: """
                    enum Setting: String {
                        case settingParameter = "setting_parameter"
                        case sourceKitLSP = "sourcekit_lsp"
                        case same = "same"
                        case get = "GET"
                        case external = "com.example.external-name"
                        case already_snake
                    }
                    """
                )

                let analysis = try await analyze(
                    source,
                    rules: [
                        SwiftSemanticRules.Enums.RedundantStringRawValue(),
                    ]
                )

                let found = diagnostics(
                    in: analysis,
                    ruleID: .redundantStringEnumRawValue
                )

                try Expect.equal(
                    found.count,
                    3,
                    "only redundant String spellings are diagnosed"
                )

                try Expect.true(
                    found.allSatisfy { diagnostic in
                        diagnostic.severity == .warning
                    },
                    "redundant raw values are warnings"
                )
            }

            Step(
                "validate must be an identifier word"
            ) {
                let source = SwiftSemanticSource(
                    source: """
                    func validate() {}
                    func validateInput() {}
                    func configurationValidate() {}
                    func invalidateCache() {}
                    func revalidate() {}
                    func validation() {}
                    """
                )

                let analysis = try await analyze(
                    source,
                    rules: [
                        SwiftSemanticRules.API.ValidateMethod(),
                    ]
                )

                try Expect.equal(
                    diagnostics(
                        in: analysis,
                        ruleID: .validateMethod
                    ).count,
                    3,
                    "validate matches as a lexical identifier component"
                )
            }

            Step(
                "validate warnings support explicit source suppression"
            ) {
                let source = SwiftSemanticSource(
                    source: """
                    func validateFirst() {}

                    // swift-semantic:disable-next-line validate_method
                    func validateSecond() {}

                    // swift-semantic:disable validate_method
                    func validateThird() {}
                    func validateFourth() {}
                    // swift-semantic:enable validate_method

                    func validateFifth() {}
                    """
                )

                let analysis = try await analyze(
                    source,
                    rules: [
                        SwiftSemanticRules.API.ValidateMethod(),
                    ]
                )

                let found = diagnostics(
                    in: analysis,
                    ruleID: .validateMethod
                )

                try Expect.equal(
                    found.count,
                    2,
                    "suppressed validate diagnostics are removed"
                )

                try Expect.equal(
                    found.compactMap(\.lineRange?.start),
                    [
                        1,
                        11,
                    ],
                    "unsuppressed diagnostics retain source lines"
                )
            }

            Step(
                "trap rules cannot be suppressed"
            ) {
                let source = SwiftSemanticSource(
                    source: """
                    let optional: Int? = 1
                    // swift-semantic:disable-next-line force_unwrap
                    let value = optional!
                    """
                )

                let analysis = try await analyze(
                    source,
                    rules: [
                        SwiftSemanticRules.Traps.ForceUnwrap(),
                    ]
                )

                try Expect.equal(
                    diagnostics(
                        in: analysis,
                        ruleID: .forceUnwrap
                    ).count,
                    1,
                    "forbidden suppression does not hide trap diagnostics"
                )
            }
        }
    }
}

private func analyze(
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

private func diagnostics(
    in analysis: SwiftSemanticRuleAnalysis,
    ruleID: SwiftSemanticRuleID
) -> [SwiftSemanticRuleDiagnostic] {
    analysis.diagnostics.filter { diagnostic in
        diagnostic.ruleID == ruleID
    }
}
