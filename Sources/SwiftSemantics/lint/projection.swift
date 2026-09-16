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

        public let diagnostics: [Diagnostic]
        public let summary: Result.Summary

        public init(
            diagnostics: [Diagnostic],
            summary: Result.Summary
        ) {
            self.diagnostics = diagnostics
            self.summary = summary
        }
    }

    struct Projector:
        SemanticLintProjecting
    {
        public let root: URL

        public init(
            root: URL
        ) {
            self.root = root.standardizedFileURL
        }

        public func project(
            _ result: Result
        ) -> Projection {
            .init(
                diagnostics: result.diagnostics.map { diagnostic in
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
                },
                summary: result.summary
            )
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
