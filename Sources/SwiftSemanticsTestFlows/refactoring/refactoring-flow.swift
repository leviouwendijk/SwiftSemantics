import Foundation
import SwiftRefactoring
import SwiftSemantics
import TestFlows

extension SwiftSemanticsFlowSuite {
    static var refactoringFlow: TestFlow {
        TestFlow(
            "swift-refactoring-source-preservation",
            tags: ["swift-refactoring", "regression"]
        ) {
            Step("move a function without rewriting its body or doc comment") {
                let fromFile = URL(fileURLWithPath: "/tmp/refactoring-origin.swift")
                let toFile = URL(fileURLWithPath: "/tmp/refactoring-destination.swift")
                let original = """
                extension Example {
                    /// Preserve this documentation.
                    func compute() -> Int {
                        return 42
                    }
                }
                """
                let destination = """
                extension Example {
                    func existing() {}
                }
                """
                let from = try SwiftSemanticSource(file: fromFile, source: original)
                let to = try SwiftSemanticSource(file: toFile, source: destination)
                let plan = try SwiftRefactoringPlanner().moveFunction(
                    named: "compute",
                    inExtensionOf: "Example",
                    from: from,
                    to: to
                )
                let result = try plan.preview(sources: [
                    fromFile: original,
                    toFile: destination,
                ])

                try Expect.equal(plan.edits.count, 2, "one removal and one insertion")
                try Expect.true(plan.declaration.text.contains("return 42"), "original body captured")
                try Expect.true(plan.declaration.text.contains("/// Preserve"), "leading docs captured")
                try Expect.equal(result[fromFile]?.contains("func compute"), false, "origin removed")
                try Expect.true(result[toFile]?.contains(plan.declaration.text) == true, "unchanged declaration inserted")
                try Expect.equal(
                    SwiftSemanticSource(source: result[toFile] ?? "").syntax.hasError,
                    false,
                    "destination still parses"
                )
            }

            Step("move between two extensions of the same file") {
                let file = URL(fileURLWithPath: "/tmp/refactoring-one-file.swift")
                let text = """
                extension Sample {
                    func move() -> Int { 21 }
                }
                extension Sample {
                    func keep() {}
                }
                """
                let source = try SwiftSemanticSource(file: file, source: text)
                let plan = try SwiftRefactoringPlanner().moveFunction(
                    named: "move",
                    inExtensionOf: "Sample",
                    from: source,
                    to: source,
                    destinationExtensionIndex: 1
                )
                let updated = try plan.preview(sources: [file: text])
                try Expect.equal(updated.count, 1, "same file receives both edits")
                try Expect.true(updated[file]?.contains("func move() -> Int { 21 }") == true, "body survives")
                try Expect.equal(
                    SwiftSemanticSource(source: updated[file] ?? "").syntax.hasError,
                    false,
                    "same-file move parses"
                )
            }

            Step("reject a stale snapshot instead of silently applying offsets") {
                let fromFile = URL(fileURLWithPath: "/tmp/refactoring-stale-source.swift")
                let toFile = URL(fileURLWithPath: "/tmp/refactoring-stale-target.swift")
                let original = "extension Sample {\n    func move() {}\n}\n"
                let destination = "extension Sample {\n}\n"
                let plan = try SwiftRefactoringPlanner().moveFunction(
                    named: "move",
                    inExtensionOf: "Sample",
                    from: try SwiftSemanticSource(file: fromFile, source: original),
                    to: try SwiftSemanticSource(file: toFile, source: destination)
                )
                var rejected = false
                do {
                    _ = try plan.preview(sources: [
                        fromFile: "// altered\n" + original,
                        toFile: destination,
                    ])
                } catch SwiftRefactoringError.staleSource {
                    rejected = true
                }
                try Expect.true(rejected, "baseline drift is rejected")
            }

            Step("reject where-constrained extensions") {
                let fromFile = URL(fileURLWithPath: "/tmp/refactoring-constrained-origin.swift")
                let toFile = URL(fileURLWithPath: "/tmp/refactoring-constrained-destination.swift")
                let original = "extension Container where Element: Equatable {\n    func move() {}\n}\n"
                let destination = "extension Container {\n}\n"
                var rejected = false

                do {
                    _ = try SwiftRefactoringPlanner().moveFunction(
                        named: "move",
                        inExtensionOf: "Container",
                        from: try SwiftSemanticSource(file: fromFile, source: original),
                        to: try SwiftSemanticSource(file: toFile, source: destination)
                    )
                } catch SwiftRefactoringError.conditionalOrConformingExtension {
                    rejected = true
                }
                try Expect.true(rejected, "constrained source extension is rejected")
            }

            Step("reject a destination function collision") {
                let fromFile = URL(fileURLWithPath: "/tmp/refactoring-collision-origin.swift")
                let toFile = URL(fileURLWithPath: "/tmp/refactoring-collision-destination.swift")
                let original = "extension Sample {\n    func duplicate() {}\n}\n"
                let destination = "extension Sample {\n    func duplicate() {}\n}\n"
                var rejected = false

                do {
                    _ = try SwiftRefactoringPlanner().moveFunction(
                        named: "duplicate",
                        inExtensionOf: "Sample",
                        from: try SwiftSemanticSource(file: fromFile, source: original),
                        to: try SwiftSemanticSource(file: toFile, source: destination)
                    )
                } catch SwiftRefactoringError.conflictingMember {
                    rejected = true
                }
                try Expect.true(rejected, "conflicting destination member is rejected")
            }

            Step("reject coincident insertion and deletion anchors") {
                let file = URL(fileURLWithPath: "/tmp/refactoring-overlap.swift")
                let original = "abcdef"
                let declaration = SwiftRefactoringDeclaration(
                    file: file,
                    name: "example",
                    extendedType: "Sample",
                    utf8Range: 1..<3,
                    text: "bc"
                )
                let plan = SwiftRefactoringPlan(
                    declaration: declaration,
                    destination: file,
                    edits: [
                        .init(file: file, utf8Range: 1..<3, expected: "bc", replacement: ""),
                        .init(file: file, utf8Range: 1..<1, expected: "", replacement: "xy"),
                    ],
                    baselines: [file: original]
                )
                var rejected = false

                do {
                    _ = try plan.preview(sources: [file: original])
                } catch SwiftRefactoringError.overlappingEdits {
                    rejected = true
                }
                try Expect.true(rejected, "coincident anchors are rejected regardless of sort order")
            }

            Step("preserve UTF-8 offsets after multibyte source text") {
                let fromFile = URL(fileURLWithPath: "/tmp/refactoring-unicode-origin.swift")
                let toFile = URL(fileURLWithPath: "/tmp/refactoring-unicode-destination.swift")
                let original = "// café\nextension Sample {\n    func move() -> Int { 7 }\n}\n"
                let destination = "extension Sample {\n}\n"
                let plan = try SwiftRefactoringPlanner().moveFunction(
                    named: "move",
                    inExtensionOf: "Sample",
                    from: try SwiftSemanticSource(file: fromFile, source: original),
                    to: try SwiftSemanticSource(file: toFile, source: destination)
                )
                let result = try plan.preview(sources: [
                    fromFile: original,
                    toFile: destination,
                ])
                try Expect.true(result[fromFile]?.contains("// café") == true, "unaffected multibyte source preserved")
                try Expect.true(result[toFile]?.contains("func move() -> Int { 7 }") == true, "function relocated at correct UTF-8 offset")
                try Expect.equal(
                    SwiftSemanticSource(source: result[toFile] ?? "").syntax.hasError,
                    false,
                    "destination parses after Unicode offset relocation"
                )
            }

            Step("reject a changed destination baseline") {
                let fromFile = URL(fileURLWithPath: "/tmp/refactoring-destination-drift-origin.swift")
                let toFile = URL(fileURLWithPath: "/tmp/refactoring-destination-drift-target.swift")
                let original = "extension Sample {\n    func move() {}\n}\n"
                let destination = "extension Sample {\n}\n"
                let plan = try SwiftRefactoringPlanner().moveFunction(
                    named: "move",
                    inExtensionOf: "Sample",
                    from: try SwiftSemanticSource(file: fromFile, source: original),
                    to: try SwiftSemanticSource(file: toFile, source: destination)
                )
                var rejected = false

                do {
                    _ = try plan.preview(sources: [
                        fromFile: original,
                        toFile: "// changed\n" + destination,
                    ])
                } catch SwiftRefactoringError.staleSource {
                    rejected = true
                }
                try Expect.true(rejected, "destination drift is rejected")
            }
        }
    }
}
