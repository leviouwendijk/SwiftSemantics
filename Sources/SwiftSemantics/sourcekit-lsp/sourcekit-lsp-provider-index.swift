import Foundation

private struct SourceKitLSPIndexSynchronizationParams: Encodable, Sendable {
    let index = true
}

private struct SourceKitLSPVoidResult: Decodable, Sendable {}

extension SourceKitLSPProvider {
    func synchronizeIndex(timeout: Duration) async throws {
        let _: SourceKitLSPVoidResult? = try await transport.requestOptional(
            method: "sourcekit/workspace/synchronize",
            params: SourceKitLSPIndexSynchronizationParams(),
            timeout: timeout
        )
    }
}
