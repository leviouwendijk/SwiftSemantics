import TestFlows

enum SwiftSemanticsFlowSuite:
    TestFlowRegistry
{
    static let title =
        "SwiftSemantics flow tests"

    static let flows: [TestFlow] = [
        packageGraphFlow,
        importInventoryFlow,
        structuralSemanticsFlow,
        sourceKitLSPSessionFlow,
        sourceKitLSPSemanticsFlow,
    ]
}
