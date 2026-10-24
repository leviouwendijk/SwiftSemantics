import Foundation
import Primitives

/// SourceKit call-hierarchy identity. This is a source-location identity, not
/// a compiler USR: moving a declaration may change its ID across revisions.
public struct SwiftSemanticCallSymbolID: Sendable, Codable, Hashable {
    public let uri: URL
    public let selection_range: SwiftSemanticRange

    public init(_ item: SwiftSemanticCallHierarchyItem) {
        uri = item.location.uri
        selection_range = item.selectionRange
    }
}

/// One relationship at one caller-side call site. Separate identities let
/// parallel A -> B calls survive graph and path-tree projection.
public struct SwiftSemanticCallSiteID: Sendable, Codable, Hashable {
    public let source: SwiftSemanticCallSymbolID
    public let destination: SwiftSemanticCallSymbolID
    public let range: SwiftSemanticRange?

    public init(
        source: SwiftSemanticCallSymbolID,
        destination: SwiftSemanticCallSymbolID,
        range: SwiftSemanticRange?
    ) {
        self.source = source
        self.destination = destination
        self.range = range
    }
}

public struct SwiftSemanticCallGraph: Sendable, Codable, Hashable {
    public typealias Structure = Graph<
        SwiftSemanticCallSymbolID,
        SwiftSemanticCallHierarchyItem,
        SwiftSemanticCallSiteID,
        SwiftSemanticRange?
    >

    /// One caller and its direct compiler-reported outgoing relationships.
    /// The graph builder accepts observations from any source or test harness;
    /// the workspace actor provides the live compiler-backed collector.
    public struct Observation: Sendable, Codable, Hashable {
        public let caller: SwiftSemanticCallHierarchyItem
        public let outgoing: [SwiftSemanticOutgoingCall]

        public init(
            caller: SwiftSemanticCallHierarchyItem,
            outgoing: [SwiftSemanticOutgoingCall]
        ) {
            self.caller = caller
            self.outgoing = outgoing
        }
    }

    public enum BuildError: Error, Sendable, Equatable {
        case inconsistent_symbol(SwiftSemanticCallSymbolID)
        case unknown_unexpanded_symbol(SwiftSemanticCallSymbolID)
        case unknown_root(SwiftSemanticCallSymbolID)
    }

    public let root: SwiftSemanticCallSymbolID
    public let graph: Structure
    /// Known symbols not expanded because of a limit or an unsupported URI.
    /// Thus an absent edge is not necessarily evidence of no call relationship.
    public let unexpanded: [SwiftSemanticCallSymbolID]

    public var is_complete: Bool { unexpanded.isEmpty }

    public init(
        root item: SwiftSemanticCallHierarchyItem,
        observations: [Observation],
        unexpanded: [SwiftSemanticCallSymbolID] = []
    ) throws {
        let root = SwiftSemanticCallSymbolID(item)
        var nodes: [Structure.Node] = []
        var node_values: [SwiftSemanticCallSymbolID: SwiftSemanticCallHierarchyItem] = [:]
        var edges: [Structure.Edge] = []
        var seen_edges: Set<SwiftSemanticCallSiteID> = []

        func register(_ item: SwiftSemanticCallHierarchyItem) throws {
            let id = SwiftSemanticCallSymbolID(item)
            if let previous = node_values[id] {
                guard previous == item else {
                    throw BuildError.inconsistent_symbol(id)
                }
            } else {
                node_values[id] = item
                nodes.append(.init(id: id, value: item))
            }
        }

        try register(item)
        for observation in observations {
            try register(observation.caller)
            let caller = SwiftSemanticCallSymbolID(observation.caller)
            for outgoing in observation.outgoing {
                try register(outgoing.callee)
                let callee = SwiftSemanticCallSymbolID(outgoing.callee)
                // An empty range array still represents a known relationship,
                // only with an unknown call-site location.
                let sites: [SwiftSemanticRange?] = outgoing.callRanges.isEmpty
                    ? [nil] : outgoing.callRanges.map(Optional.some)
                for site in sites {
                    let id = SwiftSemanticCallSiteID(
                        source: caller,
                        destination: callee,
                        range: site
                    )
                    guard seen_edges.insert(id).inserted else { continue }
                    edges.append(.init(
                        id: id,
                        source: caller,
                        destination: callee,
                        value: site
                    ))
                }
            }
        }

        try self.init(
            root: root,
            graph: Structure(nodes: nodes, edges: edges),
            unexpanded: unexpanded
        )
    }

    public init(
        root: SwiftSemanticCallSymbolID,
        graph: Structure,
        unexpanded: [SwiftSemanticCallSymbolID] = []
    ) throws {
        let index = graph.index
        guard index.node(root) != nil else {
            throw BuildError.unknown_root(root)
        }
        var seen: Set<SwiftSemanticCallSymbolID> = []
        for id in unexpanded {
            guard index.node(id) != nil else {
                throw BuildError.unknown_unexpanded_symbol(id)
            }
        }
        self.root = root
        self.graph = graph
        self.unexpanded = unexpanded.filter { seen.insert($0).inserted }
    }

    private enum CodingKeys: String, CodingKey { case root, graph, unexpanded }

    public init(from decoder: Decoder) throws {
        let data = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            root: data.decode(SwiftSemanticCallSymbolID.self, forKey: .root),
            graph: data.decode(Structure.self, forKey: .graph),
            unexpanded: data.decode([SwiftSemanticCallSymbolID].self, forKey: .unexpanded)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var data = encoder.container(keyedBy: CodingKeys.self)
        try data.encode(root, forKey: .root)
        try data.encode(graph, forKey: .graph)
        try data.encode(unexpanded, forKey: .unexpanded)
    }

    /// A tree of path occurrences, not a second stored source of topology.
    /// Nodes resolve back to canonical graph symbols through graph.index.
    public func call_paths(
        limits: TreeTraversalLimits = .unlimited
    ) throws -> Tree<Structure.Occurrence> {
        try graph.tree_projection(roots: [root], limits: limits)
    }
}
