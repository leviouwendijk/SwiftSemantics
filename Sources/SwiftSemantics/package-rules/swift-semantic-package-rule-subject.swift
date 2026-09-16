public enum SwiftSemanticPackageRuleSubject:
    Sendable,
    Codable,
    Hashable
{
    case package(
        identity: String,
        name: String
    )
    case declared_package_dependency(
        identity: String?,
        location: String?
    )
    case product(String)
    case target(String)
    case target_dependency(
        target: String,
        dependency: String,
        package: String?
    )
}
