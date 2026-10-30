import Foundation
import SwiftSemantics
import TestFlows

extension SwiftSemanticsFlowSuite {
    static var sourceKitLSPAdvancedSemanticsFlow: TestFlow {
        TestFlow(
            "semantic-sourcekit-lsp-advanced-operations",
            tags: [
                "call-hierarchy",
                "compiler-semantics",
                "document-symbols",
                "hover",
                "sourcekit-lsp",
                "symbol-identity",
                "type-hierarchy",
                "usr",
            ]
        ) {
            Step(
                "query compiler identity hover symbols and hierarchies"
            ) {
                let fixture = try SwiftAdvancedSemanticFixture()
                let workspace = SwiftSemanticWorkspace(
                    root: fixture.root
                )

                do {
                    let firstSession = try await workspace.compilerSessionInfo()

                    let compilerSymbols = try await eventuallyAdvanced(
                        label: "compiler symbol identity"
                    ) {
                        let values = try await workspace.symbolInfo(
                            in: fixture.symbolsFile,
                            at: .init(
                                line: 5,
                                utf16Column: 15
                            )
                        )

                        return values.contains { value in
                            value.name?.contains(
                                "EnglishGreeter"
                            ) == true
                                && !(value.identifier ?? "").isEmpty
                        }
                            ? values
                            : nil
                    }

                    let englishGreeter = try Expect.notNil(
                        compilerSymbols.first { value in
                            value.name?.contains(
                                "EnglishGreeter"
                            ) == true
                        },
                        "compiler-resolved EnglishGreeter symbol"
                    )

                    try Expect.true(
                        !(englishGreeter.identifier ?? "").isEmpty,
                        "compiler symbol exposes a USR"
                    )

                    try Expect.equal(
                        englishGreeter.kind,
                        .struct,
                        "compiler symbol kind"
                    )

                    let hover: SwiftSemanticHover =
                        try await eventuallyAdvanced(
                            label: "compiler hover"
                        ) {
                        guard let value = try await workspace.hover(
                            in: fixture.symbolsFile,
                            at: .init(
                                line: 5,
                                utf16Column: 15
                            )
                        ) else {
                            return nil
                        }

                            return value.contents.isEmpty
                                ? nil
                                : value
                        }

                    try Expect.true(
                        !hover.contents.isEmpty,
                        "hover contains compiler-generated information"
                    )

                    let documentSymbols = try await eventuallyAdvanced(
                        label: "document symbols"
                    ) {
                        let values = try await workspace.documentSymbols(
                            for: fixture.symbolsFile
                        )

                        return containsDocumentSymbol(
                            named: "EnglishGreeter",
                            in: values
                        )
                            && containsDocumentSymbol(
                                named: "caller",
                                in: values
                            )
                            ? values
                            : nil
                    }

                    try Expect.true(
                        containsDocumentSymbol(
                            named: "Greeter",
                            in: documentSymbols
                        ),
                        "document symbols contain Greeter"
                    )

                    try Expect.true(
                        containsDocumentSymbol(
                            named: "Derived",
                            in: documentSymbols
                        ),
                        "document symbols contain Derived"
                    )

                    let incoming = try await eventuallyAdvanced(
                        label: "incoming call hierarchy"
                    ) {
                        let values = try await workspace.incomingCalls(
                            in: fixture.symbolsFile,
                            at: .init(
                                line: 16,
                                utf16Column: 13
                            )
                        )

                        return values.contains { call in
                            call.caller.name.contains(
                                "caller"
                            )
                        }
                            ? values
                            : nil
                    }

                    try Expect.true(
                        incoming.contains { call in
                            call.caller.name.contains(
                                "caller"
                            )
                        },
                        "leaf has caller as an incoming call"
                    )

                    let outgoing = try await eventuallyAdvanced(
                        label: "outgoing call hierarchy"
                    ) {
                        let values = try await workspace.outgoingCalls(
                            in: fixture.symbolsFile,
                            at: .init(
                                line: 20,
                                utf16Column: 13
                            )
                        )

                        return values.contains { call in
                            call.callee.name.contains(
                                "leaf"
                            )
                        }
                            ? values
                            : nil
                    }

                    try Expect.true(
                        outgoing.contains { call in
                            call.callee.name.contains(
                                "leaf"
                            )
                        },
                        "caller has leaf as an outgoing call"
                    )

                    let callGraph: SwiftSemanticCallGraph = try await eventuallyAdvanced(
                        label: "compiler call graph"
                    ) {
                        guard let value = try await workspace.callGraph(
                            in: fixture.symbolsFile,
                            at: .init(line: 20, utf16Column: 13),
                            limits: try .init(
                                maximum_depth: 1,
                                maximum_expanded_symbols: 6
                            )
                        ) else { return nil }
                        return value.graph.edges.contains {
                            $0.destination != value.root
                        } ? value : nil
                    }
                    try Expect.true(
                        callGraph.graph.nodes.contains {
                            $0.value.name.contains("leaf")
                        },
                        "compiler graph contains callee"
                    )
                    try Expect.true(
                        !callGraph.is_complete,
                        "depth-limited graph exposes its unexpanded frontier"
                    )
                    try Expect.true(
                        Array(try callGraph.call_paths().walk()).count >= 2,
                        "compiler graph projects into a call-path tree"
                    )

                    let subtypes = try await eventuallyAdvanced(
                        label: "type hierarchy subtypes"
                    ) {
                        let values = try await workspace.subtypes(
                            in: fixture.symbolsFile,
                            at: .init(
                                line: 13,
                                utf16Column: 14
                            )
                        )

                        return values.contains { value in
                            value.name.contains(
                                "Derived"
                            )
                        }
                            ? values
                            : nil
                    }

                    try Expect.true(
                        subtypes.contains { value in
                            value.name.contains(
                                "Derived"
                            )
                        },
                        "Base resolves Derived as a subtype"
                    )

                    let supertypes = try await eventuallyAdvanced(
                        label: "type hierarchy supertypes"
                    ) {
                        let values = try await workspace.supertypes(
                            in: fixture.symbolsFile,
                            at: .init(
                                line: 14,
                                utf16Column: 20
                            )
                        )

                        return values.contains { value in
                            value.name.contains(
                                "Base"
                            )
                        }
                            ? values
                            : nil
                    }

                    try Expect.true(
                        supertypes.contains { value in
                            value.name.contains(
                                "Base"
                            )
                        },
                        "Derived resolves Base as a supertype"
                    )

                    let secondSession = try await workspace.compilerSessionInfo()

                    try Expect.equal(
                        secondSession.processIdentifier,
                        firstSession.processIdentifier,
                        "advanced operations reuse persistent sourcekit-lsp process"
                    )

                    try await workspace.shutdownCompilerSession()
                } catch {
                    try? await workspace.shutdownCompilerSession()
                    throw error
                }
            }
        }
    }
}

