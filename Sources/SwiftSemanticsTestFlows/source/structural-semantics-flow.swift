import Foundation
import SwiftSemantics
import TestFlows

extension SwiftSemanticsFlowSuite {
    static var structuralSemanticsFlow: TestFlow {
        TestFlow(
            "semantic-source-structure",
            tags: [
                "swift-semantics",
                "swift-syntax",
                "symbols",
                "structure",
                "regression",
            ]
        ) {
            Step(
                "collect source symbols with stable structural identity"
            ) {
                let fixture = try SwiftStructuralSemanticsFixture()

                defer {
                    fixture.remove()
                }

                let symbols = try SwiftSemanticSymbolCollector()
                    .collect(
                        in: fixture.source
                    )

                let widget = try Expect.notNil(
                    symbols.first {
                        $0.kind == .struct
                            && $0.name == "Widget"
                    },
                    "Widget structural symbol"
                )

                try Expect.equal(
                    widget.lineRange.start,
                    3,
                    "Widget start line"
                )

                try Expect.equal(
                    widget.lineRange.end,
                    13,
                    "Widget end line"
                )

                let initializer = try Expect.notNil(
                    symbols.first {
                        $0.kind == .initializer
                    },
                    "Widget initializer structural symbol"
                )

                try Expect.equal(
                    initializer.displayName,
                    "init(value:)",
                    "initializer callable display name"
                )

                try Expect.equal(
                    initializer.parentType,
                    Optional(
                        "Widget"
                    ),
                    "initializer parent type"
                )

                let render = try Expect.notNil(
                    symbols.first {
                        $0.kind == .function
                            && $0.name == "render"
                    },
                    "render structural symbol"
                )

                try Expect.equal(
                    render.displayName,
                    "render(label:_:)",
                    "function callable display name"
                )

                try Expect.equal(
                    render.parentType,
                    Optional(
                        "Widget"
                    ),
                    "function parent type"
                )

                let cases = symbols
                    .filter {
                        $0.kind == .enum_case
                    }
                    .map(\.name)
                    .sorted()

                try Expect.equal(
                    cases,
                    [
                        "fast",
                        "slow",
                    ],
                    "enum case symbols"
                )
            }

            Step(
                "select declarations members imports and enclosing scopes"
            ) {
                let fixture = try SwiftStructuralSemanticsFixture()

                defer {
                    fixture.remove()
                }

                let inspector = SwiftSemanticStructureInspector()

                let type = try inspector.selections(
                    in: fixture.source,
                    query: .type(
                        named: "Widget"
                    )
                )

                try Expect.equal(
                    type.count,
                    1,
                    "Widget type selection count"
                )

                try Expect.equal(
                    type.first?.lineRange.start,
                    Optional(
                        3
                    ),
                    "Widget type selection start"
                )

                try Expect.equal(
                    type.first?.lineRange.end,
                    Optional(
                        13
                    ),
                    "Widget type selection end"
                )

                let member = try inspector.selections(
                    in: fixture.source,
                    query: .member(
                        named: "render",
                        parentType: "Widget"
                    )
                )

                try Expect.equal(
                    member.count,
                    1,
                    "render member selection count"
                )

                try Expect.equal(
                    member.first?.lineRange.start,
                    Optional(
                        10
                    ),
                    "render member start"
                )

                try Expect.equal(
                    member.first?.lineRange.end,
                    Optional(
                        12
                    ),
                    "render member end"
                )

                let imports = try inspector.selections(
                    in: fixture.source,
                    query: .imports
                )

                try Expect.equal(
                    imports.count,
                    1,
                    "import selection count"
                )

                try Expect.equal(
                    imports.first?.summary,
                    Optional(
                        "import Foundation"
                    ),
                    "import structural summary"
                )

                let enclosing = try inspector.selections(
                    in: fixture.source,
                    query: .enclosingScope(
                        location: .init(
                            line: 11
                        )
                    )
                )

                try Expect.equal(
                    enclosing.count,
                    1,
                    "enclosing scope selection count"
                )

                try Expect.equal(
                    enclosing.first?.symbolName,
                    Optional(
                        "render"
                    ),
                    "smallest enclosing scope"
                )

                try Expect.equal(
                    enclosing.first?.lineRange.start,
                    Optional(
                        10
                    ),
                    "enclosing scope start"
                )

                try Expect.equal(
                    enclosing.first?.lineRange.end,
                    Optional(
                        12
                    ),
                    "enclosing scope end"
                )
            }
        }
    }
}

private struct SwiftStructuralSemanticsFixture {
    let root: URL
    let source: URL

    init() throws {
        root = FileManager
            .default
            .temporaryDirectory
            .appendingPathComponent(
                "swift-semantics-structure-\(UUID().uuidString)",
                isDirectory: true
            )

        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )

        source = root.appendingPathComponent(
            "Fixture.swift"
        )

        try """
        import Foundation

        public struct Widget {
            public let value: Int

            public init(value: Int) {
                self.value = value
            }

            public func render(label: String, _ count: Int) -> String {
                "\\(label)-\\(count)"
            }
        }

        extension Widget {
            public var doubled: Int {
                value * 2
            }
        }

        enum Mode {
            case fast, slow
        }
        """.write(
            to: source,
            atomically: true,
            encoding: .utf8
        )
    }

    func remove() {
        try? FileManager.default.removeItem(
            at: root
        )
    }
}
