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
        generatedRuleCatalogFlow,
        sourceKitLSPSessionFlow,
        sourceKitLSPSemanticsFlow,
        sourceKitLSPAdvancedSemanticsFlow,
    ]
}
