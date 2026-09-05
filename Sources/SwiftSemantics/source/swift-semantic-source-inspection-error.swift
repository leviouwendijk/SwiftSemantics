import Foundation

public enum SwiftSemanticSourceInspectionError:
    Error,
    Sendable,
    LocalizedError
{
    case unsupportedFile(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedFile(let path):
            return "Swift semantic source inspection only supports Swift source files. Received: \(path)"
        }
    }
}
