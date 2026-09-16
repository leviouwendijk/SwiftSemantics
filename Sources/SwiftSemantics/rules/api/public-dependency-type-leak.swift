import SwiftSyntax

public extension SwiftSemanticRules.API.Surface {
    struct PublicDependencyTypeLeak:
        SwiftSemanticRule
    {
        public let id = SwiftSemanticRuleID.publicDependencyTypeLeak
        public let suppression: SwiftSemanticRuleSuppression = .source_directive

        public init() {}

        public func diagnostics(
            in source: SwiftSemanticSource,
            context: SwiftSemanticRuleContext
        ) async throws -> [SwiftSemanticRuleDiagnostic] {
            guard !context.dependencySurface.isEmpty,
                  let file = source.file,
                  let resolver = context.symbolResolver else {
                return []
            }

            let visitor = PublicTypeReferenceVisitor()
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
                let leaking = symbols.contains { symbol in
                    if let identifier = symbol.identifier,
                       context.dependencySurface
                        .forbiddenSymbolIdentifiers
                        .contains(identifier) {
                        return true
                    }

                    if let module = symbol.systemModuleName,
                       context.dependencySurface
                        .forbiddenSystemModules
                        .contains(module) {
                        return true
                    }

                    return false
                }

                guard leaking else {
                    continue
                }

                diagnostics.append(
                    .init(
                        ruleID: id,
                        severity: .warning,
                        message: "Public or package API exposes a compiler-resolved dependency type that is forbidden by this target's dependency-surface policy.",
                        file: source.file,
                        lineRange: source.lineRange(
                            of: reference
                        )
                    )
                )
            }

            return diagnostics
        }

        private final class PublicTypeReferenceVisitor:
            SyntaxVisitor
        {
            var references: [IdentifierTypeSyntax] = []

            init() {
                super.init(
                    viewMode: .sourceAccurate
                )
            }

            override func visit(
                _ node: FunctionDeclSyntax
            ) -> SyntaxVisitorContinueKind {
                guard RuleAPISurface.isExternallyVisible(
                    node.modifiers
                ) else {
                    return .visitChildren
                }

                for parameter in node.signature
                    .parameterClause
                    .parameters {
                    collect(
                        parameter.type
                    )
                }

                if let type = node.signature
                    .returnClause?
                    .type {
                    collect(
                        type
                    )
                }

                return .skipChildren
            }

            override func visit(
                _ node: InitializerDeclSyntax
            ) -> SyntaxVisitorContinueKind {
                guard RuleAPISurface.isExternallyVisible(
                    node.modifiers
                ) else {
                    return .visitChildren
                }

                for parameter in node.signature
                    .parameterClause
                    .parameters {
                    collect(
                        parameter.type
                    )
                }

                return .skipChildren
            }

            override func visit(
                _ node: VariableDeclSyntax
            ) -> SyntaxVisitorContinueKind {
                guard RuleAPISurface.isExternallyVisible(
                    node.modifiers
                ) else {
                    return .visitChildren
                }

                for binding in node.bindings {
                    if let type = binding.typeAnnotation?.type {
                        collect(
                            type
                        )
                    }
                }

                return .skipChildren
            }

            private func collect(
                _ type: TypeSyntax
            ) {
                let collector = IdentifierCollector()
                collector.walk(
                    type
                )
                references.append(
                    contentsOf: collector.references
                )
            }
        }

        private final class IdentifierCollector:
            SyntaxVisitor
        {
            var references: [IdentifierTypeSyntax] = []

            init() {
                super.init(
                    viewMode: .sourceAccurate
                )
            }

            override func visit(
                _ node: IdentifierTypeSyntax
            ) -> SyntaxVisitorContinueKind {
                references.append(
                    node
                )
                return .visitChildren
            }
        }
    }
}
