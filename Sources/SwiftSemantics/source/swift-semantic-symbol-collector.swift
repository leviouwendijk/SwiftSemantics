import Foundation
import SwiftParser
import SwiftSyntax

/// SwiftSyntax-backed structural symbol collection.
///
/// This is the provider-neutral implementation extracted from AgenticSwift.
/// It accepts ordinary file URLs and has no workspace, path-authority, schema,
/// or tool-policy concerns.
public struct SwiftSemanticSymbolCollector:
    Sendable
{
    public init() {}

    public func collect(
        in file: URL
    ) throws -> [SwiftSemanticSymbol] {
        let file = file.standardizedFileURL

        guard file.pathExtension == "swift" else {
            throw SwiftSemanticSourceInspectionError.unsupportedFile(
                file.path
            )
        }

        let source = try String(
            contentsOf: file,
            encoding: .utf8
        )

        return collect(
            source: source
        )
    }

    public func collect(
        source: String
    ) -> [SwiftSemanticSymbol] {
        let sourceFile = Parser.parse(
            source: source
        )
        let mapper = SwiftSourceLineMapper(
            source: source
        )
        let visitor = SwiftSemanticSymbolVisitor(
            mapper: mapper
        )

        visitor.walk(
            sourceFile
        )

        return visitor.symbols()
    }
}

