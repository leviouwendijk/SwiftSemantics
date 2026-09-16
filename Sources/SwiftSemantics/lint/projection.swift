import Excerpt
import Foundation
import Position

public protocol SemanticLintProjecting:
    Sendable
{
    func project(
        _ result: SwiftSemanticLint.Result
    ) -> SwiftSemanticLint.Projection
}

public protocol SemanticLintPresenting:
    Sendable
{
    func render(
        _ projection: SwiftSemanticLint.Projection
    ) -> String
}

public extension SwiftSemanticLint {
    struct Projection:
        Sendable,
        Codable,
        Hashable
    {
        public struct Diagnostic:
            Sendable,
            Codable,
            Hashable
        {
            public let ruleID: SwiftSemanticRuleID
            public let severity: SwiftSemanticRuleSeverity
            public let path: String
            public let lineRange: LineRange?
            public let message: String
            public let suggestion: String?

            public init(
                ruleID: SwiftSemanticRuleID,
                severity: SwiftSemanticRuleSeverity,
                path: String,
                lineRange: LineRange?,
                message: String,
                suggestion: String? = nil
            ) {
                self.ruleID = ruleID
                self.severity = severity
                self.path = path
                self.lineRange = lineRange
                self.message = message
                self.suggestion = suggestion
            }
        }

        public struct DiagnosticGroup:
            Sendable,
            Codable,
            Hashable
        {
            public let lineRange: LineRange
            public let diagnostics: [Diagnostic]

            public init(
                lineRange: LineRange,
                diagnostics: [Diagnostic]
            ) {
                self.lineRange = lineRange
                self.diagnostics = diagnostics
            }
        }

        public struct SourceWindow:
            Sendable,
            Codable,
            Hashable
        {
            public let startLine: Int
            public let lines: [String]
            public let groups: [DiagnosticGroup]

            public init(
                startLine: Int,
                lines: [String],
                groups: [DiagnosticGroup]
            ) {
                self.startLine = startLine
                self.lines = lines
                self.groups = groups
            }

            public var endLine: Int {
                startLine + max(
                    0,
                    lines.count - 1
                )
            }
        }

        public struct SourceFile:
            Sendable,
            Codable,
            Hashable
        {
            public let path: String
            public let windows: [SourceWindow]

            public init(
                path: String,
                windows: [SourceWindow]
            ) {
                self.path = path
                self.windows = windows
            }
        }

        public let diagnostics: [Diagnostic]
        public let sourceFiles: [SourceFile]
        public let summary: Result.Summary

        public init(
            diagnostics: [Diagnostic],
            sourceFiles: [SourceFile] = [],
            summary: Result.Summary
        ) {
            self.diagnostics = diagnostics
            self.sourceFiles = sourceFiles
            self.summary = summary
        }
    }

    struct Projector:
        SemanticLintProjecting
    {
        public struct Options:
            Sendable,
            Codable,
            Hashable
        {
            public let contextLines: UInt
            public let mergeGap: UInt

            public init(
                contextLines: UInt = 2,
                mergeGap: UInt = 0
            ) {
                self.contextLines = contextLines
                self.mergeGap = mergeGap
            }
        }

        public let root: URL
        public let options: Options

        public init(
            root: URL,
            options: Options = .init()
        ) {
            self.root = root.standardizedFileURL
            self.options = options
        }

        public func project(
            _ result: Result
        ) -> Projection {
            let diagnostics = result.diagnostics.map(
                projectDiagnostic
            )

            return .init(
                diagnostics: diagnostics,
                sourceFiles: projectSourceFiles(
                    rawDiagnostics: result.diagnostics,
                    diagnostics: diagnostics
                ),
                summary: result.summary
            )
        }

        private func projectDiagnostic(
            _ diagnostic: SwiftSemanticRuleDiagnostic
        ) -> Projection.Diagnostic {
            let parts = messageParts(
                diagnostic.message
            )

            return .init(
                ruleID: diagnostic.ruleID,
                severity: diagnostic.severity,
                path: displayPath(
                    diagnostic.file
                ),
                lineRange: diagnostic.lineRange,
                message: parts.message,
                suggestion: parts.suggestion
            )
        }

        private func projectSourceFiles(
            rawDiagnostics: [SwiftSemanticRuleDiagnostic],
            diagnostics: [Projection.Diagnostic]
        ) -> [Projection.SourceFile] {
            var grouped: [URL: [Projection.Diagnostic]] = [:]

            for (
                rawDiagnostic,
                diagnostic
            ) in zip(
                rawDiagnostics,
                diagnostics
            ) {
                guard let file = rawDiagnostic.file?.standardizedFileURL,
                    diagnostic.lineRange != nil
                else {
                    continue
                }

                grouped[
                    file,
                    default: []
                ]
                .append(
                    diagnostic
                )
            }

            return grouped.keys
                .sorted { lhs, rhs in
                    lhs.path < rhs.path
                }
                .compactMap { file in
                    sourceFile(
                        file,
                        diagnostics: grouped[file] ?? []
                    )
                }
        }

        private func sourceFile(
            _ file: URL,
            diagnostics: [Projection.Diagnostic]
        ) -> Projection.SourceFile? {
            guard let contents = try? String(
                contentsOf: file,
                encoding: .utf8
            ) else {
                return nil
            }

            let lines = sourceLines(
                contents
            )
            let excerpt = SourceExcerpt.make(
                file: file,
                lines: lines,
                ranges: diagnostics.compactMap(
                    \.lineRange
                ),
                options: .init(
                    contextLines: options.contextLines,
                    mergeGap: options.mergeGap
                )
            )

            guard !excerpt.windows.isEmpty else {
                return nil
            }

            return .init(
                path: displayPath(
                    file
                ),
                windows: excerpt.windows.map { window in
                    .init(
                        startLine: window.slice.startLine,
                        lines: window.slice.lines,
                        groups: window.ranges.map { range in
                            .init(
                                lineRange: range,
                                diagnostics: diagnostics.filter { diagnostic in
                                    diagnostic.lineRange == range
                                }
                            )
                        }
                    )
                }
            )
        }

        private func sourceLines(
            _ source: String
        ) -> [String] {
            let normalized = source
                .replacingOccurrences(
                    of: "\r\n",
                    with: "\n"
                )
                .replacingOccurrences(
                    of: "\r",
                    with: "\n"
                )

            guard !normalized.isEmpty else {
                return []
            }

            var lines = normalized
                .split(
                    separator: "\n",
                    omittingEmptySubsequences: false
                )
                .map(String.init)

            if normalized.hasSuffix("\n") {
                lines.removeLast()
            }

            return lines
        }

        private func displayPath(
            _ file: URL?
        ) -> String {
            guard let file else {
                return "<source>"
            }

            let standardizedFile = file.standardizedFileURL
            let rootPrefix = root.path.hasSuffix("/")
                ? root.path
                : root.path + "/"

            guard standardizedFile.path.hasPrefix(rootPrefix) else {
                return standardizedFile.path
            }

            return String(
                standardizedFile.path.dropFirst(
                    rootPrefix.count
                )
            )
        }

        private func messageParts(
            _ message: String
        ) -> (
            message: String,
            suggestion: String?
        ) {
            guard let range = message.range(
                of: " Consider "
            ) else {
                return (
                    message,
                    nil
                )
            }

            return (
                String(
                    message[..<range.lowerBound]
                ),
                "Consider " + String(
                    message[range.upperBound...]
                )
            )
        }
    }
}
