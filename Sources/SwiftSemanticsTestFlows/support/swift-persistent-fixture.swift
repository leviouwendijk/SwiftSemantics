import Foundation

enum SwiftPersistentFixtureError: Error {
    case missing(URL)
    case drift(URL)
}

enum SwiftPersistentFixture {
    static func root(named name: String) throws -> URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(
                "Testing/fixture-project/\(name)",
                isDirectory: true
            )

        let manifest = root.appendingPathComponent("Package.swift")
        guard FileManager.default.fileExists(atPath: manifest.path) else {
            throw SwiftPersistentFixtureError.missing(manifest)
        }
        return root
    }
}
