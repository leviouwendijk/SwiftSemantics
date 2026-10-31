import TestFlows

public enum SwiftSemanticsTestRuns {
    public static func all() async {
        await TestFlowCLI.run(suite: SwiftSemanticsFlowSuite.self)
    }

    public static func fast() async {
        await TestFlowCLI.run(suite: SwiftSemanticsFastSuite.self)
    }

    public static func compiler() async {
        await TestFlowCLI.run(suite: SwiftSemanticsCompilerSuite.self)
    }

    public static func rename() async {
        await TestFlowCLI.run(suite: SwiftSemanticsRenameSuite.self)
    }

    public static func validate() async {
        await TestFlowCLI.run(suite: SwiftSemanticsValidationSuite.self)
    }

    public static func prepare() async {
        await TestFlowCLI.run(suite: SwiftSemanticsPreparationSuite.self)
    }

    public static func publish() async {
        await TestFlowCLI.run(suite: SwiftSemanticsPublicationSuite.self)
    }
}

private enum SwiftSemanticsFastSuite: TestFlowRegistry {
    static let title = "SwiftSemantics fast flow tests"
    static let flows = SwiftSemanticsFlowSuite.fastFlows
}

private enum SwiftSemanticsCompilerSuite: TestFlowRegistry {
    static let title = "SwiftSemantics compiler flow tests"
    static let flows = SwiftSemanticsFlowSuite.compilerFlows
}

private enum SwiftSemanticsRenameSuite: TestFlowRegistry {
    static let title = "SwiftSemantics rename integration flow"
    static let flows: [TestFlow] = [
        SwiftSemanticsFlowSuite.refactoringRenameFlow,
        SwiftSemanticsFlowSuite.sourceKitLSPSemanticsFlow,
    ]
}

private enum SwiftSemanticsValidationSuite: TestFlowRegistry {
    static let title = "SwiftSemantics compiler validation flow"
    static let flows: [TestFlow] = [
        SwiftSemanticsFlowSuite.refactoringCompilerValidationFlow,
    ]
}

private enum SwiftSemanticsPreparationSuite: TestFlowRegistry {
    static let title = "SwiftSemantics publication preparation flow"
    static let flows: [TestFlow] = [
        SwiftSemanticsFlowSuite.refactoringPublicationPreparationFlow,
    ]
}

private enum SwiftSemanticsPublicationSuite: TestFlowRegistry {
    static let title = "SwiftSemantics coordinated publication flow"
    static let flows: [TestFlow] = [
        SwiftSemanticsFlowSuite.refactoringPublicationExecutionFlow,
    ]
}
