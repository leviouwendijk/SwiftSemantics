import Foundation

/// Failures produced while establishing or communicating with the compiler-
/// semantic provider.
public enum SwiftSemanticCompilerError:
    Error,
    Sendable,
    LocalizedError
{
    case providerUnavailable(String)
    case protocolViolation(String)
    case requestFailed(
        code: Int,
        message: String
    )
    case requestTimedOut(
        method: String
    )
    case transportFailed(String)
    case connectionClosed
    case providerExited(String)

    public var errorDescription: String? {
        switch self {
        case .providerUnavailable(let message):
            return "Swift compiler-semantic provider is unavailable: \(message)"

        case .protocolViolation(let message):
            return "Swift compiler-semantic provider protocol violation: \(message)"

        case .requestFailed(let code, let message):
            return "Swift compiler-semantic request failed with code \(code): \(message)"

        case .requestTimedOut(let method):
            return "Swift compiler-semantic request '\(method)' timed out."

        case .transportFailed(let message):
            return "Swift compiler-semantic transport failed: \(message)"

        case .connectionClosed:
            return "Swift compiler-semantic provider connection closed."

        case .providerExited(let message):
            return "Swift compiler-semantic provider exited: \(message)"
        }
    }
}
