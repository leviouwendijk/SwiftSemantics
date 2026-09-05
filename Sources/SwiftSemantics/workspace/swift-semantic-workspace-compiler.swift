public extension SwiftSemanticWorkspace {
    /// Lazily establish the persistent compiler-semantic session for this
    /// workspace and return diagnostic information about it.
    ///
    /// Repeated calls reuse the same SourceKit-LSP process. The LSP protocol is
    /// an implementation detail; higher-level semantic operations are exposed
    /// separately by SwiftSemantics.
    func compilerSessionInfo()
        async throws
        -> SwiftSemanticCompilerSessionInfo
    {
        switch compilerSessionState {
        case .ready(let provider):
            return provider.info

        case .starting(
            let generation,
            let task
        ):
            return try await completeCompilerSessionStart(
                generation: generation,
                task: task
            )

        case .idle:
            compilerSessionGeneration &+= 1

            let generation = compilerSessionGeneration
            let root = self.root

            let task = Task {
                try await SourceKitLSPProvider.start(
                    root: root
                )
            }

            compilerSessionState = .starting(
                generation: generation,
                task: task
            )

            return try await completeCompilerSessionStart(
                generation: generation,
                task: task
            )
        }
    }

    /// Gracefully stop the workspace compiler-semantic provider.
    ///
    /// A later semantic request may start a fresh session again.
    func shutdownCompilerSession() async throws {
        switch compilerSessionState {
        case .idle:
            return

        case .ready(let provider):
            compilerSessionState = .idle
            try await provider.shutdown()

        case .starting(
            _,
            let task
        ):
            compilerSessionState = .idle
            task.cancel()

            if let provider = try? await task.value {
                try? await provider.shutdown()
            }
        }
    }
}

private extension SwiftSemanticWorkspace {
    func completeCompilerSessionStart(
        generation: UInt64,
        task: Task<
            SourceKitLSPProvider,
            any Error
        >
    ) async throws -> SwiftSemanticCompilerSessionInfo {
        do {
            let provider = try await task.value

            switch compilerSessionState {
            case .starting(
                let currentGeneration,
                _
            ) where currentGeneration == generation:
                compilerSessionState = .ready(
                    provider
                )

                return provider.info

            case .ready(let currentProvider):
                return currentProvider.info

            case .idle,
                 .starting:
                try? await provider.shutdown()
                throw CancellationError()
            }
        } catch {
            if case .starting(
                let currentGeneration,
                _
            ) = compilerSessionState,
               currentGeneration == generation
            {
                compilerSessionState = .idle
            }

            throw error
        }
    }
}
