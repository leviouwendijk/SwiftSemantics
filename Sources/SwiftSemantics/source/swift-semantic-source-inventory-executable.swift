import Executable

extension SwiftSemanticSourceInventory {
    init(
        executable inventory: Executable.SwiftPackageSourceInventory
    ) {
        self.init(
            packageName: inventory.packageName,
            targets: inventory.targets.map { target in
                .init(
                    name: target.name,
                    type: target.type,
                    directory: target.directory,
                    sourceFiles: target.sourceFiles
                )
            }
        )
    }
}
