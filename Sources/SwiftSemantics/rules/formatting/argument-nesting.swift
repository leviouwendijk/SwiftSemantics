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
            let visitor = Visitor(
                source: source,
                ruleID: id,
                maximumLineLength: context.configuration.maximumLineLength
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
            private let maximumLineLength: UInt
            private let lines: [RuleSource.Line]

            private(set) var diagnostics:
                [SwiftSemanticRuleDiagnostic] = []

            init(
                source: SwiftSemanticSource,
                ruleID: SwiftSemanticRuleID,
                maximumLineLength: UInt
            ) {
                self.source = source
                self.ruleID = ruleID
                self.maximumLineLength = maximumLineLength
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
                for argument in node.arguments {
                    guard let label = argument.label,
                        let labelLine = source.lineRange(
                            of: label
                        )?.start,
                        let expressionRange = source.lineRange(
                            of: argument.expression
                        ),
                        expressionRange.start > labelLine,
                        expressionRange.start == expressionRange.end,
                        let labelSourceLine = RuleSource.line(
                            labelLine,
                            in: lines
                        ) else {
                        continue
                    }

                    let trailingWhitespace = labelSourceLine.text.reversed().prefix {
                        $0 == " " || $0 == "\t"
                    }.count
                    let combinedLineLength =
                        labelSourceLine.text.count
                        - trailingWhitespace
                        + 1
                        + argument.expression.trimmedDescription.count

                    guard UInt(combinedLineLength) <= maximumLineLength else {
                        continue
                    }

                    diagnostics.append(
                        .init(
                            ruleID: ruleID,
                            severity: .warning,
                            message:
                                "Keep a single-line argument expression attached to its label when the combined line fits within the configured line-length limit.",
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
