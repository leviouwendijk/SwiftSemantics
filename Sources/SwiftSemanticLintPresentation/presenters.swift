import ANSI
import SwiftSemantics

public enum SemanticLintPresenters {}

public extension SemanticLintPresenters {
    struct Compact:
        SemanticLintPresenting
    {
        public init() {}

        public func render(
            _ projection: SwiftSemanticLint.Projection
        ) -> String {
            let diagnostics = projection.diagnostics.map { diagnostic in
                let suggestion = diagnostic.suggestion.map { suggestion in
                    " " + suggestion
                } ?? ""

                return "\(location(diagnostic)): \(diagnostic.severity.rawValue) \(diagnostic.ruleID.rawValue): \(diagnostic.message)\(suggestion)"
            }

            return (
                diagnostics
                + [
                    summary(projection.summary),
                ]
            )
            .joined(
                separator: "\n"
            )
        }
    }

    struct Terminal:
        SemanticLintPresenting
    {
        public init() {}

        public func render(
            _ projection: SwiftSemanticLint.Projection
        ) -> String {
            let diagnostics = projection.diagnostics.map { diagnostic in
                renderDiagnostic(
                    diagnostic
                )
            }

            guard !diagnostics.isEmpty else {
                return summary(
                    projection.summary
                )
            }

            return diagnostics.joined(
                separator: "\n\n"
            )
                + "\n\n"
                + summary(
                    projection.summary
                )
        }

        private func renderDiagnostic(
            _ diagnostic: SwiftSemanticLint.Projection.Diagnostic
        ) -> String {
            var lines = [
                heading(diagnostic),
                "    " + "in".ansi(.dim) + "  " + location(diagnostic),
                "",
                "    " + diagnostic.message,
            ]

            if let suggestion = diagnostic.suggestion {
                lines.append("")
                lines.append(
                    "    " + "─ suggestion".ansi(.dim)
                )
                lines.append(
                    "    " + suggestion
                )
            }

            return lines.joined(
                separator: "\n"
            )
        }

        private func heading(
            _ diagnostic: SwiftSemanticLint.Projection.Diagnostic
        ) -> String {
            let severity: String

            switch diagnostic.severity {
            case .error:
                severity = "× error".ansi(
                    .bold,
                    .brightRed
                )
            case .warning:
                severity = "! warning".ansi(
                    .bold,
                    .yellow
                )
            case .information:
                severity = "i information".ansi(
                    .cyan
                )
            case .hint:
                severity = "· hint".ansi(
                    .dim,
                    .cyan
                )
            }

            return severity
                + "  "
                + diagnostic.ruleID.rawValue.ansi(
                    .dim
                )
        }
    }
}

private func location(
    _ diagnostic: SwiftSemanticLint.Projection.Diagnostic
) -> String {
    guard let range = diagnostic.lineRange else {
        return diagnostic.path
    }

    return "\(diagnostic.path):\(range.start)-\(range.end)"
}

private func summary(
    _ summary: SwiftSemanticLint.Result.Summary
) -> String {
    "semlint: \(summary.files) file(s), \(summary.diagnostics) diagnostic(s), \(summary.errors) error(s), \(summary.warnings) warning(s), \(summary.information) information, \(summary.hints) hint(s)"
}
