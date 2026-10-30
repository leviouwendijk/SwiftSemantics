import Foundation
import Path
import SwiftRefactoring
import Writers

/// Captures explicitly selected SwiftPM sources through scoped Writers access.
/// The caller must establish that its supplied source inventory is complete.
public struct SwiftRefactoringWorkspaceSources: Sendable {
    public init() {}

    public func capture(
        sourceFiles: [URL],
        in workspace: WorkspaceWriter
    ) throws -> SwiftRefactoringCompilerPackage {
        let root = try workspace.access.root().rootURL.standardizedFileURL
        let manifest = root.appendingPathComponent("Package.swift")
        let candidates = Set(sourceFiles.map(\.standardizedFileURL))
        var files: [URL: String] = [:]

        for file in [manifest] + candidates.sorted(by: { $0.path < $1.path }) {
            let authorized = try Self.authorize(
                file,
                packageRoot: root,
                in: workspace
            )
            guard authorized.presentationPath == "Package.swift" || (
                authorized.presentationPath.hasPrefix("Sources/") &&
                file.pathExtension == "swift"
            ) else {
                throw SwiftRefactoringPublicationError.invalidTarget(file)
            }
            guard case .text(let state) = try StandardResourceState.read(
                at: authorized.absoluteURL
            ), state.encoding == .utf8 else {
                throw SwiftRefactoringPublicationError.staleSource(file)
            }
            files[authorized.absoluteURL] = state.content
        }
        return try SwiftRefactoringCompilerPackage(root: root, files: files)
    }

    /// Resolve a source URL under the existing workspace root and policy.
    public static func authorize(
        _ file: URL,
        packageRoot: URL,
        in workspace: WorkspaceWriter
    ) throws -> AuthorizedPath {
        let root = try workspace.access.root()
        guard root.rootURL.standardizedFileURL == packageRoot.standardizedFileURL else {
            throw SwiftRefactoringPublicationError.invalidTarget(file)
        }
        guard file.isFileURL,
            file == file.standardizedFileURL else {
            throw SwiftRefactoringPublicationError.invalidTarget(file)
        }
        let descendant = try root.scope.scope(file, type: .file)
        let authorized = try workspace.authorize(descendant, type: .file)
        guard authorized.absoluteURL.standardizedFileURL == file,
            file.resolvingSymlinksInPath() == file else {
            throw SwiftRefactoringPublicationError.targetMappingMismatch(file)
        }
        return authorized
    }
}
