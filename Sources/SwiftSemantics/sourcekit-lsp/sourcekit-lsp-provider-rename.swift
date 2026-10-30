import Foundation

extension SourceKitLSPProvider {
    func rename(
        in file: URL,
        at position: SwiftSemanticPosition,
        to newName: String
    ) async throws -> SwiftSemanticRenameResult {
        guard !newName.isEmpty else {
            throw SwiftSemanticCompilerError.protocolViolation(
                "Compiler rename requires a nonempty replacement name."
            )
        }

        let file = try await synchronizeDocument(file)
        let response: SourceKitLSPRenameWorkspaceEdit? =
            try await transport.requestOptional(
                method: "textDocument/rename",
                params: SourceKitLSPRenameParams(
                    textDocument: .init(uri: file.absoluteString),
                    position: position.lsp,
                    newName: newName
                ),
                timeout: .seconds(60)
            )

        guard let response else {
            throw SwiftSemanticCompilerError.protocolViolation(
                "SourceKit-LSP returned no rename proposal."
            )
        }
        guard !(response.changes != nil && response.documentChanges != nil),
            response.changeAnnotations?.isEmpty != false else {
            throw SwiftSemanticCompilerError.protocolViolation(
                "Rename returned ambiguous edits or unsupported change annotations."
            )
        }

        var documents: [SwiftSemanticRenameDocument] = []
        var seen: Set<URL> = []

        if let changes = response.changes {
            for (uri, edits) in changes.sorted(by: { $0.key < $1.key }) {
                let document = try renameDocument(
                    uri: uri,
                    version: nil,
                    edits: edits
                )
                guard seen.insert(document.uri).inserted else {
                    throw SwiftSemanticCompilerError.protocolViolation(
                        "Rename contains duplicate source documents."
                    )
                }
                documents.append(document)
            }
        } else if let changes = response.documentChanges {
            for change in changes {
                guard change.kind == nil,
                    let textDocument = change.textDocument,
                    let edits = change.edits else {
                    throw SwiftSemanticCompilerError.protocolViolation(
                        "Rename contains unsupported filesystem resource operations."
                    )
                }
                let document = try renameDocument(
                    uri: textDocument.uri,
                    version: textDocument.version,
                    edits: edits
                )
                // documentChanges is ordered. Repeated document URIs must
                // retain their original grouping and version constraints.
                // Compatibility is validated by the later edit planner.
                documents.append(document)
            }
        } else {
            throw SwiftSemanticCompilerError.protocolViolation(
                "Rename response has no supported WorkspaceEdit representation."
            )
        }

        guard documents.contains(where: { !$0.edits.isEmpty }) else {
            throw SwiftSemanticCompilerError.protocolViolation(
                "Rename produced no source edits."
            )
        }

        return SwiftSemanticRenameResult(documents: documents)
    }

    private func renameDocument(
        uri: String,
        version: Int?,
        edits: [SourceKitLSPRenameTextEdit]
    ) throws -> SwiftSemanticRenameDocument {
        guard let file = URL(string: uri), file.isFileURL,
            file.pathExtension == "swift" else {
            throw SwiftSemanticCompilerError.protocolViolation(
                "Rename references a non-file or non-Swift document: \(uri)"
            )
        }
        guard edits.allSatisfy({ $0.annotationId == nil }) else {
            throw SwiftSemanticCompilerError.protocolViolation(
                "Rename contains annotated edits requiring unsupported confirmation."
            )
        }

        return SwiftSemanticRenameDocument(
            uri: file.standardizedFileURL,
            version: version,
            edits: edits.map { edit in
                SwiftSemanticRenameEdit(
                    range: edit.range.semantic,
                    newText: edit.newText
                )
            }
        )
    }
}