private struct SwiftAdvancedSemanticFixture {
    let root: URL
    let symbolsFile: URL
    let useFile: URL

    init() throws {
        root = try SwiftPersistentFixture.root(named: "advanced")

        symbolsFile = root
            .appendingPathComponent(
                "Sources/Core/Symbols.swift"
            )

        useFile = root
            .appendingPathComponent(
                "Sources/Core/Use.swift"
            )

        try write(
            """
            // swift-tools-version: 6.3

            import PackageDescription

            let package = Package(
                name: "AdvancedSemanticFixture",
                targets: [
                    .target(
                        name: "Core"
                    ),
                ]
            )
            """,
            to: "Package.swift"
        )

        try write(
            """
            public protocol Greeter {
                func greet() -> String
            }

            public struct EnglishGreeter: Greeter {
                public init() {}

                public func greet() -> String {
                    "hello"
                }
            }

            public class Base {}
            public final class Derived: Base {}

            public func leaf() -> String {
                "leaf"
            }

            public func caller() -> String {
                leaf()
            }
            """,
            to: "Sources/Core/Symbols.swift"
        )

        try write(
            """
            public func makeGreeting() -> String {
                let greeter = EnglishGreeter()
                return greeter.greet()
            }
            """,
            to: "Sources/Core/Use.swift"
        )
    }

    func remove() {
        try? FileManager.default.removeItem(
            at: root
        )
    }
}

private extension SwiftAdvancedSemanticFixture {
    func write(
        _ contents: String,
        to path: String
    ) throws {
        let destination = root
            .appendingPathComponent(
                path
            )

        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        guard FileManager.default.fileExists(atPath: destination.path) else {
            throw SwiftPersistentFixtureError.missing(destination)
        }
        guard try String(contentsOf: destination, encoding: .utf8) == contents else {
            throw SwiftPersistentFixtureError.drift(destination)
        }
    }
}

private func containsDocumentSymbol(
    named name: String,
    in symbols: [SwiftSemanticDocumentSymbol]
) -> Bool {
    symbols.contains { symbol in
        symbol.name.contains(
            name
        )
            || containsDocumentSymbol(
                named: name,
                in: symbol.children
            )
    }
}

private func eventuallyAdvanced<Value>(
    label: String,
    attempts: Int = 60,
    operation: () async throws -> Value?
) async throws -> Value {
    var lastError: (any Error)?

    for attempt in 0..<attempts {
        do {
            if let value = try await operation() {
                return value
            }
        } catch {
            lastError = error
        }

        if attempt + 1 < attempts {
            try await Task.sleep(
                for: .milliseconds(
                    500
                )
            )
        }
    }

    if let lastError {
        throw lastError
    }

    throw SwiftSemanticCompilerError.requestTimedOut(
        method: label
    )
}
