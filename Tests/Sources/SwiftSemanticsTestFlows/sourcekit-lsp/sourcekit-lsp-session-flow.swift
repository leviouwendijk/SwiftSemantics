import Foundation
import SwiftSemantics
import TestFlows

extension SwiftSemanticsFlowSuite {
    static var sourceKitLSPSessionFlow: TestFlow {
        TestFlow(
            "semantic-sourcekit-lsp-session",
            tags: [
                "compiler-semantics",
                "integration",
                "sourcekit-lsp",
                "swift-semantics",
                "workspace",
            ]
        ) {
            Step(
                "initialize reuse and gracefully shut down installed sourcekit-lsp"
            ) {
                let fixture = try SwiftSemanticPackageFixture()
                let workspace = SwiftSemanticWorkspace(
                    root: fixture.root
                )

                do {
                    let first = try await workspace.compilerSessionInfo()

                    try Expect.equal(
                        first.provider,
                        .sourcekit_lsp,
                        "workspace compiler provider"
                    )

                    try Expect.true(
                        first.processIdentifier > 0,
                        "sourcekit-lsp process identifier"
                    )

                    try Expect.true(
                        FileManager.default.isExecutableFile(
                            atPath: first.executable.path
                        ),
                        "discovered sourcekit-lsp executable exists"
                    )

                    let second = try await workspace.compilerSessionInfo()

                    try Expect.equal(
                        second.processIdentifier,
                        first.processIdentifier,
                        "workspace reuses one persistent compiler-semantic process"
                    )

                    try Expect.equal(
                        second.executable,
                        first.executable,
                        "workspace reuses the same discovered provider executable"
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
