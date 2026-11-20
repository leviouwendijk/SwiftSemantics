import Foundation
import SwiftSemantics
import TestFlows

extension SwiftSemanticsFlowSuite {
    static var designConventionRulesFlow: TestFlow {
        TestFlow(
            "semantic-design-convention-rules",
            tags: [
                "api",
                "architecture",
                "lint",
                "rules",
                "swift-semantics",
            ]
        ) {
            Step(
                "symbol component threshold defaults to greater than three"
            ) {
                let analysis = try await analyzeDesignRule(
                    SwiftSemanticRules.API.Topology.ExcessiveSymbolComponents(),
                    source: "struct HTTPServerRequestDecoder {}"
                )

                try Expect.equal(
                    analysis.diagnostics.count,
                    1,
                    "four-component symbol fires"
                )

                let clean = try await analyzeDesignRule(
                    SwiftSemanticRules.API.Topology.ExcessiveSymbolComponents(),
                    source: "struct HTTPRequestDecoder {}"
                )

                try Expect.equal(
                    clean.diagnostics.count,
                    0,
                    "three-component symbol remains allowed"
                )
            }

            Step(
                "symbol component threshold is configurable"
            ) {
                let analysis = try await analyzeDesignRule(
                    SwiftSemanticRules.API.Topology.ExcessiveSymbolComponents(),
                    source: "struct HTTPServerRequestDecoder {}",
                    context: .init(
                        configuration: .init(
                            maximumSymbolComponents: 4
                        )
                    )
                )

                try Expect.equal(
                    analysis.diagnostics.count,
                    0,
                    "configured four-component allowance"
                )
            }

            Step(
                "nominal nesting defaults to greater than four"
            ) {
                let analysis = try await analyzeDesignRule(
                    SwiftSemanticRules.API.Topology.ExcessiveTypeNesting(),
                    source: "enum One { enum Two { enum Three { enum Four { enum Five {} } } } }"
                )

                try Expect.equal(
                    analysis.diagnostics.count,
                    1,
                    "fifth lineage level fires"
                )
            }

            Step(
                "redundant nested prefix is detected"
            ) {
                let analysis = try await analyzeDesignRule(
                    SwiftSemanticRules.API.Topology.RedundantNestedTypePrefix(),
                    source: "enum Request { struct RequestOptions {} }"
                )

                try Expect.equal(
                    analysis.diagnostics.count,
                    1,
                    "nested type repeats owner name"
                )
            }

            Step(
                "shared top-level prefix families are hints"
            ) {
                let analysis = try await analyzeDesignRule(
                    SwiftSemanticRules.API.Topology.SharedSymbolPrefixFamily(),
                    source: "struct HTTPClientRequest {}\nstruct HTTPClientResponse {}\nstruct HTTPClientState {}"
                )

                try Expect.equal(
                    analysis.diagnostics.count,
                    1,
                    "shared prefix family diagnostic"
                )
                try Expect.equal(
                    analysis.diagnostics.first?.severity,
                    .hint,
                    "shared prefix family severity"
                )
            }

            Step(
                "public semantic surface rules detect tuples Any and parameter clusters"
            ) {
                let tuple = try await analyzeDesignRule(
                    SwiftSemanticRules.API.Surface.PublicTupleReturn(),
                    source: "public func result() -> (Int, Int) { (1, 2) }"
                )
                let any = try await analyzeDesignRule(
                    SwiftSemanticRules.API.Surface.PublicAnyType(),
                    source: "public func consume(_ value: Any) {}"
                )
                let primitives = try await analyzeDesignRule(
                    SwiftSemanticRules.API.Surface.PrimitiveParameterCluster(),
                    source: "public func make(a: String, b: String, c: String) {}"
                )
                let booleans = try await analyzeDesignRule(
                    SwiftSemanticRules.API.Surface.BooleanParameterCluster(),
                    source: "public func make(enabled: Bool, cached: Bool) {}"
                )
                let count = try await analyzeDesignRule(
                    SwiftSemanticRules.API.Surface.ExcessiveParameterCount(),
                    source: "public func make(a: Int, b: Int, c: Int, d: Int, e: Int, f: Int, g: Int) {}"
                )

                try Expect.equal(tuple.diagnostics.count, 1, "tuple surface")
                try Expect.equal(any.diagnostics.count, 1, "Any surface")
                try Expect.equal(primitives.diagnostics.count, 1, "primitive cluster")
                try Expect.equal(booleans.diagnostics.count, 1, "Boolean cluster")
                try Expect.equal(count.diagnostics.count, 1, "parameter count")
            }

            Step(
                "filename convention uses primary declaration"
            ) {
                let file = URL(
                    fileURLWithPath: "/tmp/wrong-name.swift"
                )
                let source = try SwiftSemanticSource(
                    file: file,
                    source: "public struct HTTPClient {}"
                )
                let analyzer = SwiftSemanticRuleAnalyzer(
                    ruleSet: try .init(
                        rules: [
                            SwiftSemanticRules.Source.PrimaryDeclarationFilename(),
                        ]
                    )
                )
                let analysis = try await analyzer.analyze(
                    source
                )

                try Expect.equal(
                    analysis.diagnostics.count,
                    1,
                    "primary filename mismatch"
                )
            }

            Step(
                "unrelated public declarations produce one hint"
            ) {
                let analysis = try await analyzeDesignRule(
                    SwiftSemanticRules.Source.UnrelatedPublicDeclarations(),
                    source: "public struct Request {}\npublic struct Parser {}\npublic struct Storage {}"
                )

                try Expect.equal(
                    analysis.diagnostics.count,
                    1,
                    "unrelated public declarations"
                )
            }

            Step(
                "String Codable enum cases prefer snake case directly"
            ) {
                let analysis = try await analyzeDesignRule(
                    SwiftSemanticRules.Enums.CodableStringCaseCasing(),
                    source: "public enum Mode: String, Codable { case sourceKitLSP }"
                )

                try Expect.equal(
                    analysis.diagnostics.count,
                    1,
                    "camel case Codable string case"
                )
            }

            Step(
                "print is only a library-source convention"
            ) {
                let library = try await analyzeDesignRule(
                    SwiftSemanticRules.Source.LibraryPrint(),
                    source: "func render() { print(\"x\") }",
                    context: .init(
                        sourceRole: .library
                    )
                )
                let executable = try await analyzeDesignRule(
                    SwiftSemanticRules.Source.LibraryPrint(),
                    source: "func render() { print(\"x\") }",
                    context: .init(
                        sourceRole: .executable
                    )
                )

                try Expect.equal(library.diagnostics.count, 1, "library print")
                try Expect.equal(executable.diagnostics.count, 0, "executable print")
            }

            Step(
                "compiler resolved forbidden APIs use identity not spelling"
            ) {
                let file = URL(
                    fileURLWithPath: "/tmp/forbidden-api.swift"
                )
                let source = try SwiftSemanticSource(
                    file: file,
                    source: "func run() { Process() }"
                )
                let context = SwiftSemanticRuleContext(
                    forbiddenAPIs: [
                        .init(
                            identity: .system(
                                module: "Foundation",
                                name: "Process"
                            ),
                            reason: "Use Processes instead."
                        ),
                    ],
                    symbolResolver: RuleFixtureSymbolResolver(
                        symbols: [
                            .init(
                                name: "Process",
                                systemModuleName: "Foundation"
                            ),
                        ]
                    )
                )
                let analysis = try await analyzeDesignRule(
                    SwiftSemanticRules.API.Surface.ForbiddenSemanticAPIUsage(),
                    source: source,
                    context: context
                )

                try Expect.equal(
                    analysis.diagnostics.count,
                    1,
                    "compiler identity policy"
                )
            }

            Step(
                "public dependency type leakage can be blocked by compiler identity"
            ) {
                let file = URL(
                    fileURLWithPath: "/tmp/dependency-leak.swift"
                )
                let source = try SwiftSemanticSource(
                    file: file,
                    source: "public func expose() -> DependencyType { fatalError() }"
                )
                let context = SwiftSemanticRuleContext(
                    dependencySurface: .init(
                        forbiddenSymbolIdentifiers: [
                            "fixture:DependencyType",
                        ]
                    ),
                    symbolResolver: RuleFixtureSymbolResolver(
                        symbols: [
                            .init(
                                name: "DependencyType",
                                identifier: "fixture:DependencyType"
                            ),
                        ]
                    )
                )
                let analysis = try await analyzeDesignRule(
                    SwiftSemanticRules.API.Surface.PublicDependencyTypeLeak(),
                    source: source,
                    context: context
                )

                try Expect.equal(
                    analysis.diagnostics.count,
                    1,
                    "public dependency type leak"
                )
            }
        }
    }
}

private func analyzeDesignRule(
    _ rule: any SwiftSemanticRule,
    source: String,
    context: SwiftSemanticRuleContext = .init()
) async throws -> SwiftSemanticRuleAnalysis {
    try await analyzeDesignRule(
        rule,
        source: SwiftSemanticSource(
            source: source
        ),
        context: context
    )
}

private func analyzeDesignRule(
    _ rule: any SwiftSemanticRule,
    source: SwiftSemanticSource,
    context: SwiftSemanticRuleContext = .init()
) async throws -> SwiftSemanticRuleAnalysis {
    let analyzer = SwiftSemanticRuleAnalyzer(
        ruleSet: try .init(
            rules: [
                rule,
            ]
        )
    )

    return try await analyzer.analyze(
        source,
        context: context
    )
}

private struct RuleFixtureSymbolResolver:
    SwiftSemanticRuleContext.SymbolResolving
{
    let symbols: [SwiftSemanticCompilerSymbol]

    func symbols(
        in file: URL,
        at position: SwiftSemanticPosition
    ) async throws -> [SwiftSemanticCompilerSymbol] {
        _ = file
        _ = position
        return symbols
    }
}
