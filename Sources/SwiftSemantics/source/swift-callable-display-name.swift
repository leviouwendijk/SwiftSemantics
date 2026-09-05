import SwiftSyntax

/// Stable structural display names for callable Swift declarations.
///
/// This deliberately preserves source-level parameter labels only. Type-aware
/// overload identity belongs to the later compiler-semantic provider.
enum SwiftCallableDisplayName {
    static func function(
        _ node: FunctionDeclSyntax
    ) -> String {
        "\(node.name.text)\(parameterClause(for: node.signature.parameterClause.parameters))"
    }

    static func initializer(
        _ node: InitializerDeclSyntax
    ) -> String {
        "init\(parameterClause(for: node.signature.parameterClause.parameters))"
    }

    static func subscriptDecl(
        _ node: SubscriptDeclSyntax
    ) -> String {
        "subscript\(parameterClause(for: node.parameterClause.parameters))"
    }
}

private extension SwiftCallableDisplayName {
    static func parameterClause<S: Sequence>(
        for parameters: S
    ) -> String where S.Element == FunctionParameterSyntax {
        let rendered = parameters.map { parameter in
            "\(parameter.firstName.text):"
        }
        .joined()

        return "(\(rendered))"
    }
}
