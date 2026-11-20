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
                    3,
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
                try Expect.equal(
                    result.summary.hints,
                    1,
                    "lint result hint count"
                )
                try Expect.true(
                    result.hasErrors,
                    "lint result has errors"
                )
            }

            Step(
                "project paths suggestions and grouped source excerpts"
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
                    projection.sourceFiles.count,
                    2,
                    "source projection file count"
                )

                guard let foo = projection.sourceFiles.first(
                    where: { sourceFile in
                        sourceFile.path == "Sources/Foo.swift"
                    }
                ) else {
                    try Expect.true(
                        false,
                        "Foo source projection exists"
                    )
                    return
                }

                try Expect.equal(
                    foo.windows.count,
                    1,
                    "same-range diagnostics share one source window"
                )
                try Expect.equal(
                    foo.windows[0].groups.count,
                    1,
                    "exact range is grouped once"
                )
                try Expect.equal(
                    foo.windows[0].groups[0].diagnostics.count,
                    2,
                    "exact range retains both diagnostics"
                )
                try Expect.equal(
                    foo.windows[0].startLine,
                    1,
                    "source excerpt context start"
                )
                try Expect.equal(
                    foo.windows[0].endLine,
                    7,
                    "source excerpt context end"
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
                        "semlint: 2 file(s), 3 diagnostic(s), 1 error(s), 1 warning(s), 0 information, 1 hint(s)"
                    ),
                    "compact summary"
                )
            }

            Step(
                "terminal presenter renders grouped rounded ANSI source boxes"
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
                    rendered.contains("╭─ "),
                    "terminal presenter rounded top border"
                )
                try Expect.true(
                    rendered.contains("╰"),
                    "terminal presenter rounded bottom border"
                )
                try Expect.true(
                    rendered.contains("Sources/Foo.swift:1-7"),
                    "terminal excerpt location"
                )
                try Expect.true(
                    rendered.contains("let beta = 2"),
                    "terminal source excerpt"
                )
                try Expect.true(
                    rendered.contains("! warning"),
                    "terminal warning marker"
                )
                try Expect.true(
                    rendered.contains("· hint"),
                    "terminal same-range hint marker"
                )
                try Expect.true(
                    rendered.contains("× error"),
                    "terminal error marker"
                )
                try Expect.true(
                    rendered.contains("─ lines 3-5"),
                    "terminal exact-range group"
                )
                try Expect.true(
                    rendered.contains("─ suggestion"),
                    "terminal suggestion delimiter"
                )
                try Expect.true(
                    rendered.contains("Consider nesting it."),
                    "terminal suggestion"
                )
                try Expect.equal(
                    occurrences(
                        of: "let beta = 2",
                        in: rendered
                    ),
                    1,
                    "same-range diagnostics do not duplicate source text"
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
    try writeFixtureSources()

    return .init(
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
                ruleID: .excessiveSymbolComponents,
                severity: .hint,
                message: "Related naming family.",
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

private func writeFixtureSources() throws {
    let sourceDirectory = fixtureRoot.appending(
        path: "Sources"
    )

    try FileManager.default.createDirectory(
        at: sourceDirectory,
        withIntermediateDirectories: true
    )

    let foo = [
        "struct Foo {",
        "    let alpha = 1",
        "    let beta = 2",
        "    let gamma = 3",
        "    let delta = 4",
        "    let epsilon = 5",
        "}",
        "",
    ]
    .joined(
        separator: "\n"
    )
    let bar = [
        "struct Bar {",
        "    let one = 1",
        "    let two = 2",
        "    let three = 3",
        "    let four = 4",
        "    let five = 5",
        "    let six = 6",
        "    let seven = 7",
        "  let bad = true",
        "    let ten = 10",
        "}",
    ]
    .joined(
        separator: "\n"
    )

    try foo.write(
        to: sourceDirectory.appending(
            path: "Foo.swift"
        ),
        atomically: true,
        encoding: .utf8
    )
    try bar.write(
        to: sourceDirectory.appending(
            path: "Bar.swift"
        ),
        atomically: true,
        encoding: .utf8
    )
}

private func occurrences(
    of needle: String,
    in haystack: String
) -> Int {
    guard !needle.isEmpty else {
        return 0
    }

    return haystack
        .components(
            separatedBy: needle
        )
        .count - 1
}
