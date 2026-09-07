import Foundation

/// Which wire protocol a request should use. All OpenAI-compatible servers
/// speak chat completions; newer ones (OpenAI gpt-5/o-series, OpenCode Go's
/// Grok/GPT/Muse models) also — or only — expose the Responses API.
enum APIFlavor: Equatable {
    /// POST `{base}/chat/completions` — `choices[].delta.content` SSE chunks.
    case chatCompletions
    /// POST `{base}/responses` — typed `response.output_text.delta` SSE events.
    case responses
    /// Anthropic `/messages` protocol (MiniMax, Qwen on OpenCode Go) — not supported.
    case anthropicMessages
}

enum ProviderPreset: String, CaseIterable, Identifiable {
    case openai
    case openrouter
    case opencode
    case ollama
    case lmstudio
    case vllm
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .openrouter: return "OpenRouter"
        case .opencode: return "OpenCode"
        case .ollama: return "Ollama"
        case .lmstudio: return "LM Studio"
        case .vllm: return "vLLM"
        case .custom: return "Custom"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .openai: return "https://api.openai.com/v1"
        case .openrouter: return "https://openrouter.ai/api/v1"
        case .opencode: return "https://opencode.ai/zen/go/v1"
        case .ollama: return "http://localhost:11434/v1"
        case .lmstudio: return "http://localhost:1234/v1"
        case .vllm: return "http://localhost:8000/v1"
        case .custom: return ""
        }
    }

    var defaultModel: String {
        switch self {
        case .openai: return "gpt-4.1-mini"
        case .openrouter: return "openai/gpt-4o-mini"
        case .opencode: return "glm-5.3-flash"
        case .ollama: return "qwen3:8b"
        case .lmstudio: return ""
        case .vllm: return ""
        case .custom: return ""
        }
    }

    var needsAPIKey: Bool {
        switch self {
        case .openai, .openrouter, .opencode: return true
        case .ollama, .lmstudio, .vllm, .custom: return false
        }
    }

    /// Picks the wire protocol for a model. Routing follows the endpoints
    /// OpenCode Go documents per model (opencode.ai/docs/go) and OpenAI's
    /// guidance that gpt-5 / o-series models use the Responses API.
    func apiFlavor(model: String) -> APIFlavor {
        let m = model.lowercased()
        switch self {
        case .openai:
            if isOpenAIReasoningModel(m) {
                return .responses
            }
            return .chatCompletions
        case .opencode:
            // OpenCode Go serves these over the Responses API endpoint.
            if m.hasPrefix("gpt-") || m.hasPrefix("grok-") || m.hasPrefix("muse-spark-") {
                return .responses
            }
            // These are only served over Anthropic's /messages protocol.
            if m.hasPrefix("minimax-") || m.hasPrefix("qwen") {
                return .anthropicMessages
            }
            return .chatCompletions
        case .openrouter, .ollama, .lmstudio, .vllm, .custom:
            return .chatCompletions
        }
    }

    /// gpt-5* and o1–o4 models: OpenAI models that reason server-side. They
    /// are served over the Responses API and expose `reasoning.effort`.
    func isOpenAIReasoningModel(_ model: String) -> Bool {
        let m = model.lowercased()
        return m.hasPrefix("gpt-5") || m.range(of: #"^o\d"#, options: .regularExpression) != nil
    }

    /// Reasoning-locked models (gpt-5 family, o-series) accept only the
    /// server-default sampling temperature — sending `temperature` is a
    /// 400 "Unsupported parameter" (observed via OpenCode Go on
    /// gpt-5.6-luna, whose upstream is OpenAI).
    func rejectsTemperature(model: String) -> Bool {
        isOpenAIReasoningModel(model)
    }

    /// OpenCode's gateway asks clients to send a stable session ID so it can
    /// optimize routing and prompt caching across the conversation.
    func extraHeaders() -> [String: String] {
        switch self {
        case .opencode:
            return ["x-opencode-session": Self.opencodeSessionID]
        case .openai, .openrouter, .ollama, .lmstudio, .vllm, .custom:
            return [:]
        }
    }

    /// Stable per-install identifier for the `x-opencode-session` header.
    /// The system prompt is identical across translations, so a stable ID
    /// gives OpenCode's prompt cache the best hit rate.
    private static var opencodeSessionID: String {
        let key = "opencode.sessionID"
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: key)
        return id
    }

    /// Each provider exposes a different knob for disabling reasoning/"thinking".
    /// These extra body params are merged into the request (chat-completions or
    /// Responses format, per `apiFlavor(model:)`). A client-side <think>…</think>
    /// stripper covers providers with no knob.
    func thinkingDisableParams(model: String, flavor: APIFlavor) -> [String: Any] {
        let m = model.lowercased()
        switch flavor {
        case .responses:
            // The Responses API nests the effort knob under "reasoning".
            if isOpenAIReasoningModel(m) {
                return m.hasPrefix("gpt-5")
                    ? ["reasoning": ["effort": "minimal"]]
                    : ["reasoning": ["effort": "low"]]
            }
            return [:]
        case .chatCompletions:
            switch self {
            case .openai:
                if isOpenAIReasoningModel(m) {
                    return m.hasPrefix("gpt-5")
                        ? ["reasoning_effort": "minimal"]
                        : ["reasoning_effort": "low"]
                }
                return [:]
            case .openrouter:
                return ["reasoning": ["enabled": false]]
            case .ollama:
                // Ollama honors "think"; unknown fields are ignored by older versions.
                return ["think": false]
            case .vllm:
                return ["chat_template_kwargs": ["enable_thinking": false]]
            case .opencode, .lmstudio, .custom:
                // No documented knob — rely on the <think> tag stripper.
                return [:]
            }
        case .anthropicMessages:
            return [:]
        }
    }
}
