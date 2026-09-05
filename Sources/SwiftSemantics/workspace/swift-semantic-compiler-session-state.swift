enum SwiftSemanticCompilerSessionState:
    Sendable
{
    case idle

    case starting(
        generation: UInt64,
        task: Task<
            SourceKitLSPProvider,
            any Error
        >
    )

    case ready(
        SourceKitLSPProvider
    )
}