private final class SwiftSemanticSymbolVisitor:
    SyntaxVisitor
{
    private let mapper: SwiftSourceLineMapper

    private var collected: [SwiftSemanticSymbol] = []
    private var typeStack: [String] = []

    init(
        mapper: SwiftSourceLineMapper
    ) {
        self.mapper = mapper

        super.init(
            viewMode: .sourceAccurate
        )
    }

    func symbols() -> [SwiftSemanticSymbol] {
        collected.sorted { lhs, rhs in
            if lhs.lineRange.start == rhs.lineRange.start {
                if lhs.lineRange.end == rhs.lineRange.end {
                    if lhs.kind == rhs.kind {
                        return lhs.displayName < rhs.displayName
                    }

                    return lhs.kind.rawValue < rhs.kind.rawValue
                }

                return lhs.lineRange.end < rhs.lineRange.end
            }

            return lhs.lineRange.start < rhs.lineRange.start
        }
    }

    override func visit(
        _ node: ImportDeclSyntax
    ) -> SyntaxVisitorContinueKind {
        record(
            node,
            kind: .import,
            name: normalized(
                node.path.description
            ),
            parentType: nil,
            summary: normalized(
                node.description
            )
        )

        return .skipChildren
    }

    override func visit(
        _ node: StructDeclSyntax
    ) -> SyntaxVisitorContinueKind {
        record(
            node,
            kind: .struct,
            name: node.name.text,
            parentType: currentTypeName,
            summary: "struct \(node.name.text)"
        )

        typeStack.append(
            node.name.text
        )

        return .visitChildren
    }

    override func visitPost(
        _ node: StructDeclSyntax
    ) {
        _ = node
        _ = typeStack.popLast()
    }

    override func visit(
        _ node: ClassDeclSyntax
    ) -> SyntaxVisitorContinueKind {
        record(
            node,
            kind: .class,
            name: node.name.text,
            parentType: currentTypeName,
            summary: "class \(node.name.text)"
        )

        typeStack.append(
            node.name.text
        )

        return .visitChildren
    }

    override func visitPost(
        _ node: ClassDeclSyntax
    ) {
        _ = node
        _ = typeStack.popLast()
    }

    override func visit(
        _ node: ActorDeclSyntax
    ) -> SyntaxVisitorContinueKind {
        record(
            node,
            kind: .actor,
            name: node.name.text,
            parentType: currentTypeName,
            summary: "actor \(node.name.text)"
        )

        typeStack.append(
            node.name.text
        )

        return .visitChildren
    }

    override func visitPost(
        _ node: ActorDeclSyntax
    ) {
        _ = node
        _ = typeStack.popLast()
    }

    override func visit(
        _ node: EnumDeclSyntax
    ) -> SyntaxVisitorContinueKind {
        record(
            node,
            kind: .enum,
            name: node.name.text,
            parentType: currentTypeName,
            summary: "enum \(node.name.text)"
        )

        typeStack.append(
            node.name.text
        )

        return .visitChildren
    }

    override func visitPost(
        _ node: EnumDeclSyntax
    ) {
        _ = node
        _ = typeStack.popLast()
    }

    override func visit(
        _ node: ProtocolDeclSyntax
    ) -> SyntaxVisitorContinueKind {
        record(
            node,
            kind: .protocol,
            name: node.name.text,
            parentType: currentTypeName,
            summary: "protocol \(node.name.text)"
        )

        typeStack.append(
            node.name.text
        )

        return .visitChildren
    }

    override func visitPost(
        _ node: ProtocolDeclSyntax
    ) {
        _ = node
        _ = typeStack.popLast()
    }

    override func visit(
        _ node: ExtensionDeclSyntax
    ) -> SyntaxVisitorContinueKind {
        let name = normalized(
            node.extendedType.description
        )

        record(
            node,
            kind: .extension,
            name: name,
            parentType: nil,
            summary: "extension \(name)"
        )

        typeStack.append(
            name
        )

        return .visitChildren
    }

    override func visitPost(
        _ node: ExtensionDeclSyntax
    ) {
        _ = node
        _ = typeStack.popLast()
    }

    override func visit(
        _ node: TypeAliasDeclSyntax
    ) -> SyntaxVisitorContinueKind {
        record(
            node,
            kind: .typealias_decl,
            name: node.name.text,
            parentType: currentTypeName,
            summary: "typealias \(node.name.text)"
        )

        return .visitChildren
    }

    override func visit(
        _ node: FunctionDeclSyntax
    ) -> SyntaxVisitorContinueKind {
        let displayName = SwiftCallableDisplayName.function(
            node
        )

        record(
            node,
            kind: .function,
            name: node.name.text,
            displayName: displayName,
            parentType: currentTypeName,
            summary: "func \(displayName)"
        )

        return .visitChildren
    }

    override func visit(
        _ node: InitializerDeclSyntax
    ) -> SyntaxVisitorContinueKind {
        let displayName = SwiftCallableDisplayName.initializer(
            node
        )

        record(
            node,
            kind: .initializer,
            name: "init",
            displayName: displayName,
            parentType: currentTypeName,
            summary: displayName
        )

        return .visitChildren
    }

    override func visit(
        _ node: SubscriptDeclSyntax
    ) -> SyntaxVisitorContinueKind {
        let displayName = SwiftCallableDisplayName.subscriptDecl(
            node
        )

        record(
            node,
            kind: .subscript_decl,
            name: "subscript",
            displayName: displayName,
            parentType: currentTypeName,
            summary: displayName
        )

        return .visitChildren
    }

    override func visit(
        _ node: VariableDeclSyntax
    ) -> SyntaxVisitorContinueKind {
        for binding in node.bindings {
            let name = normalized(
                binding.pattern.description
            )

            record(
                binding,
                kind: .variable,
                name: name,
                parentType: currentTypeName,
                summary: "\(node.bindingSpecifier.text) \(name)"
            )
        }

        return .visitChildren
    }

    override func visit(
        _ node: EnumCaseDeclSyntax
    ) -> SyntaxVisitorContinueKind {
        for element in node.elements {
            record(
                element,
                kind: .enum_case,
                name: element.name.text,
                parentType: currentTypeName,
                summary: "case \(element.name.text)"
            )
        }

        return .visitChildren
    }
}

private extension SwiftSemanticSymbolVisitor {
    var currentTypeName: String? {
        typeStack.last
    }

    func record(
        _ node: some SyntaxProtocol,
        kind: SwiftSemanticSymbolKind,
        name: String,
        displayName: String? = nil,
        parentType: String?,
        summary: String
    ) {
        let startOffset = node
            .positionAfterSkippingLeadingTrivia
            .utf8Offset
        let endOffset = node
            .endPositionBeforeTrailingTrivia
            .utf8Offset

        guard let lineRange = mapper.lineRange(
            startUTF8Offset: startOffset,
            endUTF8Offset: endOffset
        ) else {
            assertionFailure(
                "Failed to construct LineRange for Swift semantic symbol collection."
            )
            return
        }

        collected.append(
            .init(
                kind: kind,
                name: name,
                displayName: displayName,
                parentType: parentType,
                lineRange: lineRange,
                summary: summary
            )
        )
    }

    func normalized(
        _ value: String
    ) -> String {
        value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }
}
