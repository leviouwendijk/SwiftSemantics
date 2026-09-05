import Foundation

extension SourceKitLSPProvider {
    func symbolInfo(
        in file: URL,
        at position: SwiftSemanticPosition
    ) async throws -> [SwiftSemanticCompilerSymbol] {
        let file = try await synchronizeDocument(
            file
        )

        let values: [SourceKitLSPSymbolDetails]? =
            try await transport.requestOptional(
                method: "textDocument/symbolInfo",
                params: SourceKitLSPTextDocumentPositionParams(
                    textDocument: .init(
                        uri: file.absoluteString
                    ),
                    position: position.lsp
                )
            )

        return try (values ?? []).map { value in
            let declaration = try value.bestLocalDeclaration.map {
                try semanticLocation($0)
            }

            return SwiftSemanticCompilerSymbol(
                name: value.name,
                containerName: value.containerName,
                identifier: value.usr,
                kind: value.kind.map { $0.semantic },
                bestLocalDeclaration: declaration,
                isDynamic: value.isDynamic,
                isSystem: value.isSystem,
                receiverIdentifiers: value.receiverUsrs ?? [],
                systemModuleName: value.systemModule?.moduleName,
                systemModuleGroupName: value.systemModule?.groupName
            )
        }
    }

    func hover(
        in file: URL,
        at position: SwiftSemanticPosition
    ) async throws -> SwiftSemanticHover? {
        let file = try await synchronizeDocument(
            file
        )

        let value: SourceKitLSPHover? =
            try await transport.requestOptional(
                method: "textDocument/hover",
                params: SourceKitLSPTextDocumentPositionParams(
                    textDocument: .init(
                        uri: file.absoluteString
                    ),
                    position: position.lsp
                )
            )

        guard let value else {
            return nil
        }

        let format: SwiftSemanticHoverFormat

        switch value.contents.kind {
        case "markdown":
            format = .markdown

        case "plaintext":
            format = .plaintext

        default:
            format = .unknown
        }

        return .init(
            contents: value.contents.text,
            format: format,
            range: value.range?.semantic
        )
    }

    func documentSymbols(
        for file: URL
    ) async throws -> [SwiftSemanticDocumentSymbol] {
        let file = try await synchronizeDocument(
            file
        )

        let result: SourceKitLSPDocumentSymbolResult? =
            try await transport.requestOptional(
                method: "textDocument/documentSymbol",
                params: SourceKitLSPDocumentSymbolParams(
                    textDocument: .init(
                        uri: file.absoluteString
                    )
                )
            )

        return try (result?.entries ?? []).map { entry in
            switch entry {
            case .document(let value):
                return try semanticDocumentSymbol(
                    value,
                    document: file
                )

            case .information(let value):
                let location = try semanticLocation(
                    value.location
                )

                return .init(
                    name: value.name,
                    kind: value.kind.semantic,
                    location: location,
                    selectionRange: location.range
                )
            }
        }
    }

    func incomingCalls(
        in file: URL,
        at position: SwiftSemanticPosition
    ) async throws -> [SwiftSemanticIncomingCall] {
        guard let item = try await preparedCallHierarchyItem(
            in: file,
            at: position
        ) else {
            return []
        }

        let values: [SourceKitLSPIncomingCall]? =
            try await transport.requestOptional(
                method: "callHierarchy/incomingCalls",
                params: SourceKitLSPCallHierarchyIncomingParams(
                    item: item
                ),
                timeout: .seconds(
                    60
                )
            )

        return try (values ?? []).map { value in
            .init(
                caller: try semanticCallHierarchyItem(
                    value.from
                ),
                callRanges: value.fromRanges.map(\.semantic)
            )
        }
    }

    func outgoingCalls(
        in file: URL,
        at position: SwiftSemanticPosition
    ) async throws -> [SwiftSemanticOutgoingCall] {
        guard let item = try await preparedCallHierarchyItem(
            in: file,
            at: position
        ) else {
            return []
        }

        let values: [SourceKitLSPOutgoingCall]? =
            try await transport.requestOptional(
                method: "callHierarchy/outgoingCalls",
                params: SourceKitLSPCallHierarchyOutgoingParams(
                    item: item
                ),
                timeout: .seconds(
                    60
                )
            )

        return try (values ?? []).map { value in
            .init(
                callee: try semanticCallHierarchyItem(
                    value.to
                ),
                callRanges: value.fromRanges.map(\.semantic)
            )
        }
    }

