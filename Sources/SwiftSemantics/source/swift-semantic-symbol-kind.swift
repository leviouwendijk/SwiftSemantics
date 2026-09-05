/// Structural Swift declaration kinds discoverable without type checking.
///
/// Raw values intentionally match the established AgenticSwift symbol surface
/// so the later Agentic adapter can project these values without semantic loss.
public enum SwiftSemanticSymbolKind:
    String,
    Sendable,
    Codable,
    Hashable,
    CaseIterable
{
    case `import`
    case `struct`
    case `class`
    case actor
    case `enum`
    case `protocol`
    case `extension`
    case typealias_decl
    case function
    case initializer
    case subscript_decl
    case variable
    case enum_case
}
