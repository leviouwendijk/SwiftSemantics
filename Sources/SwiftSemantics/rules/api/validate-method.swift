import Primitives
import SwiftSyntax

public extension SwiftSemanticRules.API {
    struct ValidateMethod:
        SwiftSemanticRule
    {
        public let id = SwiftSemanticRuleID.validateMethod

        public let suppression:
            SwiftSemanticRuleSuppression = .source_directive

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
                    severity: .warning,
                    message:
                        "Declaration uses a validate API. Check whether validity can instead be established at the parsing or initialization boundary.",
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
            private(set) var nodes: [FunctionDeclSyntax] = []

            init() {
                super.init(
                    viewMode: .sourceAccurate
                )
            }

            override func visit(
                _ node: FunctionDeclSyntax
            ) -> SyntaxVisitorContinueKind {
                let words = Case.convert(
                    node.name.text,
                    to: .snake
                )
                .split(
                    separator: "_"
                )

                if words.contains("validate") {
                    nodes.append(
                        node
                    )
                }

                return .visitChildren
            }
        }
    }
}
