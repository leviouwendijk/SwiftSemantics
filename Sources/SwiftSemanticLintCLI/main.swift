import Arguments
import Foundation
import Path
import PathParsing
import SwiftSemanticLintPresentation
import SwiftSemantics

@main
enum SwiftSemanticLintCLI:
    ArgumentCommandFallback
{
    static let name = "semlint"

    static func main() async {
        await ArgumentProgram.main(
            command: Self.self
        )
    }

    static func components() throws -> [CommandComponentLowerable] {
        [
            flag(
                "errors-only",
                help: "Fail only when an error-severity authored rule diagnostic is emitted."
            ),
            flag(
                "report-only",
                help: "Report diagnostics without returning a lint-enforcement failure."
            ),
            flag(
                "require-semicolons",
                help: "Require explicit semicolon termination for Swift declarations and statements."
            ),
            opt(
                "format",
                as: String.self,
                default: "terminal",
                help: "Diagnostic presentation format: terminal or compact."
            ),
            arg(
                "paths",
                as: String.self,
                arity: .variadic,
                help: "Swift path expressions relative to the package root. Use ** for recursive selection. Omit to lint library-product targets."
            ),
        ]
    }

    static func fallback(
        _ invocation: ParsedInvocation
    ) async throws {
        let errorsOnly = try invocation.flag(
            "errors-only"
        )
        let reportOnly = try invocation.flag(
            "report-only"
        )
        let requireSemicolons = try invocation.flag(
            "require-semicolons"
        )
        let format = try SemanticLintOutputFormat(
            argument: invocation.value(
                "format",
                as: String.self
            ) ?? "terminal"
        )
        let suppliedPaths = try invocation.values(
            "paths",
            as: String.self
        )
        let root = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath
        )
        .standardizedFileURL
        let workspace = SwiftSemanticWorkspace(
            root: root
        )
        let defaultLibrarySelection = suppliedPaths.isEmpty
        let files: [URL]

        if defaultLibrarySelection {
            files = try await workspace.swiftSourceFiles(
                forProductKinds: [
                    .library,
                ]
            )
        } else {
            files = try swiftFiles(
                expressions: suppliedPaths,
                root: root
            )
        }

        guard !files.isEmpty else {
            throw SemanticLintCLIError.noSwiftSources
        }

        let analyzer = SwiftSemanticRuleAnalyzer(
            ruleSet: try SwiftSemanticRuleSet.all
        )
        let context = SwiftSemanticRuleContext(
            configuration: .init(
                requireSemicolons: requireSemicolons
            ),
            sourceRole:
                defaultLibrarySelection
                ? .library
                : .unspecified,
            symbolResolver: workspace
        )
        var diagnostics: [SwiftSemanticRuleDiagnostic] = []

        for file in files {
            let source = try SwiftSemanticSource(
                file: file
            )
            let analysis = try await analyzer.analyze(
                source,
                context: context
            )

            diagnostics.append(
                contentsOf: analysis.diagnostics
            )
        }

        let result = SwiftSemanticLint.Result(
            files: files,
            diagnostics: diagnostics
        )
        let projection = SwiftSemanticLint.Projector(
            root: root
        )
        .project(
            result
        )
        let presenter: any SemanticLintPresenting

        switch format {
        case .terminal:
            presenter = SemanticLintPresenters.Terminal()
        case .compact:
            presenter = SemanticLintPresenters.Compact()
        }

        print(
            presenter.render(
                projection
            )
        )

        let failed = errorsOnly
            ? result.hasErrors
            : !result.diagnostics.isEmpty

        guard reportOnly || !failed else {
            throw SemanticLintViolation(
                diagnosticCount: result.summary.diagnostics,
                errorCount: result.summary.errors
            )
        }
    }
}

private enum SemanticLintCLIError:
    Error,
    LocalizedError
{
    case noSwiftSources
    case unsupportedFormat(String)

    var errorDescription: String? {
        switch self {
        case .noSwiftSources:
            return "No Swift source files were found."
        case .unsupportedFormat(let value):
            return "Unsupported lint output format '\(value)'. Use terminal or compact."
        }
    }
}

private enum SemanticLintOutputFormat:
    String,
    Sendable
{
    case terminal
    case compact

    init(
        argument: String
    ) throws {
        guard let value = Self(rawValue: argument) else {
            throw SemanticLintCLIError.unsupportedFormat(
                argument
            )
        }

        self = value
    }
}

private struct SemanticLintViolation:
    Error,
    LocalizedError
{
    let diagnosticCount: Int
    let errorCount: Int

    var errorDescription: String? {
        "Lint enforcement failed with \(diagnosticCount) diagnostic(s), including \(errorCount) error(s)."
    }
}

private func swiftFiles(
    expressions: [String],
    root: URL
) throws -> [URL] {
    let scan = try ParsedPathScan.scan(
        includes: expressions,
        relativeTo: .directoryURL(root)
    )
    let files: [URL] = scan.matches.compactMap {
        (match: PathScanMatch) -> URL? in
        guard match.type == .file,
              match.url.pathExtension == "swift" else {
            return nil
        }

        return match.url.standardizedFileURL
    }

    return Array(Set(files))
        .sorted { lhs, rhs in
            lhs.path < rhs.path
        }
}

