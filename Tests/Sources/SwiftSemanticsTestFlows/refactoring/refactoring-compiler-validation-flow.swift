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

            Step("preserve relative local package dependencies without weakening compilation") {
                let manager = FileManager.default
                let parent = manager.temporaryDirectory
                    .appendingPathComponent("r5c-path-dependency-\(UUID().uuidString)", isDirectory: true)
                let dependency = parent.appendingPathComponent("Dependency", isDirectory: true)
                let dependencySource = dependency.appendingPathComponent("Sources/Dependency/Value.swift")
                let root = parent.appendingPathComponent("Subject", isDirectory: true)
                let manifest = root.appendingPathComponent("Package.swift")
                let declaration = root.appendingPathComponent("Sources/Core/Declaration.swift")
                let usage = root.appendingPathComponent("Sources/Core/Use.swift")
                try manager.createDirectory(
                    at: dependencySource.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                defer { try? manager.removeItem(at: parent) }
                try """
                // swift-tools-version: 6.0
                import PackageDescription
                let package = Package(
                    name: "Dependency",
                    products: [.library(name: "Dependency", targets: ["Dependency"])],
                    targets: [.target(name: "Dependency")]
                )
                """.write(
                    to: dependency.appendingPathComponent("Package.swift"),
                    atomically: true,
                    encoding: .utf8
                )
                let dependencyContents = "public struct DependencyValue { public init() {} }\n"
                try dependencyContents.write(to: dependencySource, atomically: true, encoding: .utf8)

                let package = try SwiftRefactoringCompilerPackage(root: root, files: [
                    manifest: """
                    // swift-tools-version: 6.0
                    import PackageDescription
                    let package = Package(
                        name: "Subject",
                        products: [.library(name: "Core", targets: ["Core"])],
                        dependencies: [.package(path: "../Dependency")],
                        targets: [
                            .target(name: "Core", dependencies: [
                                .product(name: "Dependency", package: "Dependency")
                            ])
                        ]
                    )
                    """,
                    declaration: "import Dependency\npublic struct Alpha { public init() {} }\n",
                    usage: "import Dependency\npublic func instance() -> Alpha { _ = DependencyValue(); return Alpha() }\n",
                ])
                let replacements: [URL: String] = [
                    declaration: "import Dependency\npublic struct Beta { public init() {} }\n",
                    usage: "import Dependency\npublic func instance() -> Beta { _ = DependencyValue(); return Beta() }\n",
                ]
                let validator = SwiftRefactoringCompilerValidator()
                let valid = try await validator.validate(package: package, replacements: replacements)
                try Expect.true(valid.succeeded, "Local path dependency resolves: \(valid.stderr)")
                try Expect.equal(
                    valid.stagedDirectory.deletingLastPathComponent(), parent,
                    "Stage preserves the original package's parent directory"
                )
                try Expect.equal(manager.fileExists(atPath: valid.stagedDirectory.path), false,
                    "Temporary sibling stage cleaned after successful compilation")
                try Expect.equal(manager.fileExists(atPath: root.path), false,
                    "Original subject package was never materialized")
                try Expect.equal(
                    try String(contentsOf: dependencySource, encoding: .utf8),
                    dependencyContents,
                    "Local dependency source is not modified"
                )

                try manager.removeItem(at: dependency)
                let invalid = try await validator.validate(package: package, replacements: replacements)
                try Expect.equal(invalid.succeeded, false,
                    "Missing local dependency fails closed rather than bypassing compiler validation")
                try Expect.equal(manager.fileExists(atPath: invalid.stagedDirectory.path), false,
                    "Temporary sibling stage cleaned after failed compilation")
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