    func supertypes(
        in file: URL,
        at position: SwiftSemanticPosition
    ) async throws -> [SwiftSemanticTypeHierarchyItem] {
        guard let item = try await preparedTypeHierarchyItem(
            in: file,
            at: position
        ) else {
            return []
        }

        let values: [SourceKitLSPTypeHierarchyItem]? =
            try await transport.requestOptional(
                method: "typeHierarchy/supertypes",
                params: SourceKitLSPTypeHierarchyParams(
                    item: item
                ),
                timeout: .seconds(
                    60
                )
            )

        return try (values ?? []).map(
            semanticTypeHierarchyItem
        )
    }

    func subtypes(
        in file: URL,
        at position: SwiftSemanticPosition
    ) async throws -> [SwiftSemanticTypeHierarchyItem] {
        guard let item = try await preparedTypeHierarchyItem(
            in: file,
            at: position
        ) else {
            return []
        }

        let values: [SourceKitLSPTypeHierarchyItem]? =
            try await transport.requestOptional(
                method: "typeHierarchy/subtypes",
                params: SourceKitLSPTypeHierarchyParams(
                    item: item
                ),
                timeout: .seconds(
                    60
                )
            )

        return try (values ?? []).map(
            semanticTypeHierarchyItem
        )
    }
}

private extension SourceKitLSPProvider {
    func preparedCallHierarchyItem(
        in file: URL,
        at position: SwiftSemanticPosition
    ) async throws -> SourceKitLSPCallHierarchyItem? {
        let file = try await synchronizeDocument(
            file
        )

        let values: [SourceKitLSPCallHierarchyItem]? =
            try await transport.requestOptional(
                method: "textDocument/prepareCallHierarchy",
                params: SourceKitLSPTextDocumentPositionParams(
                    textDocument: .init(
                        uri: file.absoluteString
                    ),
                    position: position.lsp
                ),
                timeout: .seconds(
                    60
                )
            )

        return values?.first
    }

    func preparedTypeHierarchyItem(
        in file: URL,
        at position: SwiftSemanticPosition
    ) async throws -> SourceKitLSPTypeHierarchyItem? {
        let file = try await synchronizeDocument(
            file
        )

        let values: [SourceKitLSPTypeHierarchyItem]? =
            try await transport.requestOptional(
                method: "textDocument/prepareTypeHierarchy",
                params: SourceKitLSPTextDocumentPositionParams(
                    textDocument: .init(
                        uri: file.absoluteString
                    ),
                    position: position.lsp
                ),
                timeout: .seconds(
                    60
                )
            )

        return values?.first
    }

    func semanticDocumentSymbol(
        _ value: SourceKitLSPDocumentSymbol,
        document: URL
    ) throws -> SwiftSemanticDocumentSymbol {
        let location = SwiftSemanticLocation(
            uri: document,
            range: value.range.semantic
        )

        return .init(
            name: value.name,
            detail: value.detail,
            kind: value.kind.semantic,
            location: location,
            selectionRange: value.selectionRange.semantic,
            children: try (value.children ?? []).map {
                try semanticDocumentSymbol(
                    $0,
                    document: document
                )
            }
        )
    }

    func semanticCallHierarchyItem(
        _ value: SourceKitLSPCallHierarchyItem
    ) throws -> SwiftSemanticCallHierarchyItem {
        .init(
            name: value.name,
            detail: value.detail,
            kind: value.kind.semantic,
            location: .init(
                uri: try semanticURI(
                    value.uri
                ),
                range: value.range.semantic
            ),
            selectionRange: value.selectionRange.semantic
        )
    }

    func semanticTypeHierarchyItem(
        _ value: SourceKitLSPTypeHierarchyItem
    ) throws -> SwiftSemanticTypeHierarchyItem {
        .init(
            name: value.name,
            detail: value.detail,
            kind: value.kind.semantic,
            location: .init(
                uri: try semanticURI(
                    value.uri
                ),
                range: value.range.semantic
            ),
            selectionRange: value.selectionRange.semantic
        )
    }

    func semanticURI(
        _ value: String
    ) throws -> URL {
        guard let uri = URL(
            string: value
        ) else {
            throw SwiftSemanticCompilerError.protocolViolation(
                "SourceKit-LSP returned an invalid semantic URI: "
                    + value
            )
        }

        return uri
    }
}
