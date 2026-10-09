import Foundation
import SwiftSemantics

@main
enum SwiftSemanticLintLSPMain {
    static func main() async {
        do {
            let server = try SwiftSemanticLintServer(
                ruleSet: SwiftSemanticRuleSet.all
            )
            try await server.run()
        } catch {
            FileHandle.standardError.write(
                Data("semlsp: \(error)\n".utf8)
            )
            exit(EXIT_FAILURE)
        }
    }
}
