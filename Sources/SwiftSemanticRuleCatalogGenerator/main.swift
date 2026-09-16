import Foundation
import SwiftParser
import SwiftSyntax

@main
struct SwiftSemanticRuleCatalogGenerator {
    static func main() throws {
        let arguments = CommandLine.arguments

        let rulesDirectory: URL
        let output: URL

        switch arguments.count {
        case 1:
            let root = URL(
                fileURLWithPath: FileManager.default.currentDirectoryPath
            )
            .standardizedFileURL

            rulesDirectory = root.appending(
                path: "Sources/SwiftSemantics/rules"
            )

            output = rulesDirectory.appending(
                path: "swift-semantic-rule-catalog.generated.swift"
            )

        case 3:
            rulesDirectory = URL(
                fileURLWithPath: arguments[1]
            )
            .standardizedFileURL

            output = URL(
                fileURLWithPath: arguments[2]
            )
            .standardizedFileURL

        default:
            throw GeneratorError.invalidArguments
        }

        let sourceFiles = try swiftFiles(
            below: rulesDirectory
        )

        var discovered: Set<String> = []

        for file in sourceFiles {
            let source = try String(
                contentsOf: file,
                encoding: .utf8
            )

            let syntax = Parser.parse(
                source: source
            )

            let visitor = RuleVisitor(
                viewMode: .sourceAccurate
            )

            visitor.walk(
                syntax
            )

            discovered.formUnion(
                visitor.ruleTypeNames
            )
        }

        let ruleTypeNames = discovered.sorted()

        guard !ruleTypeNames.isEmpty else {
            throw GeneratorError.noRulesDiscovered
        }

        let generated = render(
            ruleTypeNames: ruleTypeNames
        )

        try FileManager.default.createDirectory(
            at: output.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        try generated.write(
            to: output,
            atomically: true,
            encoding: .utf8
        )
    }
}

private enum GeneratorError:
    Error,
    LocalizedError
{
    case invalidArguments
    case noRulesDiscovered

    var errorDescription: String? {
        switch self {
        case .invalidArguments:
            return "Run with no arguments from the SwiftSemantics package root, or provide rules-directory and output-file arguments."

        case .noRulesDiscovered:
            return "No concrete SwiftSemanticRule declarations were discovered."
        }
    }
}

private final class RuleVisitor:
    SyntaxVisitor
{
    private var extensionScope: [String] = []

    private(set) var ruleTypeNames: Set<String> = []

    override func visit(
        _ node: ExtensionDeclSyntax
    ) -> SyntaxVisitorContinueKind {
        extensionScope.append(
            node.extendedType.trimmedDescription
        )

        return .visitChildren
    }

    override func visitPost(
        _ node: ExtensionDeclSyntax
    ) {
        _ = node
        _ = extensionScope.popLast()
    }

    override func visit(
        _ node: StructDeclSyntax
    ) -> SyntaxVisitorContinueKind {
        guard directlyConformsToRule(
            node
        ) else {
            return .visitChildren
        }

        let name = node.name.text

        if let prefix = extensionScope.last {
            ruleTypeNames.insert(
                prefix + "." + name
            )
        } else {
            ruleTypeNames.insert(
                name
            )
        }

        return .visitChildren
    }

    private func directlyConformsToRule(
        _ node: StructDeclSyntax
    ) -> Bool {
        guard let inheritanceClause = node.inheritanceClause else {
            return false
        }

        return inheritanceClause.inheritedTypes.contains { inheritedType in
            inheritedType.type.trimmedDescription
                == "SwiftSemanticRule"
        }
    }
}

private func swiftFiles(
    below directory: URL
) throws -> [URL] {
    guard let enumerator = FileManager.default.enumerator(
        at: directory,
        includingPropertiesForKeys: [
            .isRegularFileKey,
        ],
        options: [
            .skipsHiddenFiles,
        ]
    ) else {
        return []
    }

    var result: [URL] = []

    for case let file as URL in enumerator {
        guard file.pathExtension == "swift" else {
            continue
        }

        let values = try file.resourceValues(
            forKeys: [
                .isRegularFileKey,
            ]
        )

        guard values.isRegularFile == true else {
            continue
        }

        result.append(
            file.standardizedFileURL
        )
    }

    return result.sorted { lhs, rhs in
        lhs.path < rhs.path
    }
}

private func render(
    ruleTypeNames: [String]
) -> String {
    let rules = ruleTypeNames
        .map { typeName in
            "                    \(typeName)(),"
        }
        .joined(
            separator: "\n"
        )

    return """
    // Generated by SwiftSemanticRuleCatalogGenerator.
    // Do not edit manually.

    public extension SwiftSemanticRuleSet {
        static var all: Self {
            get throws {
                try Self(
                    rules: [
    \(rules)
                    ]
                )
            }
        }
    }

    """
}
