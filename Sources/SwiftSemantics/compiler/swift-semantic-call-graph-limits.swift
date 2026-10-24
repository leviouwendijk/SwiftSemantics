/// Bounds live SourceKit-LSP call-hierarchy collection. Graph-to-tree
/// presentation has its own independent TreeTraversalLimits.
public struct SwiftSemanticCallGraphLimits: Sendable, Codable, Hashable {
    public enum Error: Swift.Error, Sendable, Equatable {
        case negative_depth
        case nonpositive_expansion_budget
    }

    public let maximum_depth: Int
    public let maximum_expanded_symbols: Int

    public static let standard = Self(verified_depth: 3, verified_budget: 128)

    private init(verified_depth: Int, verified_budget: Int) {
        maximum_depth = verified_depth
        maximum_expanded_symbols = verified_budget
    }

    public init(
        maximum_depth: Int = 3,
        maximum_expanded_symbols: Int = 128
    ) throws {
        guard maximum_depth >= 0 else { throw Error.negative_depth }
        guard maximum_expanded_symbols > 0 else {
            throw Error.nonpositive_expansion_budget
        }
        self.init(verified_depth: maximum_depth, verified_budget: maximum_expanded_symbols)
    }
    private enum CodingKeys: String, CodingKey {
        case maximum_depth, maximum_expanded_symbols
    }

    public init(from decoder: Decoder) throws {
        let data = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            maximum_depth: data.decode(Int.self, forKey: .maximum_depth),
            maximum_expanded_symbols: data.decode(Int.self, forKey: .maximum_expanded_symbols)
        )
    }

}
