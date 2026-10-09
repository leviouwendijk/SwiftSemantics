import Foundation
import SwiftSemantics

/// Diagnostics-only LSP. SourceKit-LSP remains the owner of Swift language services.
final class SwiftSemanticLintServer {
    private struct Document {
        let uri: String
        var version: Int
        var text: String
    }

    private let transport: LSPTransport
    private let analyzer: SwiftSemanticRuleAnalyzer
    private var documents: [String: Document] = [:]
    private var didShutdown = false
    private var rolesByPath: [String: SwiftSemanticRuleContext.SourceRole] = [:]

    init(
        transport: LSPTransport = .init(),
        ruleSet: SwiftSemanticRuleSet
    ) {
        self.transport = transport
        analyzer = SwiftSemanticRuleAnalyzer(ruleSet: ruleSet)
    }

    func run() async throws {
        while let message = try transport.receive() {
            let method = message["method"] as? String
            let id = message["id"]
            let params = message["params"] as? [String: Any] ?? [:]

            switch method {
            case "initialize":
                await loadSourceRoles(params)
                if let id {
                    try transport.send([
                        "jsonrpc": "2.0", "id": id,
                        "result": [
                            "serverInfo": ["name": "semlsp"],
                            "capabilities": [
                                "positionEncoding": "utf-16",
                                "textDocumentSync": [
                                    "openClose": true,
                                    "change": 1,
                                    "save": ["includeText": false]
                                ]
                            ]
                        ]
                    ])
                }

            case "initialized":
                break

            case "shutdown":
                didShutdown = true
                if let id { try transport.send([
                    "jsonrpc": "2.0", "id": id, "result": NSNull()
                ]) }

            case "exit":
                return

            case "textDocument/didOpen" where !didShutdown:
                guard let document = params["textDocument"] as? [String: Any],
                      let uri = document["uri"] as? String,
                      let version = document["version"] as? Int,
                      let text = document["text"] as? String,
                      Self.fileURL(uri) != nil else { break }
                documents[uri] = Document(uri: uri, version: version, text: text)
                await publish(uri)

            case "textDocument/didChange" where !didShutdown:
                guard let document = params["textDocument"] as? [String: Any],
                      let uri = document["uri"] as? String,
                      let version = document["version"] as? Int,
                      var current = documents[uri],
                      version > current.version,
                      let changes = params["contentChanges"] as? [[String: Any]],
                      let change = changes.last,
                      change["range"] == nil,
                      let text = change["text"] as? String else { break }
                current.text = text
                current.version = version
                documents[uri] = current
                await publish(uri)

            case "textDocument/didSave" where !didShutdown:
                guard let document = params["textDocument"] as? [String: Any],
                      let uri = document["uri"] as? String,
                      documents[uri] != nil else { break }
                await publish(uri)

            case "textDocument/didClose":
                guard let document = params["textDocument"] as? [String: Any],
                      let uri = document["uri"] as? String else { break }
                documents.removeValue(forKey: uri)
                try sendDiagnostics(uri: uri, version: nil, diagnostics: [])

            case nil:
                // Responses from the client require no action in a push-only server.
                break

            default:
                if let id {
                    try transport.send([
                        "jsonrpc": "2.0", "id": id,
                        "error": ["code": -32601, "message": "Method not found"]
                    ])
                }
            }
        }
    }

    private func publish(_ uri: String) async {
        guard let document = documents[uri],
              let file = Self.fileURL(uri) else { return }
        do {
            let source = try SwiftSemanticSource(file: file, source: document.text)
            let context = SwiftSemanticRuleContext(
                sourceRole: rolesByPath[file.path] ?? .unspecified
            )
            let analysis = try await analyzer.analyze(source, context: context)
            let lines = document.text.components(separatedBy: "\n")
            let projected: [[String: Any]] = analysis.diagnostics.compactMap { diagnostic in
                if let origin = diagnostic.file,
                   origin.standardizedFileURL != file.standardizedFileURL {
                    return nil
                }
                let first = max(0, (diagnostic.lineRange?.start ?? 1) - 1)
                let last = max(first, (diagnostic.lineRange?.end ?? first + 1) - 1)
                let limit = max(0, lines.count - 1)
                let start = min(first, limit)
                let end = min(last, limit)
                let endColumn = lines[end].utf16.count

                let severity: Int
                switch diagnostic.severity {
                case .error: severity = 1
                case .warning: severity = 2
                case .information: severity = 3
                case .hint: severity = 4
                }

                return [
                    "range": [
                        "start": ["line": start, "character": 0],
                        "end": ["line": end, "character": endColumn]
                    ],
                    "severity": severity,
                    "source": "SwiftSemantics",
                    "code": diagnostic.ruleID.rawValue,
                    "message": diagnostic.message
                ]
            }
            try sendDiagnostics(
                uri: uri, version: document.version, diagnostics: projected
            )
        } catch {
            // Never leave stale rule diagnostics in the editor on analysis errors.
            let message = "SwiftSemantics analysis error: \(error)"
            FileHandle.standardError.write(Data((message + "\n").utf8))
            try? sendDiagnostics(uri: uri, version: document.version, diagnostics: [])
            try? transport.send([
                "jsonrpc": "2.0", "method": "window/logMessage",
                "params": ["type": 1, "message": message]
            ])
        }
    }

    private func loadSourceRoles(_ params: [String: Any]) async {
        let folders = params["workspaceFolders"] as? [[String: Any]]
        let rootURI = (folders?.first?["uri"] as? String)
            ?? (params["rootUri"] as? String)
        guard let rootURI, let root = URL(string: rootURI),
              root.isFileURL else { return }
        do {
            let inventory = try await SwiftSemanticWorkspace(root: root)
                .sourceInventory()
            for target in inventory.targets {
                let role: SwiftSemanticRuleContext.SourceRole
                switch target.type.lowercased() {
                case "test": role = .test
                case "executable": role = .executable
                case "regular": role = .library
                default: role = .unspecified
                }
                for file in target.sourceFiles where file.pathExtension == "swift" {
                    rolesByPath[file.standardizedFileURL.path] = role
                }
            }
        } catch {
            // A single-file workspace or unavailable SwiftPM is not fatal.
            FileHandle.standardError.write(
                Data("semlsp: source inventory unavailable: \(error)\n".utf8)
            )
        }
    }

    private func sendDiagnostics(
        uri: String,
        version: Int?,
        diagnostics: [[String: Any]]
    ) throws {
        var params: [String: Any] = ["uri": uri, "diagnostics": diagnostics]
        if let version { params["version"] = version }
        try transport.send([
            "jsonrpc": "2.0",
            "method": "textDocument/publishDiagnostics",
            "params": params
        ])
    }

    private static func fileURL(_ uri: String) -> URL? {
        guard let url = URL(string: uri),
              url.isFileURL,
              url.pathExtension == "swift" else { return nil }
        return url.standardizedFileURL
    }
}
