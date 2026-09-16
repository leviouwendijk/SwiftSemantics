import SwiftSyntax

public extension SwiftSemanticRules.API.Surface {
    struct ForbiddenSemanticAPIUsage:
        SwiftSemanticRule
    {
        public let id = SwiftSemanticRuleID.forbiddenSemanticAPIUsage
        public let suppression: SwiftSemanticRuleSuppression = .source_directive

        public init() {}

        public func diagnostics(
            in source: SwiftSemanticSource,
            context: SwiftSemanticRuleContext
        ) async throws -> [SwiftSemanticRuleDiagnostic] {
            guard !context.forbiddenAPIs.isEmpty,
                let file = source.file,
                let resolver = context.symbolResolver else {
                return []
            }

            let visitor = ReferenceVisitor()
            visitor.walk(
                source.syntax
            )

            var diagnostics: [SwiftSemanticRuleDiagnostic] = []

            for reference in visitor.references {
                guard let position = source.compilerPosition(
                    of: reference
                ) else {
                    continue
                }

                let symbols = try await resolver.symbols(
                    in: file,
                    at: position
                )

                for policy in context.forbiddenAPIs
                    where symbols.contains(where: { symbol in
                        matches(
                            symbol,
                            identity: policy.identity
                        )
                    }) {
                    diagnostics.append(
                        .init(
                            ruleID: id,
                            severity: policy.severity,
                            message: "Use of compiler-resolved API '\(reference.baseName.text)' is forbidden here: \(policy.reason)",
                            file: source.file,
                            lineRange: source.lineRange(
                                of: reference
                            )
                        )
                    )
                }
            }

            return diagnostics
        }

        private func matches(
            _ symbol: SwiftSemanticCompilerSymbol,
            identity: SwiftSemanticRuleContext.ForbiddenAPI.Identity
        ) -> Bool {
            switch identity {
            case .usr(let identifier):
                return symbol.identifier == identifier

            case .system(let module, let name):
                guard symbol.systemModuleName == module,
                    let symbolName = symbol.name else {
                    return false
                }

                return symbolName == name
                    || symbolName.hasPrefix(
                        name + "("
                    )
            }
        }

        private final class ReferenceVisitor:
            SyntaxVisitor
        {
            var references: [DeclReferenceExprSyntax] = []

            init() {
                super.init(
                    viewMode: .sourceAccurate
                )
            }

            override func visit(
                _ node: DeclReferenceExprSyntax
            ) -> SyntaxVisitorContinueKind {
                references.append(
                    node
                )
                return .visitChildren
            }
        }
    }
}
