import TestFlows

enum SwiftSemanticsFlowSuite: TestFlowRegistry {
    static let title = "SwiftSemantics flow tests"

    static let fastFlows: [TestFlow] = [
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
        lintPresentationFlow,
        generatedRuleCatalogFlow,
        callGraphStructureFlow,
        callGraphDifferenceFlow,
        refactoringFlow,
        refactoringRenameFlow,
    ]

    static let compilerFlows: [TestFlow] = [
        refactoringCompilerValidationFlow,
        refactoringPublicationPreparationFlow,
        refactoringPublicationExecutionFlow,
        sourceKitLSPSessionFlow,
        sourceKitLSPSemanticsFlow,
        sourceKitLSPAdvancedSemanticsFlow,
    ]

    static let flows = fastFlows + compilerFlows
}
