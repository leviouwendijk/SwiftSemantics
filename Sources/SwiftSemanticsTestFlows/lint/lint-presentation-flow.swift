import Foundation
import SwiftSemanticLintPresentation
import SwiftSemantics
import TestFlows

extension SwiftSemanticsFlowSuite {
    static var lintPresentationFlow: TestFlow {
        TestFlow(
            "semantic-lint-presentation",
            tags: [
                "lint",
                "presentation",
                "projection",
                "regression",
                "result",
                "swift-semantics",
            ]
        ) {
            Step(
                "aggregate a typed whole-run result"
            ) {
                let result = try fixtureLintResult()

                try Expect.equal(
                    result.summary.files,
                    2,
                    "lint result file count"
                )
                try Expect.equal(
                    result.summary.diagnostics,
                    2,
                    "lint result diagnostic count"
                )
                try Expect.equal(
                    result.summary.errors,
                    1,
                    "lint result error count"
                )
                try Expect.equal(
                    result.summary.warnings,
                    1,
                    "lint result warning count"
                )
                try Expect.true(
                    result.hasErrors,
                    "lint result has errors"
                )
            }

            Step(
                "project paths and suggestions independently of presentation"
            ) {
                let projection = SwiftSemanticLint.Projector(
                    root: fixtureRoot
                )
                .project(
                    try fixtureLintResult()
                )

                try Expect.equal(
                    projection.diagnostics[0].path,
                    "Sources/Foo.swift",
                    "projection relative path"
                )
                try Expect.equal(
                    projection.diagnostics[0].message,
                    "Symbol is too long.",
                    "projection message"
                )
                try Expect.equal(
                    projection.diagnostics[0].suggestion,
                    "Consider nesting it.",
                    "projection suggestion"
                )
                try Expect.equal(
                    projection.diagnostics[1].suggestion,
                    nil,
                    "projection optional suggestion"
                )
            }

            Step(
                "compact presenter preserves one-line diagnostic form"
            ) {
                let projection = SwiftSemanticLint.Projector(
                    root: fixtureRoot
                )
                .project(
                    try fixtureLintResult()
                )
                let rendered = SemanticLintPresenters.Compact()
                    .render(
                        projection
                    )

                try Expect.true(
                    rendered.contains(
                        "Sources/Foo.swift:3-5: warning excessive_symbol_components: Symbol is too long. Consider nesting it."
                    ),
                    "compact warning line"
                )
                try Expect.true(
                    rendered.contains(
                        "Sources/Bar.swift:9-9: error indentation: Use four spaces."
                    ),
                    "compact error line"
                )
                try Expect.true(
                    rendered.hasSuffix(
                        "semlint: 2 file(s), 2 diagnostic(s), 1 error(s), 1 warning(s), 0 information, 0 hint(s)"
                    ),
                    "compact summary"
                )
            }

            Step(
                "terminal presenter renders ANSI severity blocks"
            ) {
                let projection = SwiftSemanticLint.Projector(
                    root: fixtureRoot
                )
                .project(
                    try fixtureLintResult()
                )
                let rendered = SemanticLintPresenters.Terminal()
                    .render(
                        projection
                    )

                try Expect.true(
                    rendered.contains("\u{001B}["),
                    "terminal presenter contains ANSI"
                )
                try Expect.true(
                    rendered.contains("! warning"),
                    "terminal warning marker"
                )
                try Expect.true(
                    rendered.contains("× error"),
                    "terminal error marker"
                )
                try Expect.true(
                    rendered.contains("Sources/Foo.swift:3-5"),
                    "terminal location"
                )
                try Expect.true(
                    rendered.contains("─ suggestion"),
                    "terminal suggestion delimiter"
                )
                try Expect.true(
                    rendered.contains("Consider nesting it."),
                    "terminal suggestion"
                )
            }
        }
    }
}

private let fixtureRoot = URL(
    fileURLWithPath: "/tmp/SemanticLintFixture",
    isDirectory: true
)

private func fixtureLintResult() throws -> SwiftSemanticLint.Result {
    .init(
        files: [
            fixtureRoot.appending(
                path: "Sources/Foo.swift"
            ),
            fixtureRoot.appending(
                path: "Sources/Bar.swift"
            ),
        ],
        diagnostics: [
            .init(
                ruleID: .excessiveSymbolComponents,
                severity: .warning,
                message: "Symbol is too long. Consider nesting it.",
                file: fixtureRoot.appending(
                    path: "Sources/Foo.swift"
                ),
                lineRange: try .init(
                    start: 3,
                    end: 5
                )
            ),
            .init(
                ruleID: .indentation,
                severity: .error,
                message: "Use four spaces.",
                file: fixtureRoot.appending(
                    path: "Sources/Bar.swift"
                ),
                lineRange: try .init(
                    start: 9,
                    end: 9
                )
            ),
        ]
    )
}
