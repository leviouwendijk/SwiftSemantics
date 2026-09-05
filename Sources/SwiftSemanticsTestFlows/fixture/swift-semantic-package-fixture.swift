import Foundation

struct SwiftSemanticPackageFixture {
    let root: URL

    init() throws {
        root = FileManager
            .default
            .temporaryDirectory
            .appendingPathComponent(
                "swift-semantics-package-\(UUID().uuidString)",
                isDirectory: true
            )

        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )

        try writeLeafPackage()
        try writeRootPackage()
    }

    func remove() {
        try? FileManager.default.removeItem(
            at: root
        )
    }
}

private extension SwiftSemanticPackageFixture {
    func writeRootPackage() throws {
        try write(
            """
            // swift-tools-version: 6.3

            import PackageDescription

            let package = Package(
                name: "SemanticFixture",
                products: [
                    .library(
                        name: "SemanticCore",
                        targets: [
                            "SemanticCore",
                        ]
                    ),
                ],
                dependencies: [
                    .package(
                        path: "Dependencies/Leaf"
                    ),
                ],
                targets: [
                    .target(
                        name: "Helper"
                    ),
                    .target(
                        name: "SemanticCore",
                        dependencies: [
                            .byName(
                                name: "Helper"
                            ),
                            .product(
                                name: "Leaf",
                                package: "Leaf"
                            ),
                        ]
                    ),
                ]
            )
            """,
            to: "Package.swift"
        )

        try write(
            """
            public struct Helper {
                public init() {}
            }
            """,
            to: "Sources/Helper/Helper.swift"
        )

        try write(
            """
            import Helper
            import Leaf
            import struct Foundation.Date

            public struct SemanticCore {
                public init() {
                    _ = Helper()
                    _ = Leaf()
                }
            }
            """,
            to: "Sources/SemanticCore/SemanticCore.swift"
        )
    }

    func writeLeafPackage() throws {
        try write(
            """
            // swift-tools-version: 6.3

            import PackageDescription

            let package = Package(
                name: "Leaf",
                products: [
                    .library(
                        name: "Leaf",
                        targets: [
                            "Leaf",
                        ]
                    ),
                ],
                targets: [
                    .target(
                        name: "Leaf"
                    ),
                ]
            )
            """,
            to: "Dependencies/Leaf/Package.swift"
        )

        try write(
            """
            public struct Leaf {
                public init() {}
            }
            """,
            to: "Dependencies/Leaf/Sources/Leaf/Leaf.swift"
        )
    }

    func write(
        _ contents: String,
        to path: String
    ) throws {
        let destination = root
            .appendingPathComponent(
                path
            )

        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        try contents.write(
            to: destination,
            atomically: true,
            encoding: .utf8
        )
    }
}
