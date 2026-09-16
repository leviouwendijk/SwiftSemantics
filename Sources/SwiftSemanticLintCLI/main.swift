import Arguments
import Foundation
import Path
import PathParsing
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

        if !diagnostics.isEmpty {
            let renderedDiagnostics = diagnostics
                .map { diagnostic in
                    rendered(
                        diagnostic,
                        root: root
                    )
                }
                .joined(
                    separator: "\n\n"
                )

            print(
                renderedDiagnostics
            )
            print("")
        }

        let errors = diagnostics.count { diagnostic in
            diagnostic.severity == .error
        }
        let warnings = diagnostics.count { diagnostic in
            diagnostic.severity == .warning
        }
        let information = diagnostics.count { diagnostic in
            diagnostic.severity == .information
        }
        let hints = diagnostics.count { diagnostic in
            diagnostic.severity == .hint
        }

        print(
            "semlint: \(files.count) file(s), \(diagnostics.count) diagnostic(s), \(errors) error(s), \(warnings) warning(s), \(information) information, \(hints) hint(s)"
        )

        let failed = errorsOnly
            ? errors > 0
            : !diagnostics.isEmpty

        guard !failed else {
            throw SemanticLintViolation(
                diagnosticCount: diagnostics.count,
                errorCount: errors
            )
        }
    }
}

private enum SemanticLintCLIError:
    Error,
    LocalizedError
{
    case noSwiftSources

    var errorDescription: String? {
        switch self {
        case .noSwiftSources:
            return "No Swift source files were found."
        }
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

private func rendered(
    _ diagnostic: SwiftSemanticRuleDiagnostic,
    root: URL
) -> String {
    let file = diagnostic.file.map { file in
        displayPath(
            file,
            root: root
        )
    } ?? "<source>"
    let range: String

    if let lineRange = diagnostic.lineRange {
        range = ":\(lineRange.start)-\(lineRange.end)"
    } else {
        range = ""
    }

    return "\(file)\(range): \(diagnostic.severity.rawValue) \(diagnostic.ruleID.rawValue): \(diagnostic.message)"
}

private func displayPath(
    _ file: URL,
    root: URL
) -> String {
    let rootPrefix = root.path.hasSuffix("/")
        ? root.path
        : root.path + "/"

    guard file.path.hasPrefix(rootPrefix) else {
        return file.path
    }

    return String(
        file.path.dropFirst(
            rootPrefix.count
        )
    )
}
