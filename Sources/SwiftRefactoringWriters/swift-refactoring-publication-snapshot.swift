import Foundation
import SwiftRefactoring
import Writers

/// Exact byte snapshots of the files supplied to a source-only SwiftPM build.
/// This is a freshness guard, not proof that a caller supplied every dependency
/// of a real-world package. It must be checked again by the publishing host.
public struct SwiftRefactoringPublicationSnapshot: Sendable {
    public let package: SwiftRefactoringCompilerPackage

    public init(package: SwiftRefactoringCompilerPackage) {
        self.package = package
    }

    /// Revalidate the original manifest and all supplied Swift sources, and
    /// reject newly added Swift sources under Sources/ before publication.
    /// Does not reserve paths or make publication atomic.
    public func requireCurrent(in workspace: WorkspaceWriter) throws {
        let root = package.root
        var expectedSources: Set<URL> = []

        for (file, baseline) in package.files {
            let authorized = try SwiftRefactoringWorkspaceSources.authorize(
                file,
                packageRoot: root,
                in: workspace
            )
            let relative = authorized.presentationPath
            guard relative == "Package.swift" || relative.hasPrefix("Sources/") else {
                throw SwiftRefactoringPublicationError.invalidTarget(file)
            }

            guard let actual = try StandardResourceState.read(
                at: authorized.absoluteURL
            ).dataContent,
                actual == Data(baseline.utf8) else {
                throw SwiftRefactoringPublicationError.staleSource(file)
            }
            if relative != "Package.swift" {
                expectedSources.insert(file)
            }
        }

        let sourceRoot = root.appendingPathComponent("Sources", isDirectory: true)
        guard sourceRoot.resolvingSymlinksInPath() == sourceRoot else {
            throw SwiftRefactoringPublicationError.targetMappingMismatch(sourceRoot)
        }
        let subpaths = try FileManager.default.subpathsOfDirectory(atPath: sourceRoot.path)
        var actualSources: Set<URL> = []
        for subpath in subpaths {
            let file = sourceRoot.appendingPathComponent(subpath).standardizedFileURL
            guard file.resolvingSymlinksInPath() == file else {
                throw SwiftRefactoringPublicationError.unexpectedSource(file)
            }
            if subpath.hasSuffix(".swift") {
                actualSources.insert(file)
            }
        }
        if let extra = actualSources.subtracting(expectedSources)
            .sorted(by: { $0.path < $1.path }).first {
            throw SwiftRefactoringPublicationError.unexpectedSource(extra)
        }
        if let missing = expectedSources.subtracting(actualSources)
            .sorted(by: { $0.path < $1.path }).first {
            throw SwiftRefactoringPublicationError.staleSource(missing)
        }
    }
}
