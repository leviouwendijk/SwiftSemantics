import Primitives
import SwiftSyntax

public extension SwiftSemanticRules.Enums {
    struct CodableStringCaseCasing:
        SwiftSemanticRule
    {
        public let id = SwiftSemanticRuleID.codableStringEnumCaseCasing
        public let suppression: SwiftSemanticRuleSuppression = .source_directive

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
            let source: SwiftSemanticSource
            let ruleID: SwiftSemanticRuleID
            var diagnostics: [SwiftSemanticRuleDiagnostic] = []

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
                _ node: EnumDeclSyntax
            ) -> SyntaxVisitorContinueKind {
                let inherited = Set(
                    node.inheritanceClause?
                        .inheritedTypes
                        .map { inherited in
                            inherited.type.trimmedDescription
                        }
                    ?? []
                )
                let isString = inherited.contains(
                    "String"
                )
                let isCodable = inherited.contains(
                    "Codable"
                )
                    || (
                        inherited.contains("Encodable")
                        && inherited.contains("Decodable")
                    )

                guard isString,
                      isCodable else {
                    return .visitChildren
                }

                for member in node.memberBlock.members {
                    guard let cases = member.decl.as(
                        EnumCaseDeclSyntax.self
                    ) else {
                        continue
                    }

                    for element in cases.elements {
                        let name = element.name.text
                        let expected = Case.convert(
                            name,
                            to: .snake
                        )

                        guard name != expected else {
                            continue
                        }

                        diagnostics.append(
                            .init(
                                ruleID: ruleID,
                                severity: .warning,
                                message: "String Codable enum case '\(name)' should use snake_case boundary spelling directly as '\(expected)' rather than relying on a redundant raw-value translation.",
                                file: source.file,
                                lineRange: source.lineRange(
                                    of: element
                                )
                            )
                        )
                    }
                }

                return .visitChildren
            }
        }
    }
}
