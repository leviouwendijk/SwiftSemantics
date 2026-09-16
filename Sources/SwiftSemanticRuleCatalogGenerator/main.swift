import Arguments
import Foundation
import SwiftParser
import SwiftSyntax

@main
enum SwiftSemanticRuleCatalogGenerator:
    ArgumentCommandFallback
{
    private enum Mode {
        case write
        case check
    }

    static let name = "semrules"

    static func main() async {
        await ArgumentProgram.main(
            command: Self.self
        )
    }

    static func components() throws -> [CommandComponentLowerable] {
        [
            flag(
                "check",
                help: "Fail when the checked-in generated rule catalog is stale."
            ),
            arg(
                "rules_directory",
                as: String.self,
                arity: .optional,
                help: "Optional rules directory. Must be supplied together with output_file."
            ),
            arg(
                "output_file",
                as: String.self,
                arity: .optional,
                help: "Optional generated output file. Must be supplied together with rules_directory."
            ),
        ]
    }

    static func fallback(
        _ invocation: ParsedInvocation
    ) async throws {
        let mode: Mode = try invocation.flag(
            "check"
        )
            ? .check
            : .write
        let rulesPath = try invocation.value(
            "rules_directory",
            as: String.self
        )
        let outputPath = try invocation.value(
            "output_file",
            as: String.self
        )

        guard (rulesPath == nil) == (outputPath == nil) else {
            throw GeneratorError.invalidArguments
        }

        let root = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath
        )
        .standardizedFileURL
        let defaultRulesDirectory = root.appending(
            path: "Sources/SwiftSemantics/rules"
        )
        let rulesDirectory = rulesPath.map { path in
            URL(
                fileURLWithPath: path
            )
            .standardizedFileURL
        } ?? defaultRulesDirectory
        let output = outputPath.map { path in
            URL(
                fileURLWithPath: path
            )
            .standardizedFileURL
        } ?? rulesDirectory.appending(
            path: "swift-semantic-rule-catalog.generated.swift"
        )

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

        switch mode {
        case .write:
            try FileManager.default.createDirectory(
                at: output.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try generated.write(
                to: output,
                atomically: true,
                encoding: .utf8
            )

        case .check:
            guard FileManager.default.fileExists(
                atPath: output.path
            ) else {
                throw GeneratorError.staleCatalog
            }

            let existing = try String(
                contentsOf: output,
                encoding: .utf8
            )

            guard existing == generated else {
                throw GeneratorError.staleCatalog
            }
        }
    }
}

private enum GeneratorError:
    Error,
    LocalizedError
{
    case invalidArguments
    case noRulesDiscovered
    case staleCatalog

    var errorDescription: String? {
        switch self {
        case .invalidArguments:
            return "Run with no arguments, with --check, with rules-directory and output-file arguments, or with --check followed by rules-directory and output-file arguments."

        case .noRulesDiscovered:
            return "No concrete SwiftSemanticRule declarations were discovered."

        case .staleCatalog:
            return "Generated Swift semantic rule catalog is stale. Run 'swift run semrules' and commit the generated output."
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
