import Foundation
import SwiftSemantics
import TestFlows

extension SwiftSemanticsFlowSuite {
    static var importInventoryFlow: TestFlow {
        TestFlow(
            "semantic-import-inventory",
            tags: [
                "swift-semantics",
                "swiftpm",
                "swift-syntax",
                "imports",
                "sources",
            ]
        ) {
            Step(
                "derive target imports from SwiftPM-owned source membership"
            ) {
                let fixture = try SwiftSemanticPackageFixture()

                defer {
                    fixture.remove()
                }

                let workspace = SwiftSemanticWorkspace(
                    root: fixture.root
                )

                let sources = try await workspace.sourceInventory()

                try Expect.equal(
                    sources.packageName,
                    "SemanticFixture",
                    "semantic source inventory package"
                )

                try Expect.equal(
                    sources.targets
                        .map(\.name)
                        .sorted(),
                    [
                        "Helper",
                        "SemanticCore",
                    ],
                    "semantic source inventory targets"
                )

                let sourceCore = try Expect.notNil(
                    sources.target(
                        named: "SemanticCore"
                    ),
                    "SemanticCore source target"
                )

                try Expect.equal(
                    sourceCore.sourceFiles,
                    [
                        fixture.root
                            .appendingPathComponent(
                                "Sources/SemanticCore/SemanticCore.swift"
                            )
                            .standardizedFileURL,
                    ],
                    "SwiftPM-owned SemanticCore source membership"
                )

                let imports = try await workspace.importInventory()

                let core = try Expect.notNil(
                    imports.target(
                        named: "SemanticCore"
                    ),
                    "SemanticCore import target"
                )

                try Expect.equal(
                    core.files.count,
                    1,
                    "SemanticCore parsed file count"
                )

                let file = try Expect.notNil(
                    core.files.first,
                    "SemanticCore parsed source file"
                )

                try Expect.equal(
                    file.imports.map(\.path),
                    [
                        [
                            "Helper",
                        ],
                        [
                            "Leaf",
                        ],
                        [
                            "Foundation",
                            "Date",
                        ],
                    ],
                    "SwiftSyntax import paths"
                )

                try Expect.equal(
                    core.moduleNames,
                    [
                        "Foundation",
                        "Helper",
                        "Leaf",
                    ],
                    "target import modules"
                )

                let helper = try Expect.notNil(
                    imports.target(
                        named: "Helper"
                    ),
                    "Helper import target"
                )

                try Expect.isEmpty(
                    helper.imports,
                    "Helper has no imports"
                )
            }
        }
    }
}
