import Foundation

/// SwiftPM-authoritative source membership projected into SwiftSemantics.
///
/// Target membership is supplied by Executable/SwiftPM rather than inferred
/// from repository layout. Structural and semantic providers consume this
/// inventory instead of independently walking source directories.
public struct SwiftSemanticSourceInventory:
    Sendable,
    Hashable
{
    public struct Target:
        Sendable,
        Hashable
    {
        public let name: String
        public let type: String
        public let directory: URL?
        public let sourceFiles: [URL]

        public init(
            name: String,
            type: String,
            directory: URL? = nil,
            sourceFiles: [URL] = []
        ) {
            self.name = name
            self.type = type
            self.directory = directory?.standardizedFileURL
            self.sourceFiles = sourceFiles
                .map(\.standardizedFileURL)
                .sorted {
                    $0.path < $1.path
                }
        }
    }

    public let packageName: String
    public let targets: [Target]

    public init(
        packageName: String,
        targets: [Target]
    ) {
        self.packageName = packageName
        self.targets = targets.sorted {
            targetKey($0) < targetKey($1)
        }
    }

    public func target(
        named name: String
    ) -> Target? {
        targets.first {
            $0.name == name
        }
    }
}

private func targetKey(
    _ target: SwiftSemanticSourceInventory.Target
) -> String {
    [
        target.name,
        target.type,
        target.directory?.path ?? "",
    ]
        .joined(
            separator: "\u{1F}"
        )
}
