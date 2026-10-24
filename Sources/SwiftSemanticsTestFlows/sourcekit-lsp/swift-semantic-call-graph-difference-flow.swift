import Difference
import Foundation
import SwiftSemantics
import TestFlows

extension SwiftSemanticsFlowSuite {
    static var callGraphDifferenceFlow: TestFlow {
        TestFlow("semantic-call-graph-revision-difference", tags: ["call-graph", "difference"]) {
            Step("compare canonical call site changes across captured revisions") {
                let uri = URL(fileURLWithPath: "/tmp/semantic-call-graph-difference.swift")
                func range(_ line: Int) -> SwiftSemanticRange {
                    .init(
                        start: .init(line: line, utf16Column: 1),
                        end: .init(line: line, utf16Column: 8)
                    )
                }
                func symbol(_ name: String, _ line: Int) -> SwiftSemanticCallHierarchyItem {
                    .init(name: name, kind: .function,
                          location: .init(uri: uri, range: range(line)),
                          selectionRange: range(line))
                }
                let a = symbol("a", 1)
                let b = symbol("b", 10)
                let c = symbol("c", 20)
                let before = try SwiftSemanticCallGraph(
                    root: a,
                    observations: [
                        .init(caller: a, outgoing: [
                            .init(callee: b, callRanges: [range(2)]),
                        ]),
                    ]
                )
                let after = try SwiftSemanticCallGraph(
                    root: a,
                    observations: [
                        .init(caller: a, outgoing: [
                            .init(callee: b, callRanges: [range(2)]),
                            .init(callee: c, callRanges: [range(3)]),
                        ]),
                    ]
                )
                let delta = GraphDiffer.make(
                    before: before.graph,
                    after: after.graph,
                    equivalent_node: ==,
                    equivalent_edge: ==
                )
                try Expect.true(
                    delta.has_changes,
                    "revision graph reports added call relationships"
                )
                try Expect.equal(delta.nodes.filter { $0.change == .added }.count, 1)
                try Expect.equal(delta.edges.filter { $0.change == .added }.count, 1)
                try Expect.equal(delta.edges.filter { $0.change == .unchanged }.count, 1)
                let tree = try after.call_paths()
                try Expect.equal(Array(tree.walk()).count, 3)
            }
        }
    }
}
