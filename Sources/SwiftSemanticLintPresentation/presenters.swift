import ANSI
import ExcerptPresentation
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
            let blocks = projection.sourceFiles.flatMap { sourceFile in
                sourceFile.windows.map { window in
                    sourceBlock(
                        sourceFile: sourceFile,
                        window: window
                    )
                }
            }
            let boxedDiagnostics = Set(
                projection.sourceFiles.flatMap { sourceFile in
                    sourceFile.windows.flatMap { window in
                        window.groups.flatMap(
                            \.diagnostics
                        )
                    }
                }
            )
            let standalone = projection.diagnostics
                .filter { diagnostic in
                    !boxedDiagnostics.contains(
                        diagnostic
                    )
                }
                .map(
                    renderStandalone
                )
            var sections: [String] = []

            if !blocks.isEmpty {
                sections.append(
                    LinePresentation.Basic.render(
                        .init(
                            blocks: blocks
                        ),
                        styling: SemanticLintStyling()
                    )
                )
            }

            if !standalone.isEmpty {
                sections.append(
                    standalone.joined(
                        separator: "\n\n"
                    )
                )
            }

            sections.append(
                summary(
                    projection.summary
                )
            )

            return sections.joined(
                separator: "\n\n"
            )
        }

        private func sourceBlock(
            sourceFile: SwiftSemanticLint.Projection.SourceFile,
            window: SwiftSemanticLint.Projection.SourceWindow
        ) -> LinePresentation.Block {
            var rows = sourceRows(
                window
            )

            rows.append(
                .init(
                    segments: [
                        .init(
                            text: ""
                        ),
                    ]
                )
            )

            for (
                index,
                group
            ) in window.groups.enumerated() {
                rows.append(
                    groupRangeRow(
                        group
                    )
                )

                for diagnostic in group.diagnostics {
                    rows.append(
                        diagnosticHeadingRow(
                            diagnostic
                        )
                    )
                    rows.append(
                        .init(
                            segments: [
                                .init(
                                    text: "  " + diagnostic.message
                                ),
                            ]
                        )
                    )

                    if let suggestion = diagnostic.suggestion {
                        rows.append(
                            .init(
                                segments: [
                                    .init(
                                        role: .suggestionLabel,
                                        text: "  ─ suggestion"
                                    ),
                                ]
                            )
                        )
                        rows.append(
                            .init(
                                segments: [
                                    .init(
                                        text: "  " + suggestion
                                    ),
                                ]
                            )
                        )
                    }
                }

                if index < window.groups.count - 1 {
                    rows.append(
                        .init(
                            segments: [
                                .init(
                                    text: ""
                                ),
                            ]
                        )
                    )
                }
            }

            return .init(
                title: .init(
                    role: .path,
                    text: "\(sourceFile.path):\(window.startLine)-\(window.endLine)"
                ),
                rows: rows,
                border: .rounded
            )
        }

        private func sourceRows(
            _ window: SwiftSemanticLint.Projection.SourceWindow
        ) -> [LinePresentation.Row] {
            let width = String(
                window.endLine
            ).count

            return window.lines.enumerated().map {
                offset,
                source in

                let lineNumber = window.startLine + offset
                let severity = highestSeverity(
                    at: lineNumber,
                    in: window.groups
                )
                let marker = severity == nil
                    ? " "
                    : "▶"

                return .init(
                    gutter: .init(
                        columns: [
                            .init(
                                text: marker,
                                width: 1,
                                role: severity.map(
                                    severityRole
                                )
                            ),
                            .number(
                                lineNumber,
                                width: width,
                                role: .lineNumber
                            ),
                            .init(
                                text: "│",
                                role: .gutter
                            ),
                        ],
                        separator: " "
                    ),
                    segments: [
                        .init(
                            role: .source,
                            text: source
                        ),
                    ]
                )
            }
        }

        private func groupRangeRow(
            _ group: SwiftSemanticLint.Projection.DiagnosticGroup
        ) -> LinePresentation.Row {
            .init(
                segments: [
                    .init(
                        role: .range,
                        text: "─ lines \(group.lineRange.start)-\(group.lineRange.end)"
                    ),
                ]
            )
        }

        private func diagnosticHeadingRow(
            _ diagnostic: SwiftSemanticLint.Projection.Diagnostic
        ) -> LinePresentation.Row {
            .init(
                segments: [
                    .init(
                        role: severityRole(
                            diagnostic.severity
                        ),
                        text: severityLabel(
                            diagnostic.severity
                        )
                    ),
                    .init(
                        role: .rule,
                        text: diagnostic.ruleID.rawValue
                    ),
                ],
                componentSpacing: 2
            )
        }

        private func renderStandalone(
            _ diagnostic: SwiftSemanticLint.Projection.Diagnostic
        ) -> String {
            var lines = [
                styledSeverity(
                    diagnostic.severity
                )
                    + "  "
                    + diagnostic.ruleID.rawValue.ansi(
                        .dim
                    ),
                "    "
                    + "in".ansi(
                        .dim
                    )
                    + "  "
                    + location(
                        diagnostic
                    ),
                "",
                "    " + diagnostic.message,
            ]

            if let suggestion = diagnostic.suggestion {
                lines.append("")
                lines.append(
                    "    "
                        + "─ suggestion".ansi(
                            .dim
                        )
                )
                lines.append(
                    "    " + suggestion
                )
            }

            return lines.joined(
                separator: "\n"
            )
        }

        private func highestSeverity(
            at lineNumber: Int,
            in groups: [SwiftSemanticLint.Projection.DiagnosticGroup]
        ) -> SwiftSemanticRuleSeverity? {
            var selected: SwiftSemanticRuleSeverity?

            for group in groups
            where lineNumber >= group.lineRange.start
                && lineNumber <= group.lineRange.end
            {
                for diagnostic in group.diagnostics {
                    guard let current = selected else {
                        selected = diagnostic.severity
                        continue
                    }

                    if severityRank(
                        diagnostic.severity
                    ) > severityRank(
                        current
                    ) {
                        selected = diagnostic.severity
                    }
                }
            }

            return selected
        }

        private func severityRank(
            _ severity: SwiftSemanticRuleSeverity
        ) -> Int {
            switch severity {
            case .error:
                return 4
            case .warning:
                return 3
            case .information:
                return 2
            case .hint:
                return 1
            }
        }
    }
}

