import Foundation
import Processes

/// Persistent compiler-semantic backend for one SwiftSemanticWorkspace.
///
/// SourceKit-LSP protocol and transport concepts remain internal. Public
/// workspace operations will progressively project definition/reference/
/// implementation/diagnostic results into SwiftSemantics-owned types.
actor SourceKitLSPProvider {
    nonisolated let info:
        SwiftSemanticCompilerSessionInfo

    private let transport:
        SourceKitLSPTransport

    private var isShutdown = false

    private init(
        info: SwiftSemanticCompilerSessionInfo,
        transport: SourceKitLSPTransport
    ) {
        self.info = info
        self.transport = transport
    }

    static func start(
        root: URL
    ) async throws -> SourceKitLSPProvider {
        try Task.checkCancellation()

        let executable = try await SourceKitLSPExecutableLocator.locate()

        try Task.checkCancellation()

        let session: ProcessSession

        do {
            session = try await ProcessSession.start(
                .init(
                    executable: .path(
                        executable.path
                    ),
                    workingDirectory: root,
                    environment: .inherited
                )
            )
        } catch {
            throw SwiftSemanticCompilerError.providerUnavailable(
                "Could not start sourcekit-lsp at \(executable.path): \(error)"
            )
        }

        let transport = await SourceKitLSPTransport.start(
            session: session
        )

        do {
            let workspaceName = root.lastPathComponent.isEmpty
                ? "workspace"
                : root.lastPathComponent

            let parameters = SourceKitLSPInitializeParams(
                processId: ProcessInfo
                    .processInfo
                    .processIdentifier,
                clientInfo: .init(
                    name: "SwiftSemantics",
                    version: nil
                ),
                rootUri: root.absoluteString,
                capabilities: [:],
                workspaceFolders: [
                    .init(
                        uri: root.absoluteString,
                        name: workspaceName
                    ),
                ]
            )

            let initialization: SourceKitLSPInitializeResult =
                try await transport.request(
                    method: "initialize",
                    params: parameters
                )

            try await transport.notify(
                method: "initialized",
                params: [String: String]()
            )

            try Task.checkCancellation()

            return SourceKitLSPProvider(
                info: .init(
                    provider: .sourcekit_lsp,
                    executable: executable,
                    processIdentifier: session.processIdentifier,
                    serverName: initialization.serverInfo?.name,
                    serverVersion: initialization.serverInfo?.version
                ),
                transport: transport
            )
        } catch {
            await transport.terminate()
            throw error
        }
    }

    func shutdown() async throws {
        guard !isShutdown else {
            return
        }

        isShutdown = true

        do {
            try await transport.requestWithoutResult(
                method: "shutdown"
            )

            try await transport.notify(
                method: "exit"
            )

            try await transport.finishInput()

            let exit = try await transport.wait()

            guard exit.isSuccess else {
                throw SwiftSemanticCompilerError.providerExited(
                    "sourcekit-lsp did not exit successfully after shutdown."
                )
            }
        } catch {
            await transport.terminate()
            throw error
        }
    }
}
