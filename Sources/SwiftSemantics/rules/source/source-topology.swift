import Foundation
import Position
import Primitives
import SwiftSyntax

public extension SwiftSemanticRules.Source {
    struct PrimaryDeclarationFilename:
        SwiftSemanticRule
    {
        public let id = SwiftSemanticRuleID.primaryDeclarationFilename
        public let suppression: SwiftSemanticRuleSuppression = .source_directive

        public init() {}

        public func diagnostics(
            in source: SwiftSemanticSource,
            context: SwiftSemanticRuleContext
        ) async throws -> [SwiftSemanticRuleDiagnostic] {
            _ = context

            guard let file = source.file else {
                return []
            }

            let declarations = RuleNamedDeclarations.collect(
                in: source
            ).filter { declaration in
                declaration.isTopLevel
                    && RuleNamedDeclarations.isNominal(
                        declaration.kind
                    )
            }

            guard declarations.count == 1,
                let declaration = declarations.first else {
                return []
            }

            let expectedStem = Case.convert(
                declaration.name,
                to: .kebab
            )
            let actualStem = file
                .deletingPathExtension()
                .lastPathComponent

            guard actualStem != expectedStem,
                !actualStem.hasPrefix(
                    expectedStem + "+"
                ) else {
                return []
            }

            return [
                .init(
                    ruleID: id,
                    severity: .warning,
                    message: "Source with one primary top-level type '\(declaration.name)' is named '\(file.lastPathComponent)'. Prefer '\(expectedStem).swift' or an intentional '\(expectedStem)+suffix.swift' companion.",
                    file: source.file,
                    lineRange: declaration.lineRange
                ),
            ]
        }
    }

    struct UnrelatedPublicDeclarations:
        SwiftSemanticRule
    {
        public let id = SwiftSemanticRuleID.unrelatedPublicDeclarations
        public let suppression: SwiftSemanticRuleSuppression = .source_directive

        public init() {}

        public func diagnostics(
            in source: SwiftSemanticSource,
            context: SwiftSemanticRuleContext
        ) async throws -> [SwiftSemanticRuleDiagnostic] {
            let minimum = Int(
                context.configuration.unrelatedPublicDeclarationCount
            )
            let visitor = TopLevelPublicNominalVisitor(
                source: source
            )

            visitor.walk(
                source.syntax
            )

            let firstComponents = Set(
                visitor.names.compactMap { name in
                    Case.components(name).first
                }
            )

            guard visitor.names.count >= minimum,
                firstComponents.count >= minimum else {
                return []
            }

            return [
                .init(
                    ruleID: id,
                    severity: .hint,
                    message: "File contains \(visitor.names.count) top-level public/package types with unrelated lexical roots. Consider splitting the file or nesting related concepts under an owner.",
                    file: source.file,
                    lineRange: visitor.firstLineRange
                ),
            ]
        }
    }

    struct LibraryPrint:
        SwiftSemanticRule
    {
        public let id = SwiftSemanticRuleID.libraryPrint
        public let suppression: SwiftSemanticRuleSuppression = .source_directive

        public init() {}

        public func diagnostics(
            in source: SwiftSemanticSource,
            context: SwiftSemanticRuleContext
        ) async throws -> [SwiftSemanticRuleDiagnostic] {
            guard context.sourceRole == .library else {
                return []
            }

            let visitor = PrintVisitor(
                source: source,
                ruleID: id
            )

            visitor.walk(
                source.syntax
            )

            return visitor.diagnostics
        }
    }
}

private final class TopLevelPublicNominalVisitor:
    SyntaxVisitor
{
    let source: SwiftSemanticSource
    var depth = 0
    var names: [String] = []
    var firstLineRange: LineRange?

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
        enter(
            name: node.name.text,
            modifiers: node.modifiers,
            node: node
        )
    }

    override func visitPost(
        _ node: StructDeclSyntax
    ) {
        _ = node
        depth -= 1
    }

    override func visit(
        _ node: ClassDeclSyntax
    ) -> SyntaxVisitorContinueKind {
        enter(
            name: node.name.text,
            modifiers: node.modifiers,
            node: node
        )
    }

    override func visitPost(
        _ node: ClassDeclSyntax
    ) {
        _ = node
        depth -= 1
    }

    override func visit(
        _ node: ActorDeclSyntax
    ) -> SyntaxVisitorContinueKind {
        enter(
            name: node.name.text,
            modifiers: node.modifiers,
            node: node
        )
    }

    override func visitPost(
        _ node: ActorDeclSyntax
    ) {
        _ = node
        depth -= 1
    }

    override func visit(
        _ node: EnumDeclSyntax
    ) -> SyntaxVisitorContinueKind {
        enter(
            name: node.name.text,
            modifiers: node.modifiers,
            node: node
        )
    }

    override func visitPost(
        _ node: EnumDeclSyntax
    ) {
        _ = node
        depth -= 1
    }

    override func visit(
        _ node: ProtocolDeclSyntax
    ) -> SyntaxVisitorContinueKind {
        enter(
            name: node.name.text,
            modifiers: node.modifiers,
            node: node
        )
    }

    override func visitPost(
        _ node: ProtocolDeclSyntax
    ) {
        _ = node
        depth -= 1
    }

    private func enter(
        name: String,
        modifiers: DeclModifierListSyntax,
        node: some SyntaxProtocol
    ) -> SyntaxVisitorContinueKind {
        if depth == 0,
            RuleAPISurface.isExternallyVisible(
                modifiers
            ) {
            names.append(
                name
            )

            if firstLineRange == nil {
                firstLineRange = source.lineRange(
                    of: node
                )
            }
        }

        depth += 1
        return .visitChildren
    }
}

private final class PrintVisitor:
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
        _ node: FunctionCallExprSyntax
    ) -> SyntaxVisitorContinueKind {
        guard let reference = node.calledExpression.as(
            DeclReferenceExprSyntax.self
        ),
        reference.baseName.text == "print" else {
            return .visitChildren
        }

        diagnostics.append(
            .init(
                ruleID: ruleID,
                severity: .warning,
                message: "Library source calls print directly. Return semantic results/events and leave presentation to an executable or interface boundary.",
                file: source.file,
                lineRange: source.lineRange(
                    of: node
                )
            )
        )

        return .visitChildren
    }
}
