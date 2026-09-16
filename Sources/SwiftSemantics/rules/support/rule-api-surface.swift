import Position
import SwiftSyntax

struct RuleAPISurfaceDeclaration:
    Sendable
{
    let parameterTypes: [String]
    let hasTupleSurface: Bool
    let hasAnySurface: Bool
    let lineRange: LineRange?
}

enum RuleAPISurface {
    static let primitiveTypes: Set<String> = [
        "Bool",
        "Character",
        "Double",
        "Float",
        "Int",
        "Int8",
        "Int16",
        "Int32",
        "Int64",
        "String",
        "UInt",
        "UInt8",
        "UInt16",
        "UInt32",
        "UInt64",
    ]

    static func declarations(
        in source: SwiftSemanticSource
    ) -> [RuleAPISurfaceDeclaration] {
        let visitor = Visitor(
            source: source
        )

        visitor.walk(
            source.syntax
        )

        return visitor.declarations
    }

    static func isExternallyVisible(
        _ modifiers: DeclModifierListSyntax
    ) -> Bool {
        modifiers.contains { modifier in
            let name = modifier.name.text
            return name == "public"
                || name == "package"
                || name == "open"
        }
    }

    static func containsAny(
        _ type: TypeSyntax
    ) -> Bool {
        let visitor = AnyTypeVisitor()
        visitor.walk(
            type
        )
        return visitor.found
    }

    private final class AnyTypeVisitor:
        SyntaxVisitor
    {
        var found = false

        init() {
            super.init(
                viewMode: .sourceAccurate
            )
        }

        override func visit(
            _ node: IdentifierTypeSyntax
        ) -> SyntaxVisitorContinueKind {
            if node.name.text == "Any"
                || node.name.text == "AnyObject" {
                found = true
                return .skipChildren
            }

            return .visitChildren
        }
    }

    private final class Visitor:
        SyntaxVisitor
    {
        let source: SwiftSemanticSource
        var declarations: [RuleAPISurfaceDeclaration] = []

        init(
            source: SwiftSemanticSource
        ) {
            self.source = source
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

            let parameterTypes = node.signature
                .parameterClause
                .parameters
                .map { parameter in
                    parameter.type.trimmedDescription
                }
            let returnType = node.signature
                .returnClause?
                .type
            let hasTuple = returnType?
                .as(TupleTypeSyntax.self)?
                .elements
                .count ?? 0 > 1
            let hasAny = node.signature
                .parameterClause
                .parameters
                .contains { parameter in
                    RuleAPISurface.containsAny(
                        parameter.type
                    )
                }
                || returnType.map(
                    RuleAPISurface.containsAny
                ) == true

            record(
                node: node,
                parameterTypes: parameterTypes,
                hasTuple: hasTuple,
                hasAny: hasAny
            )

            return .visitChildren
        }

        override func visit(
            _ node: InitializerDeclSyntax
        ) -> SyntaxVisitorContinueKind {
            guard RuleAPISurface.isExternallyVisible(
                node.modifiers
            ) else {
                return .visitChildren
            }

            let parameters = node.signature
                .parameterClause
                .parameters
            let parameterTypes = parameters.map { parameter in
                parameter.type.trimmedDescription
            }
            let hasAny = parameters.contains { parameter in
                RuleAPISurface.containsAny(
                    parameter.type
                )
            }

            record(
                node: node,
                parameterTypes: parameterTypes,
                hasTuple: false,
                hasAny: hasAny
            )

            return .visitChildren
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
                guard let type = binding.typeAnnotation?.type else {
                    continue
                }

                record(
                    node: binding,
                    parameterTypes: [],
                    hasTuple:
                        type.as(TupleTypeSyntax.self)?
                            .elements
                            .count ?? 0 > 1,
                    hasAny: RuleAPISurface.containsAny(
                        type
                    )
                )
            }

            return .visitChildren
        }

        private func record(
            node: some SyntaxProtocol,
            parameterTypes: [String],
            hasTuple: Bool,
            hasAny: Bool
        ) {
            declarations.append(
                .init(
                    parameterTypes: parameterTypes,
                    hasTupleSurface: hasTuple,
                    hasAnySurface: hasAny,
                    lineRange: source.lineRange(
                        of: node
                    )
                )
            )
        }
    }
}
