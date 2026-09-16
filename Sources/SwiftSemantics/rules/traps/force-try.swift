import SwiftSyntax

public extension SwiftSemanticRules.Traps {
    struct ForceTry:
        SwiftSemanticRule
    {
        public let id = SwiftSemanticRuleID.forcedTry

        public init() {}

        public func diagnostics(
            in source: SwiftSemanticSource,
            context: SwiftSemanticRuleContext
        ) async throws -> [SwiftSemanticRuleDiagnostic] {
            _ = context

            let visitor = Visitor()

            visitor.walk(
                source.syntax
            )

            return visitor.nodes.map { node in
                .init(
                    ruleID: id,
                    severity: .error,
                    message: "Forced try expressions are not allowed.",
                    file: source.file,
                    lineRange: source.lineRange(
                        of: node
                    )
                )
            }
        }

        private final class Visitor:
            SyntaxVisitor
        {
            private(set) var nodes: [TryExprSyntax] = []

            init() {
                super.init(
                    viewMode: .sourceAccurate
                )
            }

            override func visit(
                _ node: TryExprSyntax
            ) -> SyntaxVisitorContinueKind {
                if node.questionOrExclamationMark?.text == "!" {
                    nodes.append(
                        node
                    )
                }

                return .visitChildren
            }
        }
    }
}
