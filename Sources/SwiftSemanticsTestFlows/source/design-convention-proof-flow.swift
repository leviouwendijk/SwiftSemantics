import Foundation
import SwiftSemantics
import TestFlows

extension SwiftSemanticsFlowSuite {
    static var designConventionProofFlow: TestFlow {
        TestFlow(
            "semantic-design-convention-proof-matrix",
            tags: [
                "api",
                "architecture",
                "boundaries",
                "fixtures",
                "lint",
                "regression",
                "rules",
                "swift-semantics",
            ]
        ) {
            Step(
                "prove symbol component boundaries and acronym tokenization"
            ) {
                let rule = SwiftSemanticRules.API.Topology.ExcessiveSymbolComponents()

                try await RuleFixture(
                    source: "struct HTTPRequestDecoder {}",
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "three components remain allowed"
                )

                try await RuleFixture(
                    source: "struct URLRequestParser {}",
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "acronym remains one lexical component"
                )

                try await RuleFixture(
                    source: """
                    struct Fine {}
                    struct HTTPServerRequestDecoder {}
                    """,
                    expectedCount: 1,
                    expectedSeverity: .warning,
                    expectedStartLines: [
                        2,
                    ]
                ).assert(
                    rule,
                    label: "four components exceed default maximum"
                )

                try await RuleFixture(
                    source: "struct HTTPServerRequestDecoder {}",
                    context: .init(
                        configuration: .init(
                            maximumSymbolComponents: 4
                        )
                    ),
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "custom maximum permits four components"
                )

                try await RuleFixture(
                    source: "struct AgentToolExecutionRecoveryPolicy {}",
                    context: .init(
                        configuration: .init(
                            maximumSymbolComponents: 4
                        )
                    ),
                    expectedCount: 1,
                    expectedSeverity: .warning
                ).assert(
                    rule,
                    label: "custom maximum still rejects five components"
                )
            }

            Step(
                "prove nesting lineage boundaries"
            ) {
                let rule = SwiftSemanticRules.API.Topology.ExcessiveTypeNesting()

                try await RuleFixture(
                    source: "enum A { enum B { enum C { enum D {} } } }",
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "four lineage levels remain allowed"
                )

                try await RuleFixture(
                    source: "enum A { enum B { enum C { enum D { enum E {} } } } }",
                    expectedCount: 1,
                    expectedSeverity: .warning
                ).assert(
                    rule,
                    label: "fifth lineage level exceeds default"
                )

                try await RuleFixture(
                    source: "enum A { enum B { enum C { enum D { enum E {} } } } }",
                    context: .init(
                        configuration: .init(
                            maximumNestingLineage: 5
                        )
                    ),
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "custom lineage maximum permits five levels"
                )

                try await RuleFixture(
                    source: "enum A { enum B { enum C { enum D { enum E { enum F {} } } } } }",
                    context: .init(
                        configuration: .init(
                            maximumNestingLineage: 5
                        )
                    ),
                    expectedCount: 1,
                    expectedSeverity: .warning
                ).assert(
                    rule,
                    label: "sixth level exceeds configured maximum"
                )
            }

            Step(
                "prove redundant nested prefix boundary"
            ) {
                let rule = SwiftSemanticRules.API.Topology.RedundantNestedTypePrefix()

                try await RuleFixture(
                    source: "enum Request { struct RequestOptions {} }",
                    expectedCount: 1,
                    expectedSeverity: .warning
                ).assert(
                    rule,
                    label: "child repeats parent lexical prefix"
                )

                try await RuleFixture(
                    source: "enum Request { struct Options {} }",
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "short nested semantic name remains clean"
                )

                try await RuleFixture(
                    source: "enum Request { struct RequestedOptions {} }",
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "partial spelling overlap is not a lexical prefix"
                )
            }

            Step(
                "prove shared top-level prefix family boundaries"
            ) {
                let rule = SwiftSemanticRules.API.Topology.SharedSymbolPrefixFamily()

                try await RuleFixture(
                    source: """
                    struct HTTPClientRequest {}
                    struct HTTPClientResponse {}
                    """,
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "two related top-level types remain below default family threshold"
                )

                try await RuleFixture(
                    source: """
                    struct HTTPClientRequest {}
                    struct HTTPClientResponse {}
                    struct HTTPClientState {}
                    """,
                    expectedCount: 1,
                    expectedSeverity: .hint
                ).assert(
                    rule,
                    label: "three repeated two-component prefixes form a family"
                )

                try await RuleFixture(
                    source: """
                    struct HTTPClientRequest {}
                    struct HTTPServerResponse {}
                    struct HTTPProxyState {}
                    """,
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "shared first component alone does not form a family"
                )

                try await RuleFixture(
                    source: """
                    enum HTTPClient {
                        struct HTTPClientRequest {}
                        struct HTTPClientResponse {}
                        struct HTTPClientState {}
                    }
                    """,
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "nested declarations are excluded from top-level family pressure"
                )
            }

            Step(
                "prove tuple and Any public surface boundaries"
            ) {
                try await RuleFixture(
                    source: "public func result() -> (Int, Int) { (1, 2) }",
                    expectedCount: 1,
                    expectedSeverity: .warning
                ).assert(
                    SwiftSemanticRules.API.Surface.PublicTupleReturn(),
                    label: "public tuple return"
                )

                try await RuleFixture(
                    source: "func result() -> (Int, Int) { (1, 2) }",
                    expectedCount: 0
                ).assert(
                    SwiftSemanticRules.API.Surface.PublicTupleReturn(),
                    label: "internal tuple return"
                )

                try await RuleFixture(
                    source: "public let pair: (Int, Int) = (1, 2)",
                    expectedCount: 1,
                    expectedSeverity: .warning
                ).assert(
                    SwiftSemanticRules.API.Surface.PublicTupleReturn(),
                    label: "public tuple property"
                )

                try await RuleFixture(
                    source: "public func consume(_ value: [String: Any]) {}",
                    expectedCount: 1,
                    expectedSeverity: .warning
                ).assert(
                    SwiftSemanticRules.API.Surface.PublicAnyType(),
                    label: "nested Any in dictionary"
                )

                try await RuleFixture(
                    source: "public func result() -> Result<Any, Error> { fatalError() }",
                    expectedCount: 1,
                    expectedSeverity: .warning
                ).assert(
                    SwiftSemanticRules.API.Surface.PublicAnyType(),
                    label: "nested Any in generic return"
                )

                try await RuleFixture(
                    source: "func consume(_ value: Any) {}",
                    expectedCount: 0
                ).assert(
                    SwiftSemanticRules.API.Surface.PublicAnyType(),
                    label: "internal Any remains outside public surface rule"
                )

                try await RuleFixture(
                    source: "public func consume(_ value: String) {}",
                    expectedCount: 0
                ).assert(
                    SwiftSemanticRules.API.Surface.PublicAnyType(),
                    label: "typed public API remains clean"
                )
            }

            Step(
                "prove parameter cluster and count boundaries"
            ) {
                try await RuleFixture(
                    source: "public func make(a: String, b: String, c: String) {}",
                    expectedCount: 1,
                    expectedSeverity: .warning
                ).assert(
                    SwiftSemanticRules.API.Surface.PrimitiveParameterCluster(),
                    label: "three identical primitive parameters reach threshold"
                )

                try await RuleFixture(
                    source: "public func make(a: String, b: String, c: Int) {}",
                    expectedCount: 0
                ).assert(
                    SwiftSemanticRules.API.Surface.PrimitiveParameterCluster(),
                    label: "mixed primitive types do not form one cluster"
                )

                try await RuleFixture(
                    source: "public func make(a: String, b: String, c: String) {}",
                    context: .init(
                        configuration: .init(
                            primitiveParameterClusterSize: 4
                        )
                    ),
                    expectedCount: 0
                ).assert(
                    SwiftSemanticRules.API.Surface.PrimitiveParameterCluster(),
                    label: "primitive cluster threshold is configurable"
                )

                try await RuleFixture(
                    source: "public func make(enabled: Bool) {}",
                    expectedCount: 0
                ).assert(
                    SwiftSemanticRules.API.Surface.BooleanParameterCluster(),
                    label: "one Boolean remains clean"
                )

                try await RuleFixture(
                    source: "public func make(enabled: Bool, cached: Bool) {}",
                    expectedCount: 1,
                    expectedSeverity: .warning
                ).assert(
                    SwiftSemanticRules.API.Surface.BooleanParameterCluster(),
                    label: "two Booleans reach default threshold"
                )

                try await RuleFixture(
                    source: "public func make(enabled: Bool, cached: Bool) {}",
                    context: .init(
                        configuration: .init(
                            booleanParameterClusterSize: 3
                        )
                    ),
                    expectedCount: 0
                ).assert(
                    SwiftSemanticRules.API.Surface.BooleanParameterCluster(),
                    label: "Boolean threshold is configurable"
                )

                try await RuleFixture(
                    source: "public func make(a: Int, b: Int, c: Int, d: Int, e: Int, f: Int) {}",
                    expectedCount: 0
                ).assert(
                    SwiftSemanticRules.API.Surface.ExcessiveParameterCount(),
                    label: "six parameters remain at default maximum"
                )

                try await RuleFixture(
                    source: "public func make(a: Int, b: Int, c: Int, d: Int, e: Int, f: Int, g: Int) {}",
                    expectedCount: 1,
                    expectedSeverity: .hint
                ).assert(
                    SwiftSemanticRules.API.Surface.ExcessiveParameterCount(),
                    label: "seven parameters exceed default maximum"
                )

                try await RuleFixture(
                    source: "public func make(a: Int, b: Int, c: Int, d: Int, e: Int, f: Int, g: Int) {}",
                    context: .init(
                        configuration: .init(
                            maximumParameterCount: 7
                        )
                    ),
                    expectedCount: 0
                ).assert(
                    SwiftSemanticRules.API.Surface.ExcessiveParameterCount(),
                    label: "parameter maximum is configurable"
                )
            }

            Step(
                "prove primary declaration filename boundaries"
            ) {
                let rule = SwiftSemanticRules.Source.PrimaryDeclarationFilename()

                try await RuleFixture(
                    source: try SwiftSemanticSource(
                        file: URL(fileURLWithPath: "/tmp/http-client.swift"),
                        source: "public struct HTTPClient {}"
                    ),
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "matching kebab filename"
                )

                try await RuleFixture(
                    source: try SwiftSemanticSource(
                        file: URL(fileURLWithPath: "/tmp/http-client+conformance.swift"),
                        source: "public struct HTTPClient {}"
                    ),
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "intentional companion suffix"
                )

                try await RuleFixture(
                    source: try SwiftSemanticSource(
                        file: URL(fileURLWithPath: "/tmp/client.swift"),
                        source: "public struct HTTPClient {}"
                    ),
                    expectedCount: 1,
                    expectedSeverity: .warning
                ).assert(
                    rule,
                    label: "mismatching filename"
                )

                try await RuleFixture(
                    source: try SwiftSemanticSource(
                        file: URL(fileURLWithPath: "/tmp/mixed.swift"),
                        source: "public struct Request {}\npublic struct Response {}"
                    ),
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "multiple primary declarations do not guess a filename owner"
                )

                try await RuleFixture(
                    source: "public struct HTTPClient {}",
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "in-memory source has no filename policy"
                )
            }

            Step(
                "prove unrelated declaration boundaries"
            ) {
                let rule = SwiftSemanticRules.Source.UnrelatedPublicDeclarations()

                try await RuleFixture(
                    source: "public struct Request {}\npublic struct Parser {}",
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "two unrelated declarations remain below threshold"
                )

                try await RuleFixture(
                    source: "public struct Request {}\npublic struct Parser {}\npublic struct Storage {}",
                    expectedCount: 1,
                    expectedSeverity: .hint
                ).assert(
                    rule,
                    label: "three unrelated public roots reach threshold"
                )

                try await RuleFixture(
                    source: "public struct RequestInput {}\npublic struct RequestOutput {}\npublic struct RequestState {}",
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "related lexical roots remain clean"
                )

                try await RuleFixture(
                    source: "public struct Request {}\npublic struct Parser {}\npublic struct Storage {}",
                    context: .init(
                        configuration: .init(
                            unrelatedPublicDeclarationCount: 4
                        )
                    ),
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "unrelated declaration threshold is configurable"
                )
            }

            Step(
                "prove Codable String enum casing boundaries"
            ) {
                let rule = SwiftSemanticRules.Enums.CodableStringCaseCasing()

                try await RuleFixture(
                    source: "enum Mode: String, Codable { case source_kit_lsp }",
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "snake case Codable String enum"
                )

                try await RuleFixture(
                    source: "enum Mode: String, Codable { case sourceKitLSP }",
                    expectedCount: 1,
                    expectedSeverity: .warning
                ).assert(
                    rule,
                    label: "camel case Codable String enum"
                )

                try await RuleFixture(
                    source: "enum Mode: String { case sourceKitLSP }",
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "non-Codable String enum remains outside rule"
                )

                try await RuleFixture(
                    source: "enum Mode: Int, Codable { case sourceKitLSP = 1 }",
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "non-String Codable enum remains outside rule"
                )

                try await RuleFixture(
                    source: "enum Mode: String, Encodable, Decodable { case sourceKitLSP }",
                    expectedCount: 1,
                    expectedSeverity: .warning
                ).assert(
                    rule,
                    label: "explicit Encodable plus Decodable is Codable-equivalent"
                )
            }

            Step(
                "prove library print source-role boundary"
            ) {
                let rule = SwiftSemanticRules.Source.LibraryPrint()
                let source = "func render() { print(\"value\") }"

                try await RuleFixture(
                    source: source,
                    context: .init(
                        sourceRole: .library
                    ),
                    expectedCount: 1,
                    expectedSeverity: .warning
                ).assert(
                    rule,
                    label: "library print"
                )

                try await RuleFixture(
                    source: source,
                    context: .init(
                        sourceRole: .executable
                    ),
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "executable print"
                )

                try await RuleFixture(
                    source: source,
                    context: .init(
                        sourceRole: .test
                    ),
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "test print"
                )

                try await RuleFixture(
                    source: source,
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "unspecified source role"
                )
            }

            Step(
                "prove forbidden semantic API compiler identity boundaries"
            ) {
                let file = URL(
                    fileURLWithPath: "/tmp/forbidden-api-proof.swift"
                )
                let source = try SwiftSemanticSource(
                    file: file,
                    source: "func run() { Process() }"
                )
                let rule = SwiftSemanticRules.API.Surface.ForbiddenSemanticAPIUsage()
                let policy: [SwiftSemanticRuleContext.ForbiddenAPI] = [
                    .init(
                        identity: .system(
                            module: "Foundation",
                            name: "Process"
                        ),
                        reason: "Use Processes instead."
                    ),
                ]

                try await RuleFixture(
                    source: source,
                    context: .init(
                        forbiddenAPIs: policy,
                        symbolResolver: FixtureSymbolResolver(
                            [
                                .init(
                                    name: "Process",
                                    isSystem: true,
                                    systemModuleName: "Foundation"
                                ),
                            ]
                        )
                    ),
                    expectedCount: 1,
                    expectedSeverity: .warning
                ).assert(
                    rule,
                    label: "exact system identity is forbidden"
                )

                try await RuleFixture(
                    source: source,
                    context: .init(
                        forbiddenAPIs: policy,
                        symbolResolver: FixtureSymbolResolver(
                            [
                                .init(
                                    name: "Process",
                                    identifier: "local:Process",
                                    isSystem: false
                                ),
                            ]
                        )
                    ),
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "same spelling with different compiler identity remains clean"
                )

                try await RuleFixture(
                    source: source,
                    context: .init(
                        symbolResolver: FixtureSymbolResolver(
                            [
                                .init(
                                    name: "Process",
                                    isSystem: true,
                                    systemModuleName: "Foundation"
                                ),
                            ]
                        )
                    ),
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "empty forbidden policy remains dormant"
                )
            }

            Step(
                "prove public dependency surface compiler identity boundaries"
            ) {
                let file = URL(
                    fileURLWithPath: "/tmp/dependency-surface-proof.swift"
                )
                let publicSource = try SwiftSemanticSource(
                    file: file,
                    source: "public func expose() -> DependencyType { fatalError() }"
                )
                let internalSource = try SwiftSemanticSource(
                    file: file,
                    source: "func expose() -> DependencyType { fatalError() }"
                )
                let rule = SwiftSemanticRules.API.Surface.PublicDependencyTypeLeak()

                try await RuleFixture(
                    source: publicSource,
                    context: .init(
                        dependencySurface: .init(
                            forbiddenSymbolIdentifiers: [
                                "fixture:DependencyType",
                            ]
                        ),
                        symbolResolver: FixtureSymbolResolver(
                            [
                                .init(
                                    name: "DependencyType",
                                    identifier: "fixture:DependencyType"
                                ),
                            ]
                        )
                    ),
                    expectedCount: 1,
                    expectedSeverity: .warning
                ).assert(
                    rule,
                    label: "forbidden dependency USR leaks through public surface"
                )

                try await RuleFixture(
                    source: publicSource,
                    context: .init(
                        dependencySurface: .init(
                            forbiddenSymbolIdentifiers: [
                                "fixture:OtherType",
                            ]
                        ),
                        symbolResolver: FixtureSymbolResolver(
                            [
                                .init(
                                    name: "DependencyType",
                                    identifier: "fixture:DependencyType"
                                ),
                            ]
                        )
                    ),
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "unrelated dependency identity remains clean"
                )

                try await RuleFixture(
                    source: internalSource,
                    context: .init(
                        dependencySurface: .init(
                            forbiddenSymbolIdentifiers: [
                                "fixture:DependencyType",
                            ]
                        ),
                        symbolResolver: FixtureSymbolResolver(
                            [
                                .init(
                                    name: "DependencyType",
                                    identifier: "fixture:DependencyType"
                                ),
                            ]
                        )
                    ),
                    expectedCount: 0
                ).assert(
                    rule,
                    label: "internal dependency type is outside public surface rule"
                )

                try await RuleFixture(
                    source: publicSource,
                    context: .init(
                        dependencySurface: .init(
                            forbiddenSystemModules: [
                                "Foundation",
                            ]
                        ),
                        symbolResolver: FixtureSymbolResolver(
                            [
                                .init(
                                    name: "DependencyType",
                                    systemModuleName: "Foundation"
                                ),
                            ]
                        )
                    ),
                    expectedCount: 1,
                    expectedSeverity: .warning
                ).assert(
                    rule,
                    label: "forbidden system module leaks through public surface"
                )
            }
        }
    }
}
