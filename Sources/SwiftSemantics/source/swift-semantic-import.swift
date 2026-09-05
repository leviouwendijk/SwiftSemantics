public struct SwiftSemanticImport:
    Sendable,
    Hashable
{
    /// Parsed import path components.
    ///
    /// Examples:
    ///
    ///     import Foundation
    ///         ["Foundation"]
    ///
    ///     import struct Foundation.Date
    ///         ["Foundation", "Date"]
    public let path: [String]

    public init(
        path: [String]
    ) {
        self.path = path
    }

    public var moduleName: String? {
        path.first
    }

    public var qualifiedName: String {
        path.joined(
            separator: "."
        )
    }
}
