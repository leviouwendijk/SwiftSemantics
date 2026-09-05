import Foundation
import Processes

/// Persistent JSON-RPC/LSP transport over one ProcessSession.
///
/// Only this actor consumes ProcessSession.events. It reconstructs framed
/// stdout messages, routes responses to pending requests, records a bounded
/// stderr tail for diagnostics, and keeps raw LSP protocol mechanics below the
/// public SwiftSemantics surface.
actor SourceKitLSPTransport {
    private static let maximumStderrTailBytes =
        64 * 1024

    private let session: ProcessSession

    private var nextRequestID = 1
    private var pending: [
        SourceKitLSPMessageID:
            AsyncThrowingStream<Data, any Error>.Continuation
    ] = [:]

    private var readerTask:
        Task<Void, Never>?

    private var stderrTail = Data()
    private var processExit: ProcessExit?

    private init(
        session: ProcessSession
    ) {
        self.session = session
    }

    static func start(
        session: ProcessSession
    ) async -> SourceKitLSPTransport {
        let transport = SourceKitLSPTransport(
            session: session
        )

        await transport.startReader()

        return transport
    }

    func request<Params, Result>(
        method: String,
        params: Params,
        timeout: Duration = .seconds(
            30
        )
    ) async throws -> Result
    where
        Params: Encodable & Sendable,
        Result: Decodable & Sendable
    {
        let id = allocateRequestID()

        let body: Data

        do {
            body = try JSONEncoder().encode(
                SourceKitLSPRequest(
                    id: id,
                    method: method,
                    params: params
                )
            )
        } catch {
            throw SwiftSemanticCompilerError.protocolViolation(
                "Could not encode request '\(method)': \(error)"
            )
        }

        let responseBody = try await awaitResponse(
            id: id,
            method: method,
            body: body,
            timeout: timeout
        )

        let response: SourceKitLSPResponse<Result>

        do {
            response = try JSONDecoder().decode(
                SourceKitLSPResponse<Result>.self,
                from: responseBody
            )
        } catch {
            throw SwiftSemanticCompilerError.protocolViolation(
                "Could not decode response for '\(method)': \(error)"
            )
        }

        if let error = response.error {
            throw SwiftSemanticCompilerError.requestFailed(
                code: error.code,
                message: error.message
            )
        }

        guard let result = response.result else {
            throw SwiftSemanticCompilerError.protocolViolation(
                "Response for '\(method)' did not contain a result."
            )
        }

        return result
    }

    /// Send a request whose successful LSP result may legally be null.
    func requestOptional<Params, Result>(
        method: String,
        params: Params,
        timeout: Duration = .seconds(
            30
        )
    ) async throws -> Result?
    where
        Params: Encodable & Sendable,
        Result: Decodable & Sendable
    {
        let id = allocateRequestID()

        let body: Data

        do {
            body = try JSONEncoder().encode(
                SourceKitLSPRequest(
                    id: id,
                    method: method,
                    params: params
                )
            )
        } catch {
            throw SwiftSemanticCompilerError.protocolViolation(
                "Could not encode request '\(method)': \(error)"
            )
        }

        let responseBody = try await awaitResponse(
            id: id,
            method: method,
            body: body,
            timeout: timeout
        )

        let response: SourceKitLSPResponse<Result>

        do {
            response = try JSONDecoder().decode(
                SourceKitLSPResponse<Result>.self,
                from: responseBody
            )
        } catch {
            throw SwiftSemanticCompilerError.protocolViolation(
                "Could not decode response for '\(method)': \(error)"
            )
        }

        if let error = response.error {
            throw SwiftSemanticCompilerError.requestFailed(
                code: error.code,
                message: error.message
            )
        }

        return response.result
    }

    func requestWithoutResult(
        method: String,
        timeout: Duration = .seconds(
            30
        )
    ) async throws {
        let id = allocateRequestID()

        let body: Data

        do {
            body = try JSONEncoder().encode(
                SourceKitLSPRequestWithoutParams(
                    id: id,
                    method: method
                )
            )
        } catch {
            throw SwiftSemanticCompilerError.protocolViolation(
                "Could not encode request '\(method)': \(error)"
            )
        }

        let responseBody = try await awaitResponse(
            id: id,
            method: method,
            body: body,
            timeout: timeout
        )

        let response: SourceKitLSPResponseStatus

        do {
            response = try JSONDecoder().decode(
                SourceKitLSPResponseStatus.self,
                from: responseBody
            )
        } catch {
            throw SwiftSemanticCompilerError.protocolViolation(
                "Could not decode response for '\(method)': \(error)"
            )
        }

        if let error = response.error {
            throw SwiftSemanticCompilerError.requestFailed(
                code: error.code,
                message: error.message
            )
        }
    }

    func notify<Params>(
        method: String,
        params: Params
    ) async throws
    where Params: Encodable & Sendable
    {
        let body: Data

        do {
            body = try JSONEncoder().encode(
                SourceKitLSPNotification(
                    method: method,
                    params: params
                )
            )
        } catch {
            throw SwiftSemanticCompilerError.protocolViolation(
                "Could not encode notification '\(method)': \(error)"
            )
        }

        try await writeBody(
            body
        )
    }

    func notify(
        method: String
    ) async throws {
        let body: Data

        do {
            body = try JSONEncoder().encode(
                SourceKitLSPNotificationWithoutParams(
                    method: method
                )
            )
        } catch {
            throw SwiftSemanticCompilerError.protocolViolation(
                "Could not encode notification '\(method)': \(error)"
            )
        }

        try await writeBody(
            body
        )
    }

    func finishInput() async throws {
        do {
            try await session.finishInput()
        } catch {
            throw SwiftSemanticCompilerError.transportFailed(
                String(
                    describing: error
                )
            )
        }
    }

    func wait() async throws -> ProcessExit {
        do {
            return try await session.wait()
        } catch {
            throw SwiftSemanticCompilerError.transportFailed(
                String(
                    describing: error
                )
            )
        }
    }

    func terminate() async {
        await session.terminate()
        _ = try? await session.wait()
        readerTask?.cancel()

        failAll(
            SwiftSemanticCompilerError.connectionClosed
        )
    }
}

