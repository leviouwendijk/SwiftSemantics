import Foundation

/// SwiftSyntax-derived import structure over SwiftPM-authoritative source files.
public struct SwiftSemanticImportInventory:
    Sendable,
    Hashable
{
    public struct File:
        Sendable,
        Hashable
    {
        public let url: URL
        public let imports: [SwiftSemanticImport]

        public init(
            url: URL,
            imports: [SwiftSemanticImport]
        ) {
            self.url = url.standardizedFileURL
            self.imports = imports
        }
    }

    public struct Target:
        Sendable,
        Hashable
    {
        public let name: String
        public let files: [File]

        public init(
            name: String,
            files: [File]
        ) {
            self.name = name
            self.files = files.sorted {
                $0.url.path < $1.url.path
            }
        }

        public var imports: [SwiftSemanticImport] {
            files.flatMap(\.imports)
        }

        public var moduleNames: [String] {
            Array(
                Set(
                    imports.compactMap(\.moduleName)
                )
            )
            .sorted()
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
            $0.name < $1.name
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
