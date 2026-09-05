public struct SwiftSemanticPackageGraph:
    Sendable,
    Hashable
{
    public struct Platform:
        Sendable,
        Hashable
    {
        public let name: String
        public let version: String

        public init(
            name: String,
            version: String
        ) {
            self.name = name
            self.version = version
        }
    }

    public struct Package:
        Sendable,
        Hashable
    {
        public let identity: String
        public let name: String
        public let location: String?
        public let version: String?
        public let path: String?

        public init(
            identity: String,
            name: String,
            location: String? = nil,
            version: String? = nil,
            path: String? = nil
        ) {
            self.identity = identity
            self.name = name
            self.location = location
            self.version = version
            self.path = path
        }
    }

    public struct PackageDependency:
        Sendable,
        Hashable
    {
        public let sourceIdentity: String
        public let targetIdentity: String

        public init(
            sourceIdentity: String,
            targetIdentity: String
        ) {
            self.sourceIdentity = sourceIdentity
            self.targetIdentity = targetIdentity
        }
    }

    public struct DeclaredPackageDependency:
        Sendable,
        Hashable
    {
        public enum Kind:
            String,
            Sendable,
            Hashable
        {
            case sourceControl
            case fileSystem
            case registry
            case other
        }

        public let kind: Kind
        public let identity: String?
        public let location: String?

        public init(
            kind: Kind,
            identity: String? = nil,
            location: String? = nil
        ) {
            self.kind = kind
            self.identity = identity
            self.location = location
        }
    }

    public struct Product:
        Sendable,
        Hashable
    {
        public enum Kind:
            String,
            Sendable,
            Hashable
        {
            case executable
            case library
            case plugin
            case snippet
            case test
            case `macro`
            case other
        }

        public let name: String
        public let kind: Kind
        public let targets: [String]

        public init(
            name: String,
            kind: Kind,
            targets: [String]
        ) {
            self.name = name
            self.kind = kind
            self.targets = targets
        }
    }

    public struct Target:
        Sendable,
        Hashable
    {
        public struct Dependency:
            Sendable,
            Hashable
        {
            public enum Kind:
                String,
                Sendable,
                Hashable
            {
                case target
                case product
                case byName
                case other
            }

            public let kind: Kind
            public let name: String
            public let package: String?

            public init(
                kind: Kind,
                name: String,
                package: String? = nil
            ) {
                self.kind = kind
                self.name = name
                self.package = package
            }
        }

        public let name: String
        public let type: String
        public let path: String?
        public let dependencies: [Dependency]

        public init(
            name: String,
            type: String,
            path: String? = nil,
            dependencies: [Dependency] = []
        ) {
            self.name = name
            self.type = type
            self.path = path
            self.dependencies = dependencies
        }
    }

    public let rootIdentity: String
    public let rootName: String
    public let toolsVersion: String?
    public let platforms: [Platform]
    public let packages: [Package]
    public let packageDependencies: [PackageDependency]
    public let declaredPackageDependencies: [DeclaredPackageDependency]
    public let products: [Product]
    public let targets: [Target]

    public init(
        rootIdentity: String,
        rootName: String,
        toolsVersion: String? = nil,
        platforms: [Platform] = [],
        packages: [Package],
        packageDependencies: [PackageDependency],
        declaredPackageDependencies: [DeclaredPackageDependency] = [],
        products: [Product],
        targets: [Target]
    ) {
        self.rootIdentity = rootIdentity
        self.rootName = rootName
        self.toolsVersion = toolsVersion
        self.platforms = platforms
        self.packages = packages.sorted {
            packageKey($0) < packageKey($1)
        }
        self.packageDependencies = packageDependencies.sorted {
            dependencyKey($0) < dependencyKey($1)
        }
        self.declaredPackageDependencies = declaredPackageDependencies
        self.products = products
        self.targets = targets
    }

    public var rootPackage: Package? {
        package(
            identifiedBy: rootIdentity
        )
    }

    public func package(
        identifiedBy identity: String
    ) -> Package? {
        packages.first {
            $0.identity == identity
        }
    }

    public func packageDependencies(
        from identity: String
    ) -> [PackageDependency] {
        packageDependencies.filter {
            $0.sourceIdentity == identity
        }
    }

    public func product(
        named name: String
    ) -> Product? {
        products.first {
            $0.name == name
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

private func packageKey(
    _ package: SwiftSemanticPackageGraph.Package
) -> String {
    [
        package.identity,
        package.name,
        package.location ?? "",
        package.version ?? "",
        package.path ?? "",
    ]
        .joined(
            separator: "\u{1F}"
        )
}

private func dependencyKey(
    _ dependency: SwiftSemanticPackageGraph.PackageDependency
) -> String {
    dependency.sourceIdentity
        + "\u{1F}"
        + dependency.targetIdentity
}