private extension SourceKitLSPTransport {
    func startReader() {
        guard readerTask == nil else {
            return
        }

        let events = session.events

        readerTask = Task.detached { [weak self, events] in
            var framer = SourceKitLSPMessageFramer()

            do {
                for try await event in events {
                    guard let self else {
                        return
                    }

                    switch event {
                    case .stdout(let chunk):
                        let messages = try framer.append(
                            chunk
                        )

                        for message in messages {
                            try await self.receive(
                                message
                            )
                        }

                    case .stderr(let chunk):
                        await self.recordStderr(
                            chunk
                        )

                    case .exited(let exit):
                        await self.recordExit(
                            exit
                        )
                    }
                }
            } catch is CancellationError {
                return
            } catch {
                guard let self else {
                    return
                }

                await self.failAndTerminate(
                    error
                )
            }
        }
    }

    func allocateRequestID() -> SourceKitLSPMessageID {
        let id = nextRequestID
        nextRequestID &+= 1

        return .integer(
            id
        )
    }

    func awaitResponse(
        id: SourceKitLSPMessageID,
        method: String,
        body: Data,
        timeout: Duration
    ) async throws -> Data {
        if let processExit {
            throw providerExitError(
                processExit
            )
        }

        let response = AsyncThrowingStream<
            Data,
            any Error
        >
        .makeStream(
            bufferingPolicy: .bufferingNewest(
                1
            )
        )

        pending[id] = response.continuation

        do {
            try await writeBody(
                body
            )
        } catch {
            pending.removeValue(
                forKey: id
            )
            response.continuation.finish(
                throwing: error
            )
            throw error
        }

        let timeoutTask = Task { [weak self] in
            do {
                try await Task.sleep(
                    for: timeout
                )
            } catch {
                return
            }

            guard !Task.isCancelled else {
                return
            }

            await self?.timeoutRequest(
                id: id,
                method: method
            )
        }

        defer {
            timeoutTask.cancel()

            if let continuation = pending.removeValue(
                forKey: id
            ) {
                continuation.finish()
            }
        }

        return try await withTaskCancellationHandler {
            var iterator = response.stream.makeAsyncIterator()

            guard let data = try await iterator.next() else {
                throw SwiftSemanticCompilerError.connectionClosed
            }

            return data
        } onCancel: {
            Task { [weak self] in
                await self?.cancelRequest(
                    id: id
                )
            }
        }
    }

