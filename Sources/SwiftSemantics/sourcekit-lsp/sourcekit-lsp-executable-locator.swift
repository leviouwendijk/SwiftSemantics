import Foundation
import Processes

/// Discovers SourceKit-LSP from the active Apple toolchain rather than
/// hard-coding an Xcode or toolchain installation path.
enum SourceKitLSPExecutableLocator {
    static func locate()
        async throws
        -> URL
    {
        let result: ProcessResult

        do {
            result = try await ProcessRunner().run(
                .init(
                    executable: .path(
                        "/usr/bin/xcrun"
                    ),
                    arguments: [
                        "--find",
                        "sourcekit-lsp",
                    ],
                    environment: .inherited,
                    timeout: .seconds(
                        10
                    )
                )
            )
        } catch {
            throw SwiftSemanticCompilerError.providerUnavailable(
                "xcrun could not discover sourcekit-lsp: \(error)"
            )
        }

        guard result.isSuccess else {
            let stderr = result.stderrText
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

            throw SwiftSemanticCompilerError.providerUnavailable(
                stderr.isEmpty
                    ? "xcrun --find sourcekit-lsp failed."
                    : stderr
            )
        }

        let path = result.stdoutText
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !path.isEmpty else {
            throw SwiftSemanticCompilerError.providerUnavailable(
                "xcrun returned an empty sourcekit-lsp path."
            )
        }

        guard FileManager.default.isExecutableFile(
            atPath: path
        ) else {
            throw SwiftSemanticCompilerError.providerUnavailable(
                "Discovered sourcekit-lsp is not executable: \(path)"
            )
        }

        return URL(
            fileURLWithPath: path
        )
        .standardizedFileURL
    }
}
