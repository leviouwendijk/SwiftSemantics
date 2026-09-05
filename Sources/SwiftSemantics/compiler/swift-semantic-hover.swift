public enum SwiftSemanticHoverFormat:
    String,
    Sendable,
    Codable,
    Hashable
{
    case plaintext
    case markdown
    case unknown
}

/// Compiler-generated hover information for one source position.
///
/// `contents` intentionally remains rendered text. SwiftSemantics does not
/// interpret Markdown or declaration markup; higher interfaces may choose how
/// to present it.
public struct SwiftSemanticHover:
    Sendable,
    Codable,
    Hashable
{
    public let contents: String
    public let format: SwiftSemanticHoverFormat
    public let range: SwiftSemanticRange?

    public init(
        contents: String,
        format: SwiftSemanticHoverFormat,
        range: SwiftSemanticRange? = nil
    ) {
        self.contents = contents
        self.format = format
        self.range = range
    }
}
