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
        let provider = try await compilerProvider()

        return provider.info
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

extension SwiftSemanticWorkspace {
    func compilerProvider()
        async throws
        -> SourceKitLSPProvider
    {
        switch compilerSessionState {
        case .ready(let provider):
            return provider

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

    func completeCompilerSessionStart(
        generation: UInt64,
        task: Task<
            SourceKitLSPProvider,
            any Error
        >
    ) async throws -> SourceKitLSPProvider {
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

                return provider

            case .ready(let currentProvider):
                return currentProvider

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
