import TestFlows

enum SwiftSemanticsFlowSuite:
    TestFlowRegistry
{
    static let title =
        "SwiftSemantics flow tests"

    static let flows: [TestFlow] = [
        packageGraphFlow,
        packageRulesFlow,
        packageDependencyProofFlow,
        importInventoryFlow,
        structuralSemanticsFlow,
        semanticRuleFoundationFlow,
        authoredRulesFlow,
        authoredRuleProofFlow,
        sourceConventionRulesFlow,
        sourceConventionProofFlow,
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
