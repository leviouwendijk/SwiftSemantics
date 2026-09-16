import Position
import SwiftSyntax

struct RuleNamedDeclaration:
    Sendable
{
    enum Kind:
        Sendable
    {
        case nominal
        case typealias_decl
        case callable
        case value
        case enum_case
    }

    let kind: Kind
    let name: String
    let lineage: [String]
    let parentName: String?
    let lineRange: LineRange?

    var isTopLevel: Bool {
        switch kind {
        case .nominal:
            lineage.count == 1
        default:
            lineage.isEmpty
        }
    }
}

enum RuleNamedDeclarations {
    static func collect(
        in source: SwiftSemanticSource
    ) -> [RuleNamedDeclaration] {
        let visitor = Visitor(
            source: source
        )

        visitor.walk(
            source.syntax
        )

        return visitor.declarations
    }

    static func isNominal(
        _ kind: RuleNamedDeclaration.Kind
    ) -> Bool {
        if case .nominal = kind {
            return true
        }

        return false
    }

    private final class Visitor:
        SyntaxVisitor
    {
        let source: SwiftSemanticSource
        var stack: [String] = []
        var declarations: [RuleNamedDeclaration] = []

        init(
            source: SwiftSemanticSource
        ) {
            self.source = source
            super.init(
                viewMode: .sourceAccurate
            )
        }

        override func visit(
            _ node: StructDeclSyntax
        ) -> SyntaxVisitorContinueKind {
            enterNominal(
                name: node.name.text,
                node: node
            )
        }

        override func visitPost(
            _ node: StructDeclSyntax
        ) {
            _ = node
            _ = stack.popLast()
        }

        override func visit(
            _ node: ClassDeclSyntax
        ) -> SyntaxVisitorContinueKind {
            enterNominal(
                name: node.name.text,
                node: node
            )
        }

        override func visitPost(
            _ node: ClassDeclSyntax
        ) {
            _ = node
            _ = stack.popLast()
        }

        override func visit(
            _ node: ActorDeclSyntax
        ) -> SyntaxVisitorContinueKind {
            enterNominal(
                name: node.name.text,
                node: node
            )
        }

        override func visitPost(
            _ node: ActorDeclSyntax
        ) {
            _ = node
            _ = stack.popLast()
        }

        override func visit(
            _ node: EnumDeclSyntax
        ) -> SyntaxVisitorContinueKind {
            enterNominal(
                name: node.name.text,
                node: node
            )
        }

        override func visitPost(
            _ node: EnumDeclSyntax
        ) {
            _ = node
            _ = stack.popLast()
        }

        override func visit(
            _ node: ProtocolDeclSyntax
        ) -> SyntaxVisitorContinueKind {
            enterNominal(
                name: node.name.text,
                node: node
            )
        }

        override func visitPost(
            _ node: ProtocolDeclSyntax
        ) {
            _ = node
            _ = stack.popLast()
        }

        override func visit(
            _ node: TypeAliasDeclSyntax
        ) -> SyntaxVisitorContinueKind {
            record(
                kind: .typealias_decl,
                name: node.name.text,
                lineage: stack,
                node: node
            )
            return .visitChildren
        }

        override func visit(
            _ node: FunctionDeclSyntax
        ) -> SyntaxVisitorContinueKind {
            record(
                kind: .callable,
                name: node.name.text,
                lineage: stack,
                node: node
            )
            return .visitChildren
        }

        override func visit(
            _ node: VariableDeclSyntax
        ) -> SyntaxVisitorContinueKind {
            for binding in node.bindings {
                guard let pattern = binding.pattern.as(
                    IdentifierPatternSyntax.self
                ) else {
                    continue
                }

                record(
                    kind: .value,
                    name: pattern.identifier.text,
                    lineage: stack,
                    node: binding
                )
            }

            return .visitChildren
        }

        override func visit(
            _ node: EnumCaseDeclSyntax
        ) -> SyntaxVisitorContinueKind {
            for element in node.elements {
                record(
                    kind: .enum_case,
                    name: element.name.text,
                    lineage: stack,
                    node: element
                )
            }

            return .visitChildren
        }

        private func enterNominal(
            name: String,
            node: some SyntaxProtocol
        ) -> SyntaxVisitorContinueKind {
            let lineage = stack + [
                name,
            ]

            record(
                kind: .nominal,
                name: name,
                lineage: lineage,
                node: node
            )
            stack.append(
                name
            )

            return .visitChildren
        }

        private func record(
            kind: RuleNamedDeclaration.Kind,
            name: String,
            lineage: [String],
            node: some SyntaxProtocol
        ) {
            declarations.append(
                .init(
                    kind: kind,
                    name: name,
                    lineage: lineage,
                    parentName:
                        kind == .nominal
                        ? lineage.dropLast().last
                        : lineage.last,
                    lineRange: source.lineRange(
                        of: node
                    )
                )
            )
        }
    }
}
