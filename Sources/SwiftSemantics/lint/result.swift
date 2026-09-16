import Foundation

public extension SwiftSemanticLint {
    struct Result:
        Sendable,
        Codable,
        Hashable
    {
        public struct Summary:
            Sendable,
            Codable,
            Hashable
        {
            public let files: Int
            public let diagnostics: Int
            public let errors: Int
            public let warnings: Int
            public let information: Int
            public let hints: Int

            public init(
                files: Int,
                diagnostics: Int,
                errors: Int,
                warnings: Int,
                information: Int,
                hints: Int
            ) {
                self.files = files
                self.diagnostics = diagnostics
                self.errors = errors
                self.warnings = warnings
                self.information = information
                self.hints = hints
            }
        }

        public let files: [URL]
        public let diagnostics: [SwiftSemanticRuleDiagnostic]

        public init(
            files: [URL],
            diagnostics: [SwiftSemanticRuleDiagnostic]
        ) {
            self.files = files.map(\.standardizedFileURL)
            self.diagnostics = diagnostics
        }

        public var summary: Summary {
            .init(
                files: files.count,
                diagnostics: diagnostics.count,
                errors: count(.error),
                warnings: count(.warning),
                information: count(.information),
                hints: count(.hint)
            )
        }

        public var hasErrors: Bool {
            summary.errors > 0
        }

        private func count(
            _ severity: SwiftSemanticRuleSeverity
        ) -> Int {
            diagnostics.count { diagnostic in
                diagnostic.severity == severity
            }
        }
    }
}
