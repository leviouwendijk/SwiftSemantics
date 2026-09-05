import Executable

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
