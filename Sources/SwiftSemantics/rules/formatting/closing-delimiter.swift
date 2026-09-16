import SwiftSyntax

public extension SwiftSemanticRules.Formatting {
    struct ClosingDelimiter:
        SwiftSemanticRule
    {
        public let id = SwiftSemanticRuleID.closingDelimiter

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
            private let lines: [RuleSource.Line]

            private(set) var diagnostics:
                [SwiftSemanticRuleDiagnostic] = []

            init(
                source: SwiftSemanticSource,
                ruleID: SwiftSemanticRuleID
            ) {
                self.source = source
                self.ruleID = ruleID
                lines = RuleSource.lines(
                    in: source
                )

                super.init(
                    viewMode: .sourceAccurate
                )
            }

            override func visit(
                _ node: FunctionCallExprSyntax
            ) -> SyntaxVisitorContinueKind {
                if let opening = node.leftParen,
                    let closing = node.rightParen {
                    inspect(
                        opening: opening,
                        closing: closing,
                        diagnosticNode: Syntax(node)
                    )
                }

                return .visitChildren
            }

            override func visit(
                _ node: ArrayExprSyntax
            ) -> SyntaxVisitorContinueKind {
                inspect(
                    opening: node.leftSquare,
                    closing: node.rightSquare,
                    diagnosticNode: Syntax(node)
                )

                return .visitChildren
            }

            override func visit(
                _ node: DictionaryExprSyntax
            ) -> SyntaxVisitorContinueKind {
                inspect(
                    opening: node.leftSquare,
                    closing: node.rightSquare,
                    diagnosticNode: Syntax(node)
                )

                return .visitChildren
            }

            override func visit(
                _ node: TupleExprSyntax
            ) -> SyntaxVisitorContinueKind {
                inspect(
                    opening: node.leftParen,
                    closing: node.rightParen,
                    diagnosticNode: Syntax(node)
                )

                return .visitChildren
            }

            private func inspect(
                opening: TokenSyntax,
                closing: TokenSyntax,
                diagnosticNode: Syntax
            ) {
                guard let openingLine = source.lineRange(
                    of: opening
                )?.start,
                    let closingLine = source.lineRange(
                        of: closing
                    )?.start,
                    openingLine != closingLine,
                    let openingSourceLine = RuleSource.line(
                        openingLine,
                        in: lines
                    ),
                    let closingSourceLine = RuleSource.line(
                        closingLine,
                        in: lines
                    ) else {
                    return
                }

                let openingIndentation = openingSourceLine.indentation
                let closingIndentation = closingSourceLine.indentation

                guard !openingIndentation.containsTab,
                    !closingIndentation.containsTab,
                    openingIndentation.spaces != closingIndentation.spaces else {
                    return
                }

                diagnostics.append(
                    .init(
                        ruleID: ruleID,
                        severity: .warning,
                        message: "Align a multiline closing delimiter with the indentation level of the opening delimiter.",
                        file: source.file,
                        lineRange: source.lineRange(
                            of: diagnosticNode
                        )
                    )
                )
            }
        }
    }
}
