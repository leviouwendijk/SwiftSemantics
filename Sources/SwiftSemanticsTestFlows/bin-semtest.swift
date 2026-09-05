import TestFlows

@main
enum SwiftSemanticsFlowTestMain {
    static func main() async {
        await TestFlowCLI.run(
            suite: SwiftSemanticsFlowSuite.self
        )
    }
}
