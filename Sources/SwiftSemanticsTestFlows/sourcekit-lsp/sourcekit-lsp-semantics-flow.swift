import Foundation
import SwiftSemantics
import TestFlows

extension SwiftSemanticsFlowSuite {
    static var sourceKitLSPSemanticsFlow: TestFlow {
        TestFlow(
            "semantic-sourcekit-lsp-operations",
            tags: [
                "compiler-semantics",
                "definitions",
                "diagnostics",
                "implementations",
                "references",
                "sourcekit-lsp",
                "workspace-symbols",
            ]
        ) {
            Step(
                "query real compiler semantics from installed sourcekit-lsp"
            ) {
                let fixture = try SwiftCompilerSemanticFixture()
                let workspace = SwiftSemanticWorkspace(
                    root: fixture.root
                )

                do {
                    let firstSession = try await workspace.compilerSessionInfo()

                    let definition = try await eventually(
                        label: "symbol definition"
                    ) {
                        let values = try await workspace.definition(
                            in: fixture.useFile,
                            at: .init(
                                line: 2,
                                utf16Column: 19
                            )
                        )

                        return values.contains { location in
                            location.uri.standardizedFileURL
                                == fixture.protocolFile.standardizedFileURL
                                && location.range.start.line == 5
                        }
                            ? values
                            : nil
                    }

                    try Expect.true(
                        definition.contains { location in
                            location.uri.standardizedFileURL
                                == fixture.protocolFile.standardizedFileURL
                                && location.range.start.line == 5
                        },
                        "EnglishGreeter reference resolves to its declaration"
                    )

                    let implementations = try await eventually(
                        label: "protocol implementations"
                    ) {
                        let values = try await workspace.implementations(
                            in: fixture.protocolFile,
                            at: .init(
                                line: 1,
                                utf16Column: 17
                            )
                        )

                        return values.contains { location in
                            location.uri.standardizedFileURL
                                == fixture.protocolFile.standardizedFileURL
                                && location.range.start.line == 5
                        }
                            ? values
                            : nil
                    }

                    try Expect.true(
                        implementations.contains { location in
                            location.range.start.line == 5
                        },
                        "Greeter protocol resolves EnglishGreeter implementation"
                    )

                    let references = try await eventually(
                        label: "indexed references"
                    ) {
                        let values = try await workspace.references(
                            in: fixture.useFile,
                            at: .init(
                                line: 2,
                                utf16Column: 19
                            ),
                            includeDeclaration: true
                        )

                        return values.count >= 2
                            ? values
                            : nil
                    }

                    try Expect.true(
                        references.contains { location in
                            location.uri.standardizedFileURL
                                == fixture.protocolFile.standardizedFileURL
                        },
                        "references include declaration file"
                    )

                    try Expect.true(
                        references.contains { location in
                            location.uri.standardizedFileURL
                                == fixture.useFile.standardizedFileURL
                        },
                        "references include usage file"
                    )

                    let diagnostics = try await eventually(
                        label: "compiler diagnostics"
                    ) {
                        let values = try await workspace.diagnostics(
                            for: fixture.useFile
                        )

                        return values.contains { diagnostic in
                            diagnostic.message.contains(
                                "Cannot convert value of type 'Int' to specified type 'String'"
                            )
                        }
                            ? values
                            : nil
                    }

                    let mismatch = try Expect.notNil(
                        diagnostics.first { diagnostic in
                            diagnostic.message.contains(
                                "Cannot convert value of type 'Int' to specified type 'String'"
                            )
                        },
                        "Swift compiler type mismatch diagnostic"
                    )

                    try Expect.equal(
                        mismatch.severity,
                        .error,
                        "type mismatch severity"
                    )

                    let symbols = try await eventually(
                        label: "workspace symbols"
                    ) {
                        let values = try await workspace.workspaceSymbols(
                            matching: "EnglishGreeter"
                        )

                        return values.contains { symbol in
                            symbol.name.contains(
                                "EnglishGreeter"
                            )
                        }
                            ? values
                            : nil
                    }

                    let englishGreeter = try Expect.notNil(
                        symbols.first { symbol in
                            symbol.name.contains(
                                "EnglishGreeter"
                            )
                        },
                        "EnglishGreeter workspace symbol"
                    )

                    try Expect.equal(
                        englishGreeter.kind,
                        .struct,
                        "EnglishGreeter workspace symbol kind"
                    )

                    let secondSession = try await workspace.compilerSessionInfo()

                    try Expect.equal(
                        secondSession.processIdentifier,
                        firstSession.processIdentifier,
                        "semantic operations reuse persistent sourcekit-lsp process"
                    )

                    try await workspace.shutdownCompilerSession()
                    fixture.remove()
                } catch {
                    try? await workspace.shutdownCompilerSession()
                    fixture.remove()
                    throw error
                }
            }
        }
    }
}

private struct SwiftCompilerSemanticFixture {
    let root: URL
    let protocolFile: URL
    let useFile: URL

    init() throws {
        root = FileManager
            .default
            .temporaryDirectory
            .appendingPathComponent(
                "swift-semantics-sourcekit-\(UUID().uuidString)",
                isDirectory: true
            )

        protocolFile = root
            .appendingPathComponent(
                "Sources/Core/Protocol.swift"
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
                name: "CompilerSemanticFixture",
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
            """,
            to: "Sources/Core/Protocol.swift"
        )

        try write(
            """
            public func makeGreeting() -> String {
                let greeter = EnglishGreeter()
                return greeter.greet()
            }

            public let broken: String = 1
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

private extension SwiftCompilerSemanticFixture {
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

        try contents.write(
            to: destination,
            atomically: true,
            encoding: .utf8
        )
    }
}

private func eventually<Value>(
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
