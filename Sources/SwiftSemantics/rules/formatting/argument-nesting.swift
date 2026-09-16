import SwiftSyntax

public extension SwiftSemanticRules.Formatting {
    struct ArgumentNesting:
        SwiftSemanticRule
    {
        public let id = SwiftSemanticRuleID.argumentNesting

        public let suppression:
            SwiftSemanticRuleSuppression = .source_directive

        public init() {}

        public func diagnostics(
            in source: SwiftSemanticSource,
            context: SwiftSemanticRuleContext
        ) async throws -> [SwiftSemanticRuleDiagnostic] {
            _ = context

            let visitor = Visitor(
                source: source,
                ruleID: id
            )

            visitor.walk(
                source.syntax
            )

            return visitor.diagnostics
        }

        private final class Visitor:
            SyntaxVisitor
        {
            private let source: SwiftSemanticSource
            private let ruleID: SwiftSemanticRuleID

            private(set) var diagnostics:
                [SwiftSemanticRuleDiagnostic] = []

            init(
                source: SwiftSemanticSource,
                ruleID: SwiftSemanticRuleID
            ) {
                self.source = source
                self.ruleID = ruleID

                super.init(
                    viewMode: .sourceAccurate
                )
            }

            override func visit(
                _ node: FunctionCallExprSyntax
            ) -> SyntaxVisitorContinueKind {
                for argument in node.arguments {
                    guard let label = argument.label,
                          let labelLine = source.lineRange(
                            of: label
                          )?.start,
                          let expressionLine = source.lineRange(
                            of: argument.expression
                          )?.start,
                          expressionLine > labelLine else {
                        continue
                    }

                    diagnostics.append(
                        .init(
                            ruleID: ruleID,
                            severity: .warning,
                            message:
                                "Keep an argument label attached to the expression it introduces; do not add indentation merely beneath the label.",
                            file: source.file,
                            lineRange: source.lineRange(
                                of: argument
                            )
                        )
                    )
                }

                return .visitChildren
            }
        }
    }
}
