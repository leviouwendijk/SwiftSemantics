import Foundation

struct SourceKitLSPOpenDocument:
    Sendable
{
    let version: Int
    let text: String
}
