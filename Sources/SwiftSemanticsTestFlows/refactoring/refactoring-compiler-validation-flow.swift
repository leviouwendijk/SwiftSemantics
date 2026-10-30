import Foundation
import SwiftRefactoring
import SwiftSemantics
import TestFlows

extension SwiftSemanticsFlowSuite {
    static var refactoringCompilerValidationFlow: TestFlow {
        TestFlow("swift-refactoring-staged-compiler-validation", tags: ["refactoring", "compiler-validation"]) {
            Step("compile a complete cross-file rename in a disposable SwiftPM package") {
                let fixture = try compilerValidationFixture()
                let proposal = SwiftSemanticRenameResult(documents: [
                    .init(uri: fixture.declaration, version: nil, edits: [
                        .init(range: compilerSpan(15, 20), newText: "Beta"),
                    ]),
                    .init(uri: fixture.usage, version: nil, edits: [
                        .init(range: compilerSpan(27, 32), newText: "Beta"),
                        .init(range: compilerSpan(35, 40), newText: "Beta"),
                    ]),
                ])
                let plan = try SwiftRefactoringRenamePlanner().plan(
                    proposal, sources: fixture.package.files
                )
                let result = try await SwiftRefactoringCompilerValidator().validate(
                    plan, package: fixture.package
                )
                try Expect.true(result.succeeded, "renamed package compiles: \(result.stderr)")
                try Expect.equal(
                    FileManager.default.fileExists(atPath: result.stagedDirectory.path),
                    false,
                    "disposable compilation package removed"
                )
                try Expect.equal(
                    FileManager.default.fileExists(atPath: fixture.package.root.path),
                    false,
                    "original synthetic package root never materialized"
                )
                try Expect.equal(
                    fixture.package.files[fixture.declaration],
                    "public struct Alpha { public init() {} }\n",
                    "original declaration snapshot unchanged"
                )
            }

            Step("reject a compilation-breaking incomplete rename") {
                let fixture = try compilerValidationFixture()
                let proposal = SwiftSemanticRenameResult(documents: [
                    .init(uri: fixture.declaration, version: nil, edits: [
                        .init(range: compilerSpan(15, 20), newText: "Beta"),
                    ]),
                ])
                let plan = try SwiftRefactoringRenamePlanner().plan(
                    proposal, sources: fixture.package.files
                )
                let result = try await SwiftRefactoringCompilerValidator().validate(
                    plan, package: fixture.package
                )
                try Expect.equal(result.succeeded, false, "incomplete rename fails compilation")
                let diagnostics = result.stdout + "\n" + result.stderr
                try Expect.true(
                    diagnostics.contains("error:"),
                    "compiler diagnostics retained; stdout:\n\(result.stdout)\nstderr:\n\(result.stderr)"
                )
                try Expect.equal(
                    FileManager.default.fileExists(atPath: result.stagedDirectory.path),
                    false,
                    "failed compilation package removed"
                )
            }

            Step("reject a stale snapshot before materializing sources") {
                let fixture = try compilerValidationFixture()
                let proposal = SwiftSemanticRenameResult(documents: [
                    .init(uri: fixture.declaration, version: nil, edits: [
                        .init(range: compilerSpan(15, 20), newText: "Beta"),
                    ]),
                ])
                let plan = try SwiftRefactoringRenamePlanner().plan(
                    proposal, sources: fixture.package.files
                )
                var altered = fixture.package.files
                altered[fixture.declaration] = "// changed\n" + (
                    altered[fixture.declaration] ?? ""
                )
                let changedPackage = try SwiftRefactoringCompilerPackage(
                    root: fixture.package.root, files: altered
                )
                var rejected = false
                do {
                    _ = try await SwiftRefactoringCompilerValidator().validate(
                        plan, package: changedPackage
                    )
                } catch SwiftRefactoringError.staleSource {
                    rejected = true
                }
                try Expect.true(rejected, "stale preview must not compile")
            }
        }
    }

    private static func compilerValidationFixture() throws -> (
        package: SwiftRefactoringCompilerPackage,
        declaration: URL,
        usage: URL
    ) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("r5c-source-snapshot-\(UUID().uuidString)", isDirectory: true)
        let manifest = root.appendingPathComponent("Package.swift")
        let declaration = root.appendingPathComponent("Sources/Core/Declaration.swift")
        let usage = root.appendingPathComponent("Sources/Core/Use.swift")
        let package = try SwiftRefactoringCompilerPackage(root: root, files: [
            manifest: """
            // swift-tools-version: 6.0
            import PackageDescription
            let package = Package(
                name: "RenameValidation",
                products: [.library(name: "Core", targets: ["Core"])],
                targets: [.target(name: "Core")]
            )
            """,
            declaration: "public struct Alpha { public init() {} }\n",
            usage: "public func instance() -> Alpha { Alpha() }\n",
        ])
        return (package, declaration, usage)
    }

    private static func compilerSpan(_ start: Int, _ end: Int) -> SwiftSemanticRange {
        .init(
            start: .init(line: 1, utf16Column: start),
            end: .init(line: 1, utf16Column: end)
        )
    }
}
