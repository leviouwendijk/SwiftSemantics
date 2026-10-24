import Foundation

public extension SwiftSemanticWorkspace {
    /// The compiler-selected callable declaration at a source position.
    func callHierarchyItem(
        in file: URL,
        at position: SwiftSemanticPosition
    ) async throws -> SwiftSemanticCallHierarchyItem? {
        let provider = try await compilerProvider()
        return try await provider.callHierarchyItem(in: file, at: position)
    }

    /// Collect a bounded canonical call graph from compiler-provided outgoing
    /// relationships. Each symbol is expanded once; cycles remain in graph
    /// topology and are bounded only when projected into a tree.
    func callGraph(
        in file: URL,
        at position: SwiftSemanticPosition,
        limits: SwiftSemanticCallGraphLimits = .standard
    ) async throws -> SwiftSemanticCallGraph? {
        let provider = try await compilerProvider()
        guard let root = try await provider.callHierarchyItem(
            in: file, at: position
        ) else { return nil }

        var queue: [(item: SwiftSemanticCallHierarchyItem, depth: Int)] = [
            (root, 0)
        ]
        var seen: Set<SwiftSemanticCallSymbolID> = [
            .init(root)
        ]
        var visited: Set<SwiftSemanticCallSymbolID> = []
        var observations: [SwiftSemanticCallGraph.Observation] = []
        var unexpanded: [SwiftSemanticCallSymbolID] = []
        var cursor = 0

        while cursor < queue.count {
            try Task.checkCancellation()
            let (item, depth) = queue[cursor]
            cursor += 1
            let id = SwiftSemanticCallSymbolID(item)
            guard visited.insert(id).inserted else { continue }

            guard depth < limits.maximum_depth,
                observations.count < limits.maximum_expanded_symbols,
                item.location.uri.isFileURL
            else {
                unexpanded.append(id)
                continue
            }

            let outgoing = try await provider.outgoingCalls(
                in: item.location.uri,
                at: item.selectionRange.start
            )
            observations.append(.init(caller: item, outgoing: outgoing))
            for call in outgoing {
                let next = SwiftSemanticCallSymbolID(call.callee)
                guard seen.insert(next).inserted else { continue }
                queue.append((call.callee, depth + 1))
            }
        }

        return try .init(
            root: root,
            observations: observations,
            unexpanded: unexpanded
        )
    }
}
