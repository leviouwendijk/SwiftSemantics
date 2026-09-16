import SwiftSyntax

public extension SwiftSemanticRules.Traps {
    struct ForceUnwrap:
        SwiftSemanticRule
    {
        public let id = SwiftSemanticRuleID.forceUnwrap

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
                    message: "Force unwraps are not allowed.",
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
            private(set) var nodes: [ForceUnwrapExprSyntax] = []

            init() {
                super.init(
                    viewMode: .sourceAccurate
                )
            }

            override func visit(
                _ node: ForceUnwrapExprSyntax
            ) -> SyntaxVisitorContinueKind {
                nodes.append(
                    node
                )

                return .visitChildren
            }
        }
    }
}
