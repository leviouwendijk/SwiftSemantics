import SwiftSyntax

public extension SwiftSemanticRules.Formatting {
    struct SemicolonTermination:
        SwiftSemanticRule
    {
        public let id = SwiftSemanticRuleID.semicolonTermination

        public let suppression:
            SwiftSemanticRuleSuppression = .source_directive

        public init() {}

        public func diagnostics(
            in source: SwiftSemanticSource,
            context: SwiftSemanticRuleContext
        ) async throws -> [SwiftSemanticRuleDiagnostic] {
            guard context.configuration.requireSemicolons else {
                return []
            }

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
                _ node: CodeBlockItemSyntax
            ) -> SyntaxVisitorContinueKind {
                inspect(
                    semicolon: node.semicolon,
                    node: Syntax(node)
                )

                return .visitChildren
            }

            override func visit(
                _ node: MemberBlockItemSyntax
            ) -> SyntaxVisitorContinueKind {
                inspect(
                    semicolon: node.semicolon,
                    node: Syntax(node)
                )

                return .visitChildren
            }

            private func inspect(
                semicolon: TokenSyntax?,
                node: Syntax
            ) {
                guard semicolon == nil else {
                    return
                }

                diagnostics.append(
                    .init(
                        ruleID: ruleID,
                        severity: .error,
                        message: "Terminate every declaration or statement item with ';'.",
                        file: source.file,
                        lineRange: source.lineRange(
                            of: node
                        )
                    )
                )
            }
        }
    }
}
