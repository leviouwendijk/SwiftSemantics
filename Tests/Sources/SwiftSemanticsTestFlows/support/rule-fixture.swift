import Foundation
import SwiftSemantics
import TestFlows

struct RuleFixture {
    let source: SwiftSemanticSource
    let context: SwiftSemanticRuleContext
    let expectedCount: Int
    let expectedSeverity: SwiftSemanticRuleSeverity?
    let expectedStartLines: [Int]

    init(
        source: String,
        context: SwiftSemanticRuleContext = .init(),
        expectedCount: Int,
        expectedSeverity: SwiftSemanticRuleSeverity? = nil,
        expectedStartLines: [Int] = []
    ) {
        self.source = SwiftSemanticSource(
            source: source
        )
        self.context = context
        self.expectedCount = expectedCount
        self.expectedSeverity = expectedSeverity
        self.expectedStartLines = expectedStartLines
    }

    init(
        source: SwiftSemanticSource,
        context: SwiftSemanticRuleContext = .init(),
        expectedCount: Int,
        expectedSeverity: SwiftSemanticRuleSeverity? = nil,
        expectedStartLines: [Int] = []
    ) {
        self.source = source
        self.context = context
        self.expectedCount = expectedCount
        self.expectedSeverity = expectedSeverity
        self.expectedStartLines = expectedStartLines
    }

    func assert(
        _ rule: any SwiftSemanticRule,
        label: String
    ) async throws {
        let analyzer = SwiftSemanticRuleAnalyzer(
            ruleSet: try .init(
                rules: [
                    rule,
                ]
            )
        )
        let analysis = try await analyzer.analyze(
            source,
            context: context
        )

        try Expect.equal(
            analysis.diagnostics.count,
            expectedCount,
            label + " diagnostic count"
        )

        for diagnostic in analysis.diagnostics {
            try Expect.equal(
                diagnostic.ruleID,
                rule.id,
                label + " rule ID"
            )

            if let expectedSeverity {
                try Expect.equal(
                    diagnostic.severity,
                    expectedSeverity,
                    label + " severity"
                )
            }
        }

        if !expectedStartLines.isEmpty {
            let starts = analysis.diagnostics.compactMap { diagnostic in
                diagnostic.lineRange?.start
            }

            try Expect.equal(
                starts,
                expectedStartLines,
                label + " diagnostic start lines"
            )
        }
    }
}

struct PackageRuleFixture {
    let graph: SwiftSemanticPackageGraph
    let expectedCount: Int
    let expectedSeverity: SwiftSemanticRuleSeverity?

    init(
        graph: SwiftSemanticPackageGraph,
        expectedCount: Int,
        expectedSeverity: SwiftSemanticRuleSeverity? = nil
    ) {
        self.graph = graph
        self.expectedCount = expectedCount
        self.expectedSeverity = expectedSeverity
    }

    func assert(
        _ rule: any SwiftSemanticPackageRule,
        label: String
    ) async throws {
        let analyzer = SwiftSemanticPackageRuleAnalyzer(
            ruleSet: try .init(
                rules: [
                    rule,
                ]
            )
        )
        let analysis = try await analyzer.analyze(
            graph
        )

        try Expect.equal(
            analysis.diagnostics.count,
            expectedCount,
            label + " diagnostic count"
        )

        for diagnostic in analysis.diagnostics {
            try Expect.equal(
                diagnostic.ruleID,
                rule.id,
                label + " rule ID"
            )

            if let expectedSeverity {
                try Expect.equal(
                    diagnostic.severity,
                    expectedSeverity,
                    label + " severity"
                )
            }
        }
    }
}

struct FixtureSymbolResolver:
    SwiftSemanticRuleContext.SymbolResolving
{
    let resolved: [SwiftSemanticCompilerSymbol]

    init(
        _ resolved: [SwiftSemanticCompilerSymbol]
    ) {
        self.resolved = resolved
    }

    func symbols(
        in file: URL,
        at position: SwiftSemanticPosition
    ) async throws -> [SwiftSemanticCompilerSymbol] {
        _ = file
        _ = position
        return resolved
    }
}
