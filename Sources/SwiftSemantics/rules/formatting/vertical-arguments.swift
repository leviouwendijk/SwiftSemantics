import SwiftSyntax

public extension SwiftSemanticRules.Formatting {
    struct VerticalArguments:
        SwiftSemanticRule
    {
        public let id = SwiftSemanticRuleID.verticalArguments

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
                guard node.arguments.count > 1,
                      let leftParen = node.leftParen,
                      let rightParen = node.rightParen,
                      let openingLine = source.lineRange(
                        of: leftParen
                      )?.start,
                      let closingLine = source.lineRange(
                        of: rightParen
                      )?.start,
                      openingLine != closingLine else {
                    return .visitChildren
                }

                let ranges = node.arguments.compactMap { argument in
                    source.lineRange(
                        of: argument
                    )
                }

                guard ranges.count == node.arguments.count else {
                    return .visitChildren
                }

                let starts = ranges.map(\.start)
                let allStartAfterOpening = starts.allSatisfy { line in
                    line > openingLine
                }
                let oneArgumentPerLine = Set(starts).count == starts.count
                let closingAfterArguments = ranges.allSatisfy { range in
                    closingLine > range.end
                }

                guard !allStartAfterOpening
                        || !oneArgumentPerLine
                        || !closingAfterArguments else {
                    return .visitChildren
                }

                diagnostics.append(
                    .init(
                        ruleID: ruleID,
                        severity: .warning,
                        message:
                            "Once a call uses vertical argument layout, put each argument on its own line and close the call after the final argument.",
                        file: source.file,
                        lineRange: source.lineRange(
                            of: node
                        )
                    )
                )

                return .visitChildren
            }
        }
    }
}
