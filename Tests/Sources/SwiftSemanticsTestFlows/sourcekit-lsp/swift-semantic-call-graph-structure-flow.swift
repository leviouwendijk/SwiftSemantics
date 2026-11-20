import Foundation
import SwiftSemantics
import TestFlows

extension SwiftSemanticsFlowSuite {
    static var callGraphStructureFlow: TestFlow {
        TestFlow("semantic-call-graph-structure", tags: ["call-graph", "graph", "projection"]) {
            Step("preserve parallel call sites shared callees and recursive paths") {
                let uri = URL(fileURLWithPath: "/tmp/semantic-call-graph-fixture.swift")
                func point(_ line: Int) -> SwiftSemanticPosition {
                    .init(line: line, utf16Column: 1)
                }
                func range(_ line: Int) -> SwiftSemanticRange {
                    .init(start: point(line), end: .init(line: line, utf16Column: 8))
                }
                func item(_ name: String, _ line: Int) -> SwiftSemanticCallHierarchyItem {
                    .init(
                        name: name,
                        kind: .function,
                        location: .init(uri: uri, range: range(line)),
                        selectionRange: range(line)
                    )
                }

                let a = item("a", 1)
                let b = item("b", 10)
                let c = item("c", 20)
                let d = item("d", 30)
                let graph = try SwiftSemanticCallGraph(
                    root: a,
                    observations: [
                        .init(caller: a, outgoing: [
                            .init(callee: b, callRanges: [range(2), range(3)]),
                            .init(callee: c, callRanges: [range(4)]),
                        ]),
                        .init(caller: b, outgoing: [
                            .init(callee: d, callRanges: [range(11)]),
                        ]),
                        .init(caller: c, outgoing: [
                            .init(callee: d, callRanges: [range(21)]),
                        ]),
                        .init(caller: d, outgoing: [
                            .init(callee: b, callRanges: [range(31)]),
                        ]),
                    ]
                )
                try Expect.equal(graph.graph.nodes.count, 4)
                try Expect.equal(graph.graph.edges.count, 6)
                try Expect.equal(graph.graph.index.outgoing_edges(from: .init(a)).count, 3)
                let paths = try graph.call_paths()
                let occurrences = paths.walk().map(\.node.value)
                try Expect.equal(
                    occurrences.filter { $0.node_id == .init(d) && !$0.is_cycle_reference }.count,
                    3
                )
                try Expect.true(
                    occurrences.contains(where: \.is_cycle_reference),
                    "recursive call paths terminate with a cycle reference"
                )
                let encoded = try JSONEncoder().encode(graph)
                let decoded = try JSONDecoder().decode(
                    SwiftSemanticCallGraph.self,
                    from: encoded
                )
                try Expect.equal(decoded, graph)

                let no_site = try SwiftSemanticCallGraph(
                    root: a,
                    observations: [
                        .init(caller: a, outgoing: [
                            .init(callee: b, callRanges: []),
                            .init(callee: b, callRanges: []),
                        ]),
                    ]
                )
                try Expect.equal(no_site.graph.edges.count, 1)
                try Expect.equal(no_site.graph.edges.first?.value, nil)
            }
        }
    }
}
