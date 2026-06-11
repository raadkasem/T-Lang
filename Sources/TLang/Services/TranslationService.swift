import Foundation

enum TranslationError: LocalizedError {
    case missingBaseURL
    case missingModel
    case badURL
    case badResponse
    case http(Int, String)

    var errorDescription: String? {
        switch self {
        case .missingBaseURL:
            return "No base URL configured. Open Settings and pick a provider."
        case .missingModel:
            return "No model configured. Open Settings and set a model name."
        case .badURL:
            return "The base URL is not a valid URL."
        case .badResponse:
            return "The server returned an unexpected response."
        case .http(let code, let message):
            if code == 401 || code == 403 {
                return "Authentication failed (\(code)) — check your API key."
            }
            let detail = Self.extractAPIError(message) ?? message
            let trimmed = detail.trimmingCharacters(in: .whitespacesAndNewlines)
            return "Server error \(code)" + (trimmed.isEmpty ? "" : ": \(String(trimmed.prefix(200)))")
        }
    }

    private static func extractAPIError(_ body: String) -> String? {
        guard let data = body.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        if let err = obj["error"] as? [String: Any], let msg = err["message"] as? String {
            return msg
        }
        if let err = obj["error"] as? String { return err }
        if let msg = obj["message"] as? String { return msg }
        return nil
    }
}

/// Strips <think>/<thinking>/<reasoning> blocks that local reasoning models
/// emit inline, including unterminated blocks mid-stream.
enum ThinkFilter {
    private static let tags: [(open: String, close: String)] = [
        ("<think>", "</think>"),
        ("<thinking>", "</thinking>"),
        ("<reasoning>", "</reasoning>"),
    ]

    static func filter(_ raw: String) -> (visible: String, thinking: Bool) {
        var out = ""
        var rest = Substring(raw)
        var thinking = false

        while true {
            var earliest: (range: Range<Substring.Index>, close: String)?
            for tag in tags {
                if let r = rest.range(of: tag.open) {
                    if earliest == nil || r.lowerBound < earliest!.range.lowerBound {
                        earliest = (r, tag.close)
                    }
                }
            }
            guard let found = earliest else {
                out += rest
                break
            }
            out += rest[..<found.range.lowerBound]
            let afterOpen = rest[found.range.upperBound...]
            if let closeRange = afterOpen.range(of: found.close) {
                rest = afterOpen[closeRange.upperBound...]
            } else {
                thinking = true
                break
            }
        }

        // Hide a partially-streamed open tag at the tail (e.g. "<thi").
        if !thinking {
            for tag in tags {
                for prefixLen in stride(from: tag.open.count - 1, through: 1, by: -1) {
                    let prefix = String(tag.open.prefix(prefixLen))
                    if out.hasSuffix(prefix) {
                        out.removeLast(prefixLen)
                    }
                }
            }
        }
        return (out, thinking)
    }
}

final class TranslationService: @unchecked Sendable {
    static let shared = TranslationService()

    struct Config {
        let baseURL: String
        let apiKey: String
        let model: String
        let extraBody: [String: Any]
    }

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.ephemeral
        // Fail fast when the server is down instead of spinning for 30s+.
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 180
        config.waitsForConnectivity = false
        session = URLSession(configuration: config)
    }

    @MainActor
    static func currentConfig() -> Config {
        let s = AppSettings.shared
        let extra = s.disableThinking
            ? s.provider.thinkingDisableParams(model: s.model)
            : [:]
        return Config(baseURL: s.baseURL, apiKey: s.apiKey, model: s.model, extraBody: extra)
    }

    static func systemPrompt(for direction: Direction) -> String {
        """
        You are a professional translator. Translate the user's text from \
        \(direction.sourcePromptName) to \(direction.targetPromptName).

        Rules:
        - Translate accurately and naturally, preserving meaning, tone, register, and intent in context.
        - Render idioms and expressions into natural \(direction.targetPromptName) equivalents — never word-for-word.
        - Preserve the original formatting: line breaks, lists, and punctuation style.
        - Keep numbers, proper names, URLs, emails, code snippets, and placeholders (like {x} or %s) unchanged.
        - Output ONLY the translation. No explanations, no notes, no quotation marks around the result.
        """
    }

    /// Streams translated text chunks from an OpenAI-compatible chat-completions endpoint.
    func stream(text: String, direction: Direction, config: Config) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try Self.makeRequest(text: text, direction: direction, config: config)
                    let (bytes, response) = try await self.session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw TranslationError.badResponse
                    }
                    guard http.statusCode == 200 else {
                        var data = Data()
                        for try await byte in bytes {
                            data.append(byte)
                            if data.count > 8192 { break }
                        }
                        throw TranslationError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
                    }
                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if payload == "[DONE]" { break }
                        guard let data = payload.data(using: .utf8),
                              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let choices = obj["choices"] as? [[String: Any]],
                              let delta = choices.first?["delta"] as? [String: Any],
                              let piece = delta["content"] as? String,
                              !piece.isEmpty
                        else { continue }
                        continuation.yield(piece)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Non-streaming convenience used by the settings "Test" button.
    func translateOnce(text: String, direction: Direction, config: Config) async throws -> String {
        var result = ""
        for try await piece in stream(text: text, direction: direction, config: config) {
            result += piece
        }
        return ThinkFilter.filter(result).visible
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func makeRequest(text: String, direction: Direction, config: Config) throws -> URLRequest {
        let base = config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty else { throw TranslationError.missingBaseURL }
        guard !config.model.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw TranslationError.missingModel
        }
        var urlString = base
        while urlString.hasSuffix("/") { urlString.removeLast() }
        guard let url = URL(string: urlString + "/chat/completions"), url.scheme != nil else {
            throw TranslationError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("TLang", forHTTPHeaderField: "X-Title")
        if !config.apiKey.isEmpty {
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }

        var body: [String: Any] = [
            "model": config.model,
            "stream": true,
            "temperature": 0.3,
            "messages": [
                ["role": "system", "content": systemPrompt(for: direction)],
                ["role": "user", "content": text],
            ],
        ]
        for (key, value) in config.extraBody {
            body[key] = value
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }
}
