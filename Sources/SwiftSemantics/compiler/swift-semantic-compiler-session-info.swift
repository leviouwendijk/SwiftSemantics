import Foundation

/// Compiler-semantic provider backing one live Swift semantic workspace session.
///
/// String-backed cases use their boundary spelling directly rather than
/// introducing redundant raw-value mappings.
public enum SwiftSemanticCompilerProvider:
    String,
    Sendable,
    Codable,
    Hashable
{
    case sourcekit_lsp
}

/// Diagnostic information about the live compiler-semantic service attached to
/// a SwiftSemanticWorkspace.
///
/// Higher layers consume semantic operations rather than the underlying LSP
/// protocol. This value exists for lifecycle diagnostics, testing, and runtime
/// introspection only.
public struct SwiftSemanticCompilerSessionInfo:
    Sendable,
    Hashable
{
    public let provider: SwiftSemanticCompilerProvider
    public let executable: URL
    public let processIdentifier: Int64
    public let serverName: String?
    public let serverVersion: String?

    public init(
        provider: SwiftSemanticCompilerProvider,
        executable: URL,
        processIdentifier: Int64,
        serverName: String? = nil,
        serverVersion: String? = nil
    ) {
        self.provider = provider
        self.executable = executable.standardizedFileURL
        self.processIdentifier = processIdentifier
        self.serverName = serverName
        self.serverVersion = serverVersion
    }
}
