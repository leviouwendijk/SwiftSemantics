import Executable
import Foundation

/// Long-lived semantic context for one authorized Swift workspace root.
///
/// The workspace is intentionally an actor from the beginning because later
/// semantic providers, especially SourceKit-LSP, have persistent mutable state
/// whose lifetime should be tied to this object.
///
/// SwiftPM mechanics remain owned by Executable. SwiftSemantics consumes those
/// mechanics and projects them into its own provider-neutral semantic types.
public actor SwiftSemanticWorkspace {
    public nonisolated let root: URL

    public init(
        root: URL
    ) {
        self.root = root.standardizedFileURL
    }

    /// Resolve package topology for the workspace root through SwiftPM.
    ///
    /// The returned model is owned by SwiftSemantics and therefore does not
    /// expose Executable implementation types to higher semantic consumers.
    public func packageGraph()
        async throws
        -> SwiftSemanticPackageGraph
    {
        let graph = try await Executable.Package.graph(
            at: root
        )

        return SwiftSemanticPackageGraph(
            executable: graph
        )
    }
}
