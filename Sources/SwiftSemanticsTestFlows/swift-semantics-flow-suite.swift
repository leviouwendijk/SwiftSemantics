import TestFlows

enum SwiftSemanticsFlowSuite:
    TestFlowRegistry
{
    static let title =
        "SwiftSemantics flow tests"

    static let flows: [TestFlow] = [
        packageGraphFlow,
        packageRulesFlow,
        importInventoryFlow,
        structuralSemanticsFlow,
        semanticRuleFoundationFlow,
        authoredRulesFlow,
        sourceConventionRulesFlow,
        designConventionRulesFlow,
        designConventionProofFlow,
        architectureRulesFlow,
        architectureProofFlow,
        generatedRuleCatalogFlow,
        sourceKitLSPSessionFlow,
        sourceKitLSPSemanticsFlow,
        sourceKitLSPAdvancedSemanticsFlow,
    ]
}
