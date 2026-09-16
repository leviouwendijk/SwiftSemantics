public struct SwiftSemanticForbiddenTargetDependency:
    Sendable,
    Codable,
    Hashable
{
    public let sourceTarget: String
    public let dependencyName: String
    public let dependencyPackage: String?

    public init(
        sourceTarget: String,
        dependencyName: String,
        dependencyPackage: String? = nil
    ) {
        self.sourceTarget = sourceTarget
        self.dependencyName = dependencyName
        self.dependencyPackage = dependencyPackage
    }
}