private struct SemanticLintStyling:
    LinePresentationStyling
{
    func render(
        role: LinePresentation.Role?,
        text: String
    ) -> String {
        guard let role else {
            return text
        }

        switch role.rawValue {
        case "semantic_lint.error":
            return text.ansi(
                .bold,
                .brightRed
            )

        case "semantic_lint.warning":
            return text.ansi(
                .bold,
                .yellow
            )

        case "semantic_lint.information":
            return text.ansi(
                .cyan
            )

        case "semantic_lint.hint":
            return text.ansi(
                .dim,
                .cyan
            )

        case "semantic_lint.path",
             "semantic_lint.rule",
             "semantic_lint.range",
             "semantic_lint.line_number",
             "semantic_lint.gutter",
             "semantic_lint.suggestion_label":
            return text.ansi(
                .dim
            )

        case "semantic_lint.source":
            return text

        default:
            return text
        }
    }
}

private extension LinePresentation.Role {
    static let error = Self(
        "semantic_lint.error"
    )
    static let warning = Self(
        "semantic_lint.warning"
    )
    static let information = Self(
        "semantic_lint.information"
    )
    static let hint = Self(
        "semantic_lint.hint"
    )
    static let path = Self(
        "semantic_lint.path"
    )
    static let rule = Self(
        "semantic_lint.rule"
    )
    static let range = Self(
        "semantic_lint.range"
    )
    static let lineNumber = Self(
        "semantic_lint.line_number"
    )
    static let gutter = Self(
        "semantic_lint.gutter"
    )
    static let source = Self(
        "semantic_lint.source"
    )
    static let suggestionLabel = Self(
        "semantic_lint.suggestion_label"
    )
}

private func severityRole(
    _ severity: SwiftSemanticRuleSeverity
) -> LinePresentation.Role {
    switch severity {
    case .error:
        return .error
    case .warning:
        return .warning
    case .information:
        return .information
    case .hint:
        return .hint
    }
}

private func severityLabel(
    _ severity: SwiftSemanticRuleSeverity
) -> String {
    switch severity {
    case .error:
        return "× error"
    case .warning:
        return "! warning"
    case .information:
        return "i information"
    case .hint:
        return "· hint"
    }
}

private func styledSeverity(
    _ severity: SwiftSemanticRuleSeverity
) -> String {
    let text = severityLabel(
        severity
    )

    switch severity {
    case .error:
        return text.ansi(
            .bold,
            .brightRed
        )
    case .warning:
        return text.ansi(
            .bold,
            .yellow
        )
    case .information:
        return text.ansi(
            .cyan
        )
    case .hint:
        return text.ansi(
            .dim,
            .cyan
        )
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
