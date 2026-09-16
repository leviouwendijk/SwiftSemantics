import Foundation
import SwiftSyntax

/// SwiftSyntax-backed parser for structural import declarations.
///
/// This intentionally performs no module resolution. SourceKit-LSP will own
/// resolved semantic relationships in a later layer.
enum SwiftImportParser {
    static func imports(
        in file: URL
    ) throws -> [SwiftSemanticImport] {
        imports(
            in: try SwiftSemanticSource(
                file: file
            )
        )
    }

    static func imports(
        in source: SwiftSemanticSource
    ) -> [SwiftSemanticImport] {
        let visitor = SwiftImportVisitor()

        visitor.walk(
            source.syntax
        )

        return visitor.imports
    }
}

private final class SwiftImportVisitor:
    SyntaxVisitor
{
    private(set) var imports: [SwiftSemanticImport] = []

    init() {
        super.init(
            viewMode: .sourceAccurate
        )
    }

    override func visit(
        _ node: ImportDeclSyntax
    ) -> SyntaxVisitorContinueKind {
        let path = node.path.description
            .split(
                separator: "."
            )
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter {
                !$0.isEmpty
            }

        if !path.isEmpty {
            imports.append(
                .init(
                    path: path
                )
            )
        }

        return .skipChildren
    }
}
