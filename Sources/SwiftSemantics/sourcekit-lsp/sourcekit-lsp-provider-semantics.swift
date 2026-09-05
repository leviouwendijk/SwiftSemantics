import Foundation

extension SourceKitLSPProvider {
    func definition(
        in file: URL,
        at position: SwiftSemanticPosition
    ) async throws -> [SwiftSemanticLocation] {
        let file = try await synchronizeDocument(
            file
        )

        let result: SourceKitLSPLocationResult? =
            try await transport.requestOptional(
                method: "textDocument/definition",
                params: SourceKitLSPTextDocumentPositionParams(
                    textDocument: .init(
                        uri: file.absoluteString
                    ),
                    position: position.lsp
                )
            )

        return try result?.locations.map(
            semanticLocation
        ) ?? []
    }

    func references(
        in file: URL,
        at position: SwiftSemanticPosition,
        includeDeclaration: Bool
    ) async throws -> [SwiftSemanticLocation] {
        let file = try await synchronizeDocument(
            file
        )

        let result: [SourceKitLSPLocation]? =
            try await transport.requestOptional(
                method: "textDocument/references",
                params: SourceKitLSPReferencesParams(
                    textDocument: .init(
                        uri: file.absoluteString
                    ),
                    position: position.lsp,
                    context: .init(
                        includeDeclaration: includeDeclaration
                    )
                )
            )

        return try result?.map(
            semanticLocation
        ) ?? []
    }

    func implementations(
        in file: URL,
        at position: SwiftSemanticPosition
    ) async throws -> [SwiftSemanticLocation] {
        let file = try await synchronizeDocument(
            file
        )

        let result: SourceKitLSPLocationResult? =
            try await transport.requestOptional(
                method: "textDocument/implementation",
                params: SourceKitLSPTextDocumentPositionParams(
                    textDocument: .init(
                        uri: file.absoluteString
                    ),
                    position: position.lsp
                )
            )

        return try result?.locations.map(
            semanticLocation
        ) ?? []
    }

    func diagnostics(
        for file: URL
    ) async throws -> [SwiftSemanticDiagnostic] {
        let file = try await synchronizeDocument(
            file
        )

        let report: SourceKitLSPDocumentDiagnosticReport =
            try await transport.request(
                method: "textDocument/diagnostic",
                params: SourceKitLSPDocumentDiagnosticParams(
                    textDocument: .init(
                        uri: file.absoluteString
                    )
                ),
                timeout: .seconds(
                    60
                )
            )

        return (report.items ?? []).map { diagnostic in
            SwiftSemanticDiagnostic(
                uri: file,
                range: diagnostic.range.semantic,
                severity: diagnostic.severity.semantic,
                message: diagnostic.message,
                source: diagnostic.source
            )
        }
    }

    func workspaceSymbols(
        matching query: String
    ) async throws -> [SwiftSemanticWorkspaceSymbol] {
        let items: [SourceKitLSPWorkspaceSymbolItem]? =
            try await transport.requestOptional(
                method: "workspace/symbol",
                params: SourceKitLSPWorkspaceSymbolParams(
                    query: query
                ),
                timeout: .seconds(
                    60
                )
            )

        return try (items ?? []).map { item in
            let location: SwiftSemanticLocation?

            switch item.location {
            case .full(let value):
                location = try semanticLocation(
                    value
                )

            case .uri:
                location = nil
            }

            return SwiftSemanticWorkspaceSymbol(
                name: item.name,
                kind: item.kind.semantic,
                containerName: item.containerName,
                location: location
            )
        }
    }
}

private extension SourceKitLSPProvider {
    func synchronizeDocument(
        _ file: URL
    ) async throws -> URL {
        let file = file.standardizedFileURL

        guard file.isFileURL else {
            throw SwiftSemanticCompilerError.protocolViolation(
                "Compiler-semantic source queries require a file URL."
            )
        }

        let text: String

        do {
            text = try String(
                contentsOf: file,
                encoding: .utf8
            )
        } catch {
            throw SwiftSemanticCompilerError.transportFailed(
                "Could not read semantic source file \(file.path): \(error)"
            )
        }

        if let current = openedDocuments[file] {
            guard current.text != text else {
                return file
            }

            let version = current.version + 1

            try await transport.notify(
                method: "textDocument/didChange",
                params: SourceKitLSPDidChangeParams(
                    textDocument: .init(
                        uri: file.absoluteString,
                        version: version
                    ),
                    contentChanges: [
                        .init(
                            text: text
                        ),
                    ]
                )
            )

            openedDocuments[file] = .init(
                version: version,
                text: text
            )

            return file
        }

        try await transport.notify(
            method: "textDocument/didOpen",
            params: SourceKitLSPDidOpenParams(
                textDocument: .init(
                    uri: file.absoluteString,
                    languageId: "swift",
                    version: 1,
                    text: text
                )
            )
        )

        openedDocuments[file] = .init(
            version: 1,
            text: text
        )

        return file
    }

    func semanticLocation(
        _ value: SourceKitLSPLocation
    ) throws -> SwiftSemanticLocation {
        guard let uri = URL(
            string: value.uri
        ) else {
            throw SwiftSemanticCompilerError.protocolViolation(
                "SourceKit-LSP returned an invalid URI: \(value.uri)"
            )
        }

        return .init(
            uri: uri,
            range: value.range.semantic
        )
    }
}

private extension SwiftSemanticPosition {
    var lsp: SourceKitLSPPosition {
        .init(
            line: max(
                0,
                line - 1
            ),
            character: max(
                0,
                utf16Column - 1
            )
        )
    }
}

private extension SourceKitLSPRange {
    var semantic: SwiftSemanticRange {
        .init(
            start: start.semantic,
            end: end.semantic
        )
    }
}

private extension SourceKitLSPPosition {
    var semantic: SwiftSemanticPosition {
        .init(
            line: line + 1,
            utf16Column: character + 1
        )
    }
}

private extension Optional where Wrapped == Int {
    var semantic: SwiftSemanticDiagnosticSeverity {
        switch self {
        case 1:
            return .error

        case 2:
            return .warning

        case 3:
            return .information

        case 4:
            return .hint

        default:
            return .unspecified
        }
    }
}

private extension Int {
    var semantic: SwiftSemanticWorkspaceSymbolKind {
        switch self {
        case 1:
            return .file
        case 2:
            return .module
        case 3:
            return .namespace
        case 4:
            return .package
        case 5:
            return .class
        case 6:
            return .method
        case 7:
            return .property
        case 8:
            return .field
        case 9:
            return .constructor
        case 10:
            return .enumCase
        case 11:
            return .interface
        case 12:
            return .function
        case 13:
            return .variable
        case 14:
            return .constant
        case 15:
            return .string
        case 16:
            return .number
        case 17:
            return .boolean
        case 18:
            return .array
        case 19:
            return .object
        case 20:
            return .key
        case 21:
            return .null
        case 22:
            return .enumType
        case 23:
            return .struct
        case 24:
            return .event
        case 25:
            return .operator
        case 26:
            return .typeParameter
        default:
            return .unknown
        }
    }
}
