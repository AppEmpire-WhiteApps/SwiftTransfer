import Foundation

/// One chat message sent to the LLM backend.
struct LLMMessage: Codable, Sendable, Equatable {
    enum Role: String, Codable, Sendable {
        case system
        case user
        case assistant
    }

    var role: Role
    var content: String
}

/// A chat completion request (TZ §7.9).
struct LLMRequest: Sendable, Equatable {
    var messages: [LLMMessage]
    var maxTokens = 1024
    /// Ask for the `assistant_reply` JSON schema (TZ §7.7).
    var structured = AppConfig.assistantStructuredReplies
}

/// Something that answers chat requests: the live LLMApps client or a mock.
protocol LLMClienting: Sendable {
    /// Returns the raw `choices[0].message.content`. Throws `LLMError` or `CancellationError`.
    func complete(_ request: LLMRequest) async throws -> String
}

/// Client for `POST /v1/chat/completions` on the LLMApps backend (TZ §7.2).
///
/// - A fresh TOTP token is created for every attempt.
/// - 401/403: one retry with a new token, then `LLMError.unauthorized` (device clock).
/// - Network error / 5xx: one retry after `retryDelay`.
/// - Cancelling the calling task cancels the underlying URLSession task.
final class LLMClient: LLMClienting {
    static let requestTimeout: TimeInterval = 60

    private let endpoint: URL
    private let session: URLSession
    private let tokenProvider: TOTPTokenProvider
    private let retryDelay: Duration

    init(
        baseURL: URL = AppConfig.llmBaseURL,
        session: URLSession = LLMClient.makeSession(),
        tokenProvider: TOTPTokenProvider = TOTPTokenProvider(),
        retryDelay: Duration = .seconds(2)
    ) {
        self.endpoint = baseURL.appendingPathComponent("v1/chat/completions")
        self.session = session
        self.tokenProvider = tokenProvider
        self.retryDelay = retryDelay
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = requestTimeout
        configuration.waitsForConnectivity = false
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }

    func complete(_ request: LLMRequest) async throws -> String {
        let body = try Self.makeBody(for: request)
        var didRetryAuth = false
        var didRetryTransient = false

        while true {
            try Task.checkCancellation()
            let token = try await tokenProvider.token()
            let urlRequest = makeURLRequest(body: body, token: token)

            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await session.data(for: urlRequest)
            } catch let error as URLError {
                let mapped = try Self.map(error)
                if mapped.isTransient, !didRetryTransient {
                    didRetryTransient = true
                    try await Task.sleep(for: retryDelay)
                    continue
                }
                throw mapped
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw LLMError.server
            }

            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            switch status {
            case 200..<300:
                return try Self.parseContent(from: data)
            case 401, 403:
                guard !didRetryAuth else {
                    throw LLMError.unauthorized
                }
                didRetryAuth = true
            case 429:
                throw LLMError.busy
            case 500...:
                guard !didRetryTransient else {
                    throw LLMError.server
                }
                didRetryTransient = true
                try await Task.sleep(for: retryDelay)
            default:
                throw LLMError.server
            }
        }
    }

    private func makeURLRequest(body: Data, token: String) -> URLRequest {
        var request = URLRequest(url: endpoint, timeoutInterval: Self.requestTimeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = body
        return request
    }

    /// JSON body without `model` (the backend chooses the model).
    static func makeBody(for request: LLMRequest) throws -> Data {
        var body: [String: Any] = [
            "messages": request.messages.map { ["role": $0.role.rawValue, "content": $0.content] },
            "max_tokens": request.maxTokens,
        ]
        if request.structured {
            body["response_format"] = replySchema
        }
        return try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    }

    /// `response_format` for structured replies (TZ §7.7).
    static var replySchema: [String: Any] {
        [
            "type": "json_schema",
            "json_schema": [
                "name": "assistant_reply",
                "schema": [
                    "type": "object",
                    "properties": [
                        "text": ["type": "string"],
                        "actions": [
                            "type": "array",
                            "items": [
                                "type": "string",
                                "enum": AssistantAction.allCases.map(\.rawValue),
                            ] as [String: Any],
                        ] as [String: Any],
                    ] as [String: Any],
                    "required": ["text", "actions"],
                ] as [String: Any],
            ] as [String: Any],
        ]
    }

    static func parseContent(from data: Data) throws -> String {
        guard let response = try? JSONDecoder().decode(CompletionResponse.self, from: data) else {
            throw LLMError.server
        }
        let content = response.choices.first?.message.content ?? ""
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LLMError.emptyReply
        }
        return content
    }

    static func map(_ error: URLError) throws -> LLMError {
        switch error.code {
        case .cancelled:
            throw CancellationError()
        case .notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff:
            return .offline
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return .unreachable
        case .timedOut, .networkConnectionLost, .secureConnectionFailed, .badServerResponse:
            return .server
        default:
            return .server
        }
    }

    private struct CompletionResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                var content: String?
            }

            var message: Message
        }

        var choices: [Choice]
    }
}