    func writeBody(
        _ body: Data
    ) async throws {
        do {
            try await session.write(
                SourceKitLSPMessageWriter.frame(
                    body
                )
            )
        } catch {
            throw SwiftSemanticCompilerError.transportFailed(
                String(
                    describing: error
                )
            )
        }
    }

    func receive(
        _ body: Data
    ) async throws {
        let envelope: SourceKitLSPIncomingEnvelope

        do {
            envelope = try JSONDecoder().decode(
                SourceKitLSPIncomingEnvelope.self,
                from: body
            )
        } catch {
            throw SwiftSemanticCompilerError.protocolViolation(
                "Could not decode incoming JSON-RPC envelope: \(error)"
            )
        }

        if let method = envelope.method {
            if let id = envelope.id {
                switch method {
                case "workspace/diagnostic/refresh":
                    try await acknowledgeServerRequest(
                        id: id
                    )

                default:
                    try await rejectServerRequest(
                        id: id,
                        method: method
                    )
                }
            }

            return
        }

        guard let id = envelope.id else {
            return
        }

        guard let continuation = pending.removeValue(
            forKey: id
        ) else {
            return
        }

        continuation.yield(
            body
        )
        continuation.finish()
    }

    func acknowledgeServerRequest(
        id: SourceKitLSPMessageID
    ) async throws {
        let body: Data

        do {
            body = try JSONEncoder().encode(
                SourceKitLSPServerNullResponse(
                    id: id
                )
            )
        } catch {
            throw SwiftSemanticCompilerError.protocolViolation(
                "Could not encode JSON-RPC server-request acknowledgement: \(error)"
            )
        }

        try await writeBody(
            body
        )
    }

    func rejectServerRequest(
        id: SourceKitLSPMessageID,
        method: String
    ) async throws {
        let response = SourceKitLSPServerErrorResponse(
            id: id,
            error: .init(
                code: -32601,
                message: "SwiftSemantics does not implement server request '\(method)' yet."
            )
        )

        let body: Data

        do {
            body = try JSONEncoder().encode(
                response
            )
        } catch {
            throw SwiftSemanticCompilerError.protocolViolation(
                "Could not encode JSON-RPC server-request rejection: \(error)"
            )
        }

        try await writeBody(
            body
        )
    }

    func timeoutRequest(
        id: SourceKitLSPMessageID,
        method: String
    ) {
        guard let continuation = pending.removeValue(
            forKey: id
        ) else {
            return
        }

        continuation.finish(
            throwing: SwiftSemanticCompilerError.requestTimedOut(
                method: method
            )
        )
    }

    func cancelRequest(
        id: SourceKitLSPMessageID
    ) {
        guard let continuation = pending.removeValue(
            forKey: id
        ) else {
            return
        }

        continuation.finish(
            throwing: CancellationError()
        )
    }

    func recordStderr(
        _ chunk: Data
    ) {
        stderrTail.append(
            chunk
        )

        if stderrTail.count > Self.maximumStderrTailBytes {
            stderrTail = Data(
                stderrTail.suffix(
                    Self.maximumStderrTailBytes
                )
            )
        }
    }

    func recordExit(
        _ exit: ProcessExit
    ) {
        processExit = exit

        failAll(
            providerExitError(
                exit
            )
        )
    }

    func failAndTerminate(
        _ error: any Error
    ) async {
        failAll(
            error
        )

        await session.terminate()
    }

    func failAll(
        _ error: any Error
    ) {
        let continuations = pending.values
        pending.removeAll()

        for continuation in continuations {
            continuation.finish(
                throwing: error
            )
        }
    }

    func providerExitError(
        _ exit: ProcessExit
    ) -> SwiftSemanticCompilerError {
        let status: String

        switch exit {
        case .exited(let code):
            status = "exit code \(code)"

        case .signaled(let signal):
            status = "signal \(signal)"
        }

        let stderr = String(
            decoding: stderrTail,
            as: UTF8.self
        )
        .trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        if stderr.isEmpty {
            return .providerExited(
                status
            )
        }

        return .providerExited(
            "\(status); stderr: \(stderr)"
        )
    }
}
