import Foundation
import Processes

public enum SwiftRefactoringCompilerValidationError: Error, Sendable {
    case invalidPackageRoot(URL)
    case missingManifest(URL)
    case unsupportedPackageFile(URL)
    case unsupportedRefactoringFile(URL)
    case noSwiftSources
    case emptyReplacements
}

/// Complete source-only SwiftPM package snapshot. No files are read from
/// `root`: every staged byte must be supplied explicitly by the caller.
public struct SwiftRefactoringCompilerPackage: Sendable {
    public let root: URL
    public let files: [URL: String]

    public init(root: URL, files: [URL: String]) throws {
        guard root.isFileURL else {
            throw SwiftRefactoringCompilerValidationError.invalidPackageRoot(root)
        }
        let root = root.standardizedFileURL
        let manifest = root.appendingPathComponent("Package.swift")
        guard files[manifest] != nil else {
            throw SwiftRefactoringCompilerValidationError.missingManifest(manifest)
        }

        var hasSources = false
        for file in files.keys {
            guard file.isFileURL,
                file == file.standardizedFileURL,
                let relative = Self.relativePath(file, below: root),
                relative == "Package.swift" || Self.isSwiftSource(relative) else {
                throw SwiftRefactoringCompilerValidationError.unsupportedPackageFile(file)
            }
            hasSources = hasSources || Self.isSwiftSource(relative)
        }
        guard hasSources else {
            throw SwiftRefactoringCompilerValidationError.noSwiftSources
        }
        self.root = root
        self.files = files
    }

    fileprivate static func relativePath(_ file: URL, below root: URL) -> String? {
        let prefix = root.path + "/"
        guard file.path.hasPrefix(prefix) else { return nil }
        return String(file.path.dropFirst(prefix.count))
    }

    fileprivate static func isSwiftSource(_ relative: String) -> Bool {
        relative.hasPrefix("Sources/")
            && relative.hasSuffix(".swift")
            && relative.split(separator: "/").count >= 3
    }
}

public struct SwiftRefactoringCompilerValidation: Sendable {
    public let succeeded: Bool
    public let stdout: String
    public let stderr: String
    /// Diagnostic only; the directory has already been removed on return.
    public let stagedDirectory: URL
}

/// Build a guarded preview in a disposable, source-only SwiftPM package.
/// This is not a security sandbox: SwiftPM manifests and plugins may execute
/// host code. Callers must authorize execution of the supplied package.
public struct SwiftRefactoringCompilerValidator: Sendable {
    public init() {}

    public func validate(
        _ plan: SwiftRefactoringRenamePlan,
        package: SwiftRefactoringCompilerPackage
    ) async throws -> SwiftRefactoringCompilerValidation {
        let preview = try plan.preview(sources: package.files)
        return try await validate(package: package, replacements: preview)
    }

    /// Compile exactly the replacement bytes supplied by a reviewed mutation.
    /// Approval and source freshness remain the responsibility of the caller.
    public func validate(
        package: SwiftRefactoringCompilerPackage,
        replacements: [URL: String]
    ) async throws -> SwiftRefactoringCompilerValidation {
        guard !replacements.isEmpty else {
            throw SwiftRefactoringCompilerValidationError.emptyReplacements
        }
        for file in replacements.keys {
            guard let relative = SwiftRefactoringCompilerPackage.relativePath(
                file, below: package.root
            ), SwiftRefactoringCompilerPackage.isSwiftSource(relative),
                package.files[file] != nil else {
                throw SwiftRefactoringCompilerValidationError.unsupportedRefactoringFile(file)
            }
        }
        var stagedFiles = package.files
        stagedFiles.merge(replacements) { _, revised in revised }

        let stage = FileManager.default.temporaryDirectory
            .appendingPathComponent("swift-refactoring-validate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: stage, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: stage) }

        for (file, contents) in stagedFiles {
            guard let relative = SwiftRefactoringCompilerPackage.relativePath(
                file, below: package.root
            ) else {
                throw SwiftRefactoringCompilerValidationError.unsupportedPackageFile(file)
            }
            let destination = stage.appendingPathComponent(relative)
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data(contents.utf8).write(to: destination, options: .atomic)
        }

        let result = try await ProcessRunner().run(
            .init(
                executable: .path("/usr/bin/swift"),
                arguments: [
                    "build",
                    "--package-path", stage.path,
                    "--scratch-path", stage.appendingPathComponent(".build").path,
                    "-j", "2",
                ],
                environment: .inherited,
                timeout: .seconds(120)
            )
        )
        return SwiftRefactoringCompilerValidation(
            succeeded: result.isSuccess,
            stdout: result.stdoutText,
            stderr: result.stderrText,
            stagedDirectory: stage
        )
    }
}
