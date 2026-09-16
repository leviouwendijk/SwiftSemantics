import Foundation
import PackagePlugin

@main
struct SwiftSemanticRuleCatalogPlugin:
    BuildToolPlugin
{
    func createBuildCommands(
        context: PluginContext,
        target: Target
    ) async throws -> [Command] {
        guard let sourceTarget = target as? SourceModuleTarget else {
            return []
        }

        let generator = try context.tool(
            named: "SwiftSemanticRuleCatalogGenerator"
        )

        let output = context.pluginWorkDirectoryURL
            .appending(
                path: "swift-semantic-rule-catalog.generated.swift"
            )

        let rulesDirectory = sourceTarget.directoryURL
            .appending(
                path: "rules"
            )

        let sourceFiles = sourceTarget
            .sourceFiles(
                withSuffix: "swift"
            )
            .map(\.url)

        return [
            .buildCommand(
                displayName:
                    "Generate SwiftSemanticRuleSet.all",
                executable: generator.url,
                arguments: [
                    rulesDirectory.path,
                    output.path,
                ],
                inputFiles: sourceFiles,
                outputFiles: [
                    output,
                ]
            ),
        ]
    }
}
