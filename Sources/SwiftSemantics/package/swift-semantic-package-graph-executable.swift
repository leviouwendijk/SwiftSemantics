import Executable

extension SwiftSemanticPackageGraph {
    init(
        executable graph: Executable.SwiftPackageGraph
    ) {
        let manifest = graph.manifest

        self.init(
            rootIdentity: graph.rootIdentity,
            rootName: manifest.name,
            toolsVersion: manifest.toolsVersion,
            platforms: manifest.platforms.map { platform in
                .init(
                    name: platform.name,
                    version: platform.version
                )
            },
            packages: graph.packages.map { package in
                .init(
                    identity: package.identity,
                    name: package.name,
                    location: package.location,
                    version: package.version,
                    path: package.path
                )
            },
            packageDependencies: graph.edges.map { edge in
                .init(
                    sourceIdentity: edge.sourceIdentity,
                    targetIdentity: edge.targetIdentity
                )
            },
            declaredPackageDependencies: manifest.dependencies.map { dependency in
                .init(
                    kind:
                        DeclaredPackageDependency.Kind(
                            rawValue: dependency.kind.rawValue
                        )
                        ?? .other,
                    identity: dependency.identity,
                    location: dependency.location
                )
            },
            products: manifest.products.map { product in
                .init(
                    name: product.name,
                    kind:
                        Product.Kind(
                            rawValue: product.kind.rawValue
                        )
                        ?? .other,
                    targets: product.targets
                )
            },
            targets: manifest.targets.map { target in
                .init(
                    name: target.name,
                    type: target.type,
                    path: target.path,
                    dependencies: target.dependencies.map { dependency in
                        .init(
                            kind:
                                Target.Dependency.Kind(
                                    rawValue: dependency.kind.rawValue
                                )
                                ?? .other,
                            name: dependency.name,
                            package: dependency.package
                        )
                    }
                )
            }
        )
    }
}
