import Primitives
import SwiftSyntax

public extension SwiftSemanticRules.Enums {
    struct RedundantStringRawValue:
        SwiftSemanticRule
    {
        public let id =
            SwiftSemanticRuleID.redundantStringEnumRawValue

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

            return visitor.nodes.compactMap { node in
                guard
                    let literal = node.rawValue?
                        .value
                        .as(StringLiteralExprSyntax.self),
                    let rawValue = literal.representedLiteralValue,
                    isRedundant(
                        name: node.name.text,
                        rawValue: rawValue
                    )
                else {
                    return nil
                }

                return .init(
                    ruleID: id,
                    severity: .warning,
                    message:
                        "String enum raw value is a redundant spelling of the case identifier.",
                    file: source.file,
                    lineRange: source.lineRange(
                        of: node
                    )
                )
            }
        }

        private func isRedundant(
            name: String,
            rawValue: String
        ) -> Bool {
            if rawValue == name {
                return true
            }

            guard !isExternalAcronym(rawValue) else {
                return false
            }

            return Case.convert(
                name,
                to: .flat
            ) == Case.convert(
                rawValue,
                to: .flat
            )
        }

        private func isExternalAcronym(
            _ value: String
        ) -> Bool {
            let letters = value.filter(\.isLetter)

            guard !letters.isEmpty else {
                return false
            }

            return letters.allSatisfy(\.isUppercase)
                && !value.contains("_")
                && !value.contains("-")
        }

        private final class Visitor:
            SyntaxVisitor
        {
            private var stringEnumStack: [Bool] = []
            private(set) var nodes: [EnumCaseElementSyntax] = []

            init() {
                super.init(
                    viewMode: .sourceAccurate
                )
            }

            override func visit(
                _ node: EnumDeclSyntax
            ) -> SyntaxVisitorContinueKind {
                let isString = node.inheritanceClause?
                    .inheritedTypes
                    .contains { inherited in
                        inherited.type.trimmedDescription == "String"
                    } == true

                stringEnumStack.append(
                    isString
                )

                return .visitChildren
            }

            override func visitPost(
                _ node: EnumDeclSyntax
            ) {
                _ = node
                _ = stringEnumStack.popLast()
            }

            override func visit(
                _ node: EnumCaseElementSyntax
            ) -> SyntaxVisitorContinueKind {
                if stringEnumStack.last == true,
                    node.rawValue != nil {
                    nodes.append(
                        node
                    )
                }

                return .visitChildren
            }
        }
    }
}
