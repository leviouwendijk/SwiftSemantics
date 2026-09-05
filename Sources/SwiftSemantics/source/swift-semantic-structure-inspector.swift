import Foundation
import SwiftParser
import SwiftSyntax

/// SwiftSyntax-backed structural selection over one Swift source file.
///
/// This preserves the deterministic query behavior previously implemented by
/// AgenticSwift while removing Agentic workspace/path/tool concerns from the
/// source-understanding layer.
public struct SwiftSemanticStructureInspector:
    Sendable
{
    public init() {}

    public func selections(
        in file: URL,
        query: SwiftSemanticStructureQuery
    ) throws -> [SwiftSemanticStructureSelection] {
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
        let sourceFile = Parser.parse(
            source: source
        )
        let mapper = SwiftSourceLineMapper(
            source: source
        )
        let visitor = SwiftSemanticStructureVisitor(
            file: file,
            query: query,
            mapper: mapper
        )

        visitor.walk(
            sourceFile
        )

        return visitor.matches()
    }
}

private struct SwiftSemanticStructuralMatch:
    Sendable
{
    let selection: SwiftSemanticStructureSelection
    let startUTF8Offset: Int
    let endUTF8Offset: Int
}

private final class SwiftSemanticStructureVisitor:
    SyntaxVisitor
{
    private let file: URL
    private let query: SwiftSemanticStructureQuery
    private let mapper: SwiftSourceLineMapper

    private var collected: [SwiftSemanticStructuralMatch] = []
    private var typeStack: [String] = []

    init(
        file: URL,
        query: SwiftSemanticStructureQuery,
        mapper: SwiftSourceLineMapper
    ) {
        self.file = file
        self.query = query
        self.mapper = mapper

        super.init(
            viewMode: .sourceAccurate
        )
    }

    func matches() -> [SwiftSemanticStructureSelection] {
        switch query {
        case .enclosingScope(let location):
            let containing: [SwiftSemanticStructuralMatch]

            if let column = location.column {
                guard let offset = mapper.utf8Offset(
                    line: location.line,
                    column: column
                ) else {
                    return []
                }

                containing = collected.filter { match in
                    match.startUTF8Offset <= offset
                        && offset < match.endUTF8Offset
                }
            } else {
                containing = collected.filter { match in
                    match.selection.lineRange.start <= location.line
                        && match.selection.lineRange.end >= location.line
                }
            }

            guard let smallest = containing.min(
                by: isNarrower(lhs:rhs:)
            ) else {
                return []
            }

            return [
                smallest.selection,
            ]

        default:
            return collected.map(
                \.selection
            )
        }
    }

    override func visit(
        _ node: StructDeclSyntax
    ) -> SyntaxVisitorContinueKind {
        recordType(
            node,
            name: node.name.text,
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
        recordType(
            node,
            name: node.name.text,
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
        recordType(
            node,
            name: node.name.text,
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
        recordType(
            node,
            name: node.name.text,
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
        recordType(
            node,
            name: node.name.text,
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

        recordAnyDeclaration(
            node,
            kind: .declaration,
            name: name,
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
        recordAnyDeclaration(
            node,
            kind: currentTypeName == nil
                ? .declaration
                : .member,
            name: node.name.text,
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

        recordMemberLike(
            node,
            name: node.name.text,
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

        recordMemberLike(
            node,
            name: "init",
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

        recordMemberLike(
            node,
            name: "subscript",
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

            recordMemberLike(
                binding,
                name: name,
                summary: "\(node.bindingSpecifier.text) \(name)"
            )
        }

        return .visitChildren
    }

    override func visit(
        _ node: EnumCaseDeclSyntax
    ) -> SyntaxVisitorContinueKind {
        for element in node.elements {
            recordMemberLike(
                element,
                name: element.name.text,
                summary: "case \(element.name.text)"
            )
        }

        return .visitChildren
    }

    override func visit(
        _ node: ImportDeclSyntax
    ) -> SyntaxVisitorContinueKind {
        if case .imports = query {
            record(
                node,
                kind: .imports,
                name: nil,
                summary: normalized(
                    node.description
                )
            )
        }

        return .skipChildren
    }
}

private extension SwiftSemanticStructureVisitor {
    var currentTypeName: String? {
        typeStack.last
    }

    func recordType(
        _ node: some SyntaxProtocol,
        name: String,
        summary: String
    ) {
        switch query {
        case .type(let requestedName):
            guard name == requestedName else {
                return
            }

            record(
                node,
                kind: .type,
                name: name,
                summary: summary
            )

        case .declaration(let requestedName):
            guard name == requestedName else {
                return
            }

            record(
                node,
                kind: .declaration,
                name: name,
                summary: summary
            )

        case .enclosingScope:
            record(
                node,
                kind: .enclosing_scope,
                name: name,
                summary: summary
            )

        default:
            break
        }
    }

    func recordAnyDeclaration(
        _ node: some SyntaxProtocol,
        kind: SwiftSemanticStructureSelection.Kind,
        name: String,
        summary: String
    ) {
        switch query {
        case .declaration(let requestedName):
            guard name == requestedName else {
                return
            }

            record(
                node,
                kind: kind,
                name: name,
                summary: summary
            )

        case .enclosingScope:
            record(
                node,
                kind: .enclosing_scope,
                name: name,
                summary: summary
            )

        default:
            break
        }
    }

    func recordMemberLike(
        _ node: some SyntaxProtocol,
        name: String,
        summary: String
    ) {
        switch query {
        case .member(
            let requestedName,
            let parentType
        ):
            guard name == requestedName else {
                return
            }

            if let parentType {
                guard currentTypeName == parentType else {
                    return
                }
            }

            record(
                node,
                kind: .member,
                name: name,
                summary: summary
            )

        case .declaration(let requestedName):
            guard name == requestedName else {
                return
            }

            record(
                node,
                kind: currentTypeName == nil
                    ? .declaration
                    : .member,
                name: name,
                summary: summary
            )

        case .enclosingScope:
            record(
                node,
                kind: .enclosing_scope,
                name: name,
                summary: summary
            )

        default:
            break
        }
    }

    func record(
        _ node: some SyntaxProtocol,
        kind: SwiftSemanticStructureSelection.Kind,
        name: String?,
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
                "Failed to construct LineRange for Swift semantic structural selection."
            )
            return
        }

        if case .enclosingScope(let location) = query {
            guard location.line > 0 else {
                return
            }

            if let column = location.column,
               column <= 0
            {
                return
            }
        }

        collected.append(
            .init(
                selection: .init(
                    file: file,
                    lineRange: lineRange,
                    kind: kind,
                    symbolName: name,
                    summary: summary
                ),
                startUTF8Offset: startOffset,
                endUTF8Offset: endOffset
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

    func isNarrower(
        lhs: SwiftSemanticStructuralMatch,
        rhs: SwiftSemanticStructuralMatch
    ) -> Bool {
        let lhsWidth = lhs.endUTF8Offset
            - lhs.startUTF8Offset
        let rhsWidth = rhs.endUTF8Offset
            - rhs.startUTF8Offset

        if lhsWidth == rhsWidth {
            return lhs.selection.lineRange.start
                < rhs.selection.lineRange.start
        }

        return lhsWidth < rhsWidth
    }
}
