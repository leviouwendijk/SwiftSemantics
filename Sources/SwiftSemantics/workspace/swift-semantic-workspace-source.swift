import Executable
import Foundation

public extension SwiftSemanticWorkspace {
    /// Return SwiftPM-authoritative target/source membership in semantic types.
    func sourceInventory()
        async throws
        -> SwiftSemanticSourceInventory
    {
        let inventory = try await Executable.Package.sourceInventory(
            at: root
        )

        return SwiftSemanticSourceInventory(
            executable: inventory
        )
    }

    /// Return Swift source files owned directly by root-package products whose
    /// kinds are selected by the caller.
    func swiftSourceFiles(
        forProductKinds kinds: Set<SwiftSemanticPackageGraph.Product.Kind>
    ) async throws -> [URL] {
        let manifest = try await Executable.Package.manifest(
            at: root
        )
        let inventory = try await sourceInventory()
        let selectedKinds = Set(
            kinds.map(\.rawValue)
        )
        let targetNames = Set(
            manifest.products
                .filter { product in
                    selectedKinds.contains(
                        product.kind.rawValue
                    )
                }
                .flatMap(\.targets)
        )
        let files = inventory.targets
            .filter { target in
                targetNames.contains(target.name)
            }
            .flatMap(\.sourceFiles)
            .filter { file in
                file.pathExtension == "swift"
            }

        return Array(Set(files))
            .sorted { lhs, rhs in
                lhs.path < rhs.path
            }
    }

    /// Parse imports only from source files SwiftPM assigns to root-package
    /// targets.
    ///
    /// Non-Swift target sources remain represented by `sourceInventory()` but
    /// are not passed to SwiftParser.
    func importInventory()
        async throws
        -> SwiftSemanticImportInventory
    {
        let inventory = try await sourceInventory()

        let targets = try inventory.targets.map { target in
            let files = try target.sourceFiles
                .filter {
                    $0.pathExtension == "swift"
                }
                .map { file in
                    SwiftSemanticImportInventory.File(
                        url: file,
                        imports: try SwiftImportParser.imports(
                            in: file
                        )
                    )
                }

            return SwiftSemanticImportInventory.Target(
                name: target.name,
                files: files
            )
        }

        return SwiftSemanticImportInventory(
            packageName: inventory.packageName,
            targets: targets
        )
    }
}
