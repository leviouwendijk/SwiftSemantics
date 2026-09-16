import Arguments
import Foundation
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
                help: "Swift source files or directories to lint. Defaults to Sources."
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
        let paths = suppliedPaths.isEmpty
            ? ["Sources"]
            : suppliedPaths
        let root = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath
        )
        .standardizedFileURL
        let files = try swiftFiles(
            paths: paths,
            root: root
        )

        guard !files.isEmpty else {
            throw SemanticLintCLIError.noSwiftSources
        }

        let analyzer = SwiftSemanticRuleAnalyzer(
            ruleSet: try SwiftSemanticRuleSet.all
        )
        var diagnostics: [SwiftSemanticRuleDiagnostic] = []

        for file in files {
            let source = try SwiftSemanticSource(
                file: file
            )
            let analysis = try await analyzer.analyze(
                source
            )

            diagnostics.append(
                contentsOf: analysis.diagnostics
            )
        }

        for diagnostic in diagnostics {
            print(
                rendered(
                    diagnostic,
                    root: root
                )
            )
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
    case missingPath(String)
    case noSwiftSources

    var errorDescription: String? {
        switch self {
        case .missingPath(let path):
            return "Lint path does not exist: \(path)"

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
    paths: [String],
    root: URL
) throws -> [URL] {
    let manager = FileManager.default
    var files: Set<URL> = []

    for path in paths {
        let candidate = URL(
            fileURLWithPath: path,
            relativeTo: root
        )
        .standardizedFileURL
        var isDirectory: ObjCBool = false

        guard manager.fileExists(
            atPath: candidate.path,
            isDirectory: &isDirectory
        ) else {
            throw SemanticLintCLIError.missingPath(
                path
            )
        }

        if isDirectory.boolValue {
            guard let enumerator = manager.enumerator(
                at: candidate,
                includingPropertiesForKeys: [
                    .isRegularFileKey,
                ],
                options: [
                    .skipsHiddenFiles,
                ]
            ) else {
                continue
            }

            for case let file as URL in enumerator {
                guard file.pathExtension == "swift" else {
                    continue
                }

                let values = try file.resourceValues(
                    forKeys: [
                        .isRegularFileKey,
                    ]
                )

                if values.isRegularFile == true {
                    files.insert(
                        file.standardizedFileURL
                    )
                }
            }
        } else if candidate.pathExtension == "swift" {
            files.insert(
                candidate
            )
        }
    }

    return files.sorted { lhs, rhs in
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
