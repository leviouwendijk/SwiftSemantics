import Foundation
import SwiftSemantics
import TestFlows

extension SwiftSemanticsFlowSuite {
    static var semanticRuleFoundationFlow: TestFlow {
        TestFlow(
            "semantic-rule-foundation",
            tags: [
                "swift-semantics",
                "swift-syntax",
                "rules",
                "source",
                "regression",
            ]
        ) {
            Step(
                "reuse one parsed source across structural consumers"
            ) {
                let fixture = try SwiftSemanticRuleFoundationFixture()

                defer {
                    fixture.remove()
                }

                let source = try SwiftSemanticSource(
                    file: fixture.source
                )
                let symbols = SwiftSemanticSymbolCollector()
                    .collect(
                        in: source
                    )
                let selections = try SwiftSemanticStructureInspector()
                    .selections(
                        in: source,
                        query: .type(
                            named: "Widget"
                        )
                    )

                let widget = try Expect.notNil(
                    symbols.first { symbol in
                        symbol.kind == .struct
                            && symbol.name == "Widget"
                    },
                    "Widget structural symbol"
                )

                try Expect.equal(
                    widget.lineRange.start,
                    3,
                    "Widget starts on fixture line 3"
                )

                let selection = try Expect.notNil(
                    selections.first,
                    "Widget structural selection"
                )

                try Expect.equal(
                    selection.symbolName,
                    "Widget",
                    "shared parsed source resolves Widget selection"
                )
            }

            Step(
                "analyze an in-memory source with an authored rule"
            ) {
                let source = SwiftSemanticSource(
                    source: "struct Widget {}"
                )
                let ruleSet = try SwiftSemanticRuleSet(
                    rules: [
                        SemanticSourceProbeRule(),
                    ]
                )
                let analysis = try await SwiftSemanticRuleAnalyzer(
                    ruleSet: ruleSet
                )
                .analyze(
                    source
                )

                try Expect.equal(
                    analysis.diagnostics.count,
                    1,
                    "probe rule diagnostic count"
                )

                let diagnostic = try Expect.notNil(
                    analysis.diagnostics.first,
                    "probe rule diagnostic"
                )

                try Expect.equal(
                    diagnostic.ruleID,
                    .init(
                        rawValue: "semantic_source_probe"
                    ),
                    "probe rule identifier"
                )
                try Expect.equal(
                    diagnostic.severity,
                    .warning,
                    "probe rule severity"
                )
                try Expect.true(
                    !analysis.hasErrors,
                    "warning-only rule analysis has no errors"
                )
            }

            Step(
                "reject duplicate rule identifiers at construction"
            ) {
                var rejectedIdentifier: SwiftSemanticRuleID?

                do {
                    _ = try SwiftSemanticRuleSet(
                        rules: [
                            SemanticSourceProbeRule(),
                            SemanticSourceProbeRule(),
                        ]
                    )
                } catch SwiftSemanticRuleSetError.duplicateRuleID(let identifier) {
                    rejectedIdentifier = identifier
                }

                try Expect.equal(
                    rejectedIdentifier,
                    .init(
                        rawValue: "semantic_source_probe"
                    ),
                    "duplicate rule identifier is rejected at the construction seam"
                )
            }
        }
    }
}

private struct SemanticSourceProbeRule:
    SwiftSemanticRule
{
    let id = SwiftSemanticRuleID(
        rawValue: "semantic_source_probe"
    )

    func diagnostics(
        in source: SwiftSemanticSource,
        context: SwiftSemanticRuleContext
    ) async throws -> [SwiftSemanticRuleDiagnostic] {
        _ = context

        return [
            .init(
                ruleID: id,
                severity: .warning,
                message: "Semantic source probe diagnostic.",
                file: source.file
            ),
        ]
    }
}

private struct SwiftSemanticRuleFoundationFixture {
    let root: URL
    let source: URL

    init() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "swift-semantics-rule-foundation-\(UUID().uuidString)",
                isDirectory: true
            )
        let source = root
            .appendingPathComponent(
                "Widget.swift"
            )

        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        try """
        import Foundation

        struct Widget {
            let value: Int
        }
        """
        .write(
            to: source,
            atomically: true,
            encoding: .utf8
        )

        self.root = root
        self.source = source
    }

    func remove() {
        try? FileManager.default.removeItem(
            at: root
        )
    }
}
